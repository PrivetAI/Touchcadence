import SwiftUI

/// One self-contained session flow: countdown -> live game -> result.
/// Kept in a single pushed destination so no nested navigation dismissals are needed.
struct GameFlowView: View {
    @EnvironmentObject private var store: TrainingStore
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    let training: Training
    var challenge: ChallengeTag? = nil
    /// Called after the result is stored, used by the weekly challenge runner.
    var onFinished: ((SessionResult) -> Void)? = nil

    private enum Phase { case countdown, playing, result }

    @State private var phase: Phase = .countdown
    @State private var engine: GameEngine?
    @State private var finalResult: SessionResult?
    @State private var runID = UUID()

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()
            switch phase {
            case .countdown:
                CountdownStage(training: training) { beginPlay() }
                    .id(runID)
            case .playing:
                if let engine {
                    GameStage(engine: engine, onQuit: { dismiss() }, onFinish: { storeResult(from: engine) })
                        .id(runID)
                }
            case .result:
                if let finalResult {
                    ResultStage(training: training, result: finalResult,
                                experience: max(0, finalResult.score / 20),
                                onRepeat: { restart() },
                                onDone: { dismiss() })
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .onAppear { FeedbackEngine.shared.prepare() }
        .onDisappear { engine?.stop() }
    }

    private func beginPlay() {
        let e = GameEngine(training: training, motion: store.motion, settings: store.settings)
        engine = e
        phase = .playing
    }

    private func storeResult(from engine: GameEngine) {
        let result = engine.makeResult()
        store.save(result: result, training: training, challenge: challenge)
        finalResult = result
        onFinished?(result)
        phase = .result
    }

    private func restart() {
        engine?.stop()
        engine = nil
        finalResult = nil
        runID = UUID()
        phase = .countdown
    }
}

// MARK: - Countdown

private struct CountdownStage: View {
    @Environment(\.palette) private var palette
    @EnvironmentObject private var store: TrainingStore
    let training: Training
    let onDone: () -> Void

    @State private var value = 3
    @State private var pulse = false
    @State private var timer: Timer?
    @State private var done = false

    var body: some View {
        VStack(spacing: Metrics.spaceL) {
            Spacer()
            Text(training.name).font(.kHeadline).foregroundColor(palette.secondaryText)
                .multilineTextAlignment(.center)
            ZStack {
                Circle().stroke(palette.grid, lineWidth: 6).frame(width: 168, height: 168)
                Circle().stroke(palette.primary, lineWidth: 6)
                    .frame(width: 168, height: 168)
                    .scaleEffect(pulse ? 1.06 : 0.94)
                    .opacity(pulse ? 0.4 : 1)
                Text(value > 0 ? "\(value)" : "GO")
                    .font(.system(size: value > 0 ? 74 : 52, weight: .bold, design: .rounded))
                    .foregroundColor(palette.text)
            }
            Text(training.movement.summary)
                .font(.kBody).foregroundColor(palette.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Metrics.spaceM)
            Spacer()
            Text("\(training.category.title) · \(training.difficulty.title) · \(training.duration)s")
                .font(.kCaption).foregroundColor(palette.secondaryText)
            PrimaryButton(title: "Skip Countdown", glyph: .play, tone: .neutral) { finish() }
                .frame(maxWidth: 260)
            Spacer().frame(height: Metrics.spaceS)
        }
        .padding(Metrics.spaceL)
        .onAppear { begin() }
        .onDisappear { timer?.invalidate() }
    }

    private func begin() {
        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) { pulse = true }
        beep()
        let t = Timer(timeInterval: 0.8, repeats: true) { _ in
            Task { @MainActor in step() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func step() {
        guard !done else { return }
        if value > 0 {
            value -= 1
            beep()
        } else {
            finish()
        }
    }

    private func finish() {
        guard !done else { return }
        done = true
        timer?.invalidate()
        timer = nil
        onDone()
    }

    private func beep() {
        FeedbackEngine.shared.play(.countdown, sound: store.settings.sound,
                                   vibration: store.settings.vibration)
    }
}

// MARK: - Live game

private struct GameStage: View {
    @ObservedObject var engine: GameEngine
    @Environment(\.palette) private var palette
    let onQuit: () -> Void
    let onFinish: () -> Void

    @State private var fieldSize: CGSize = .zero

    var body: some View {
        GeometryReader { outer in
            let compact = outer.size.height < 700
            VStack(spacing: compact ? Metrics.spaceS : Metrics.spaceM) {
                header(compact: compact)

                // Play field. The size comes from THIS GeometryReader and is handed to the
                // engine and the Canvas — a Canvas closure size is not the parent size.
                GeometryReader { fieldGeo in
                    let size = fieldGeo.size
                    ZStack {
                        FieldCanvas(engine: engine, fieldSize: size, palette: palette)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    // startLocation, so re-delivered callbacks cannot shift the touch.
                                    .onChanged { value in engine.touchBegan(at: value.startLocation) }
                                    .onEnded { _ in engine.touchEnded() }
                            )
                        if engine.isPaused { pauseOverlay }
                    }
                    .onAppear { engine.setField(size); fieldSize = size; engine.start() }
                    .onChange(of: size) { newValue in engine.setField(newValue); fieldSize = newValue }
                }
                .frame(minHeight: compact ? 240 : 300)
                .background(
                    RoundedRectangle(cornerRadius: Metrics.cornerLarge, style: .continuous)
                        .fill(palette.field)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Metrics.cornerLarge, style: .continuous)
                        .stroke(palette.grid, lineWidth: 1)
                )
                .clipped()

                footer(compact: compact)
            }
            .padding(.horizontal, Metrics.spaceM)
            .padding(.vertical, compact ? Metrics.spaceS : Metrics.spaceM)
        }
        .onChange(of: engine.isFinished) { finished in
            if finished { onFinish() }
        }
    }

    private func header(compact: Bool) -> some View {
        HStack(spacing: Metrics.spaceS) {
            GlyphButton(kind: .close, size: 18, box: 40) { onQuit() }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(engine.score)")
                    .font(.system(size: compact ? 26 : 32, weight: .bold, design: .rounded))
                    .foregroundColor(palette.text)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text("SCORE").font(.kCaption).foregroundColor(palette.secondaryText)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1fs", engine.remaining))
                    .font(.system(size: compact ? 22 : 26, weight: .bold, design: .rounded))
                    .foregroundColor(engine.remaining < 6 ? palette.warning : palette.text)
                    .monospacedDigit()
                Text("LEFT").font(.kCaption).foregroundColor(palette.secondaryText)
            }
            GlyphButton(kind: engine.isPaused ? .play : .pause, size: 18, box: 40) {
                engine.isPaused ? engine.resume() : engine.pause()
            }
        }
    }

    private func footer(compact: Bool) -> some View {
        HStack(spacing: Metrics.spaceS) {
            StatTile(label: "COMBO", value: "\(engine.combo)", tint: palette.accent)
            StatTile(label: "MULT", value: String(format: "x%.2f", engine.multiplier), tint: palette.primary)
            StatTile(label: "ACC", value: "\(Int((engine.accuracy * 100).rounded()))%",
                     tint: engine.accuracy >= 0.8 ? palette.success : palette.warning)
            StatTile(label: "REACT", value: engine.lastReaction > 0
                     ? String(format: "%.2fs", engine.lastReaction) : "—")
        }
        .frame(height: compact ? 62 : 70)
    }

    private var pauseOverlay: some View {
        ZStack {
            palette.background.opacity(0.88)
            VStack(spacing: Metrics.spaceM) {
                Text("Paused").font(.kTitle).foregroundColor(palette.text)
                PrimaryButton(title: "Resume", glyph: .play) { engine.resume() }
                    .frame(maxWidth: 220)
                PrimaryButton(title: "End Session", glyph: .check, tone: .neutral) { engine.finishNow() }
                    .frame(maxWidth: 220)
                PrimaryButton(title: "Quit", glyph: .close, tone: .danger) { onQuit() }
                    .frame(maxWidth: 220)
            }
            .padding(Metrics.spaceL)
        }
    }
}

/// Draws the field, the target and the transient feedback.
private struct FieldCanvas: View {
    @ObservedObject var engine: GameEngine
    /// Size passed in from the parent geometry.
    let fieldSize: CGSize
    let palette: Palette

    var body: some View {
        Canvas { ctx, _ in
            let w = fieldSize.width
            let h = fieldSize.height
            guard w > 1, h > 1 else { return }

            // Grid backdrop
            let step: CGFloat = 44
            var grid = Path()
            var x: CGFloat = step
            while x < w { grid.move(to: CGPoint(x: x, y: 0)); grid.addLine(to: CGPoint(x: x, y: h)); x += step }
            var y: CGFloat = step
            while y < h { grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: w, y: y)); y += step }
            ctx.stroke(grid, with: .color(palette.grid.opacity(0.55)), lineWidth: 0.5)

            // Ripples
            for r in engine.ripples {
                let age = engine.now - r.born
                let f = max(0, min(1, age / 0.45))
                var ring = Path()
                let rad = engine.radius * (0.6 + f * 1.8)
                ring.addEllipse(in: CGRect(x: r.point.x - rad, y: r.point.y - rad, width: rad * 2, height: rad * 2))
                ctx.stroke(ring, with: .color((r.isMiss ? palette.error : palette.accent).opacity(1 - f)),
                           lineWidth: 2)
            }

            // Target
            let c = engine.targetPoint
            let radius = engine.radius
            if radius > 0 {
                let shadowRect = CGRect(x: c.x - radius, y: c.y - radius + Metrics.targetShadow,
                                        width: radius * 2, height: radius * 2)
                var shadow = Path(); shadow.addEllipse(in: shadowRect)
                ctx.fill(shadow, with: .color(Color.black.opacity(palette.isDark ? 0.45 : 0.18)))

                let rect = CGRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2)
                var body = Path(); body.addEllipse(in: rect)
                ctx.fill(body, with: .linearGradient(
                    Gradient(colors: [palette.primary, palette.accent]),
                    startPoint: CGPoint(x: rect.minX, y: rect.minY),
                    endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))

                var inner = Path()
                inner.addEllipse(in: rect.insetBy(dx: radius * 0.58, dy: radius * 0.58))
                ctx.fill(inner, with: .color(palette.isDark ? Color.white.opacity(0.92) : Color.black.opacity(0.75)))

                // Lifetime arc around the target
                var arc = Path()
                arc.addArc(center: c, radius: radius + 7,
                           startAngle: .degrees(-90),
                           endAngle: .degrees(-90 + 360 * (1 - engine.targetProgress)),
                           clockwise: false)
                ctx.stroke(arc, with: .color(palette.warning.opacity(0.85)),
                           style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }

            // Floating labels
            for f in engine.floaters {
                let age = engine.now - f.born
                let t = max(0, min(1, age / 0.9))
                let resolved = ctx.resolve(
                    Text(f.text)
                        .font(.system(size: f.isMiss ? 13 : 15, weight: .bold, design: .rounded))
                        .foregroundColor((f.isMiss ? palette.error : palette.success).opacity(1 - t))
                )
                ctx.draw(resolved, at: CGPoint(x: f.point.x, y: f.point.y - 26 - t * 26))
            }
        }
        .drawingGroup(opaque: false)
    }
}

// MARK: - Result

private struct ResultStage: View {
    @Environment(\.palette) private var palette
    let training: Training
    let result: SessionResult
    let experience: Int
    let onRepeat: () -> Void
    let onDone: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Metrics.spaceM) {
                Text("Session Complete").font(.kTitle).foregroundColor(palette.text)
                Text(training.name).font(.kBody).foregroundColor(palette.secondaryText)
                    .multilineTextAlignment(.center)

                RankBadge(rank: result.rank, size: 108)
                    .padding(.vertical, Metrics.spaceS)

                Card {
                    HStack {
                        Text("Score").font(.kBody).foregroundColor(palette.secondaryText)
                        Spacer()
                        Text("\(result.score)").font(.kNumber).foregroundColor(palette.text)
                            .lineLimit(1).minimumScaleFactor(0.6)
                    }
                }

                HStack(spacing: Metrics.spaceS) {
                    StatTile(label: "ACCURACY", value: "\(Int((result.accuracy * 100).rounded()))%",
                             tint: palette.success)
                    StatTile(label: "REACTION", value: result.averageReaction > 0
                             ? String(format: "%.2fs", result.averageReaction) : "—", tint: palette.accent)
                }
                HStack(spacing: Metrics.spaceS) {
                    StatTile(label: "BEST COMBO", value: "\(result.combo)", tint: palette.primary)
                    StatTile(label: "STABILITY", value: String(format: "%.0f", result.stability),
                             tint: palette.warning)
                }
                HStack(spacing: Metrics.spaceS) {
                    StatTile(label: "RHYTHM", value: "\(Int((result.rhythm * 100).rounded()))%")
                    StatTile(label: "EXPERIENCE", value: "+\(experience)", tint: palette.accent)
                }

                Card {
                    SectionTitle(text: "Takeaway")
                    Text(takeaway).font(.kBody).foregroundColor(palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                PrimaryButton(title: "Train Again", glyph: .restart) { onRepeat() }
                PrimaryButton(title: "Back", glyph: .back, tone: .neutral) { onDone() }
            }
            .padding(Metrics.spaceM)
            .padding(.bottom, Metrics.spaceL)
        }
    }

    private var takeaway: String {
        let analysis = Analysis(accuracy: result.accuracy, reaction: result.averageReaction,
                                rhythm: result.rhythm, stability: result.stability,
                                combo: Double(result.combo))
        let weakest = analysis.weakest
        return "Weakest measure: \(weakest.title). \(weakest.advice)"
    }
}
