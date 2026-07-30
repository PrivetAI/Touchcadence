import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var store: TrainingStore
    @Environment(\.palette) private var palette

    @State private var category: TrainingCategory? = nil
    @State private var difficulty: Difficulty? = nil
    @State private var movement: MovementType? = nil
    @State private var showFilters = false

    private var filtered: [Training] {
        store.trainings.filter { t in
            (category == nil || t.category == category)
                && (difficulty == nil || t.difficulty == difficulty)
                && (movement == nil || t.movement == movement)
        }
    }

    var body: some View {
        ScreenScaffold(title: "Library", subtitle: "\(filtered.count) of \(store.trainings.count) trainings", back: true) {
            HStack(spacing: Metrics.spaceS) {
                Button {
                    withAnimation(.easeInOut(duration: Metrics.animation)) { showFilters.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Glyph(kind: .layers, size: 18, color: palette.text)
                        Text(showFilters ? "Hide Filters" : "Filters").font(.kCaption).foregroundColor(palette.text)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: Metrics.cornerSmall).fill(palette.elevated))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if category != nil || difficulty != nil || movement != nil {
                    Button {
                        category = nil; difficulty = nil; movement = nil
                    } label: {
                        HStack(spacing: 6) {
                            Glyph(kind: .close, size: 16, color: palette.error)
                            Text("Clear").font(.kCaption).foregroundColor(palette.error)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: Metrics.cornerSmall).fill(palette.error.opacity(0.12)))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }

            if showFilters {
                Card {
                    Text("Category").font(.kCaption).foregroundColor(palette.secondaryText)
                    filterRow(TrainingCategory.allCases.map { ($0.title, $0) }, selection: $category)
                    Text("Difficulty").font(.kCaption).foregroundColor(palette.secondaryText)
                    filterRow(Difficulty.allCases.map { ($0.title, $0) }, selection: $difficulty)
                    Text("Movement").font(.kCaption).foregroundColor(palette.secondaryText)
                    filterRow(MovementType.allCases.map { ($0.title, $0) }, selection: $movement)
                }
            }

            if filtered.isEmpty {
                EmptyNote(text: "No training matches these filters. Clear one to see more.")
            }

            ForEach(filtered) { training in
                NavigationLink { TrainingDetailView(training: training) } label: {
                    TrainingRow(training: training,
                                best: store.bestScores[training.id],
                                rank: store.bestRanks[training.id],
                                favorite: store.favorites.contains(training.id))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func filterRow<T: Hashable>(_ options: [(String, T)], selection: Binding<T?>) -> some View {
        let columns = 3
        let rows = stride(from: 0, to: options.count, by: columns).map {
            Array(options[$0..<min($0 + columns, options.count)])
        }
        VStack(spacing: Metrics.spaceS) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: Metrics.spaceS) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, pair in
                        let isOn = selection.wrappedValue == pair.1
                        Button {
                            selection.wrappedValue = isOn ? nil : pair.1
                        } label: {
                            Text(pair.0)
                                .font(.kCaption)
                                .foregroundColor(isOn ? (palette.isDark ? .black : .white) : palette.text)
                                .lineLimit(1).minimumScaleFactor(0.65)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(RoundedRectangle(cornerRadius: Metrics.cornerSmall)
                                    .fill(isOn ? palette.primary : palette.elevated))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    if row.count < columns {
                        ForEach(0..<(columns - row.count), id: \.self) { _ in
                            Color.clear.frame(maxWidth: .infinity).frame(height: 1)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Detail

struct TrainingDetailView: View {
    @EnvironmentObject private var store: TrainingStore
    @Environment(\.palette) private var palette
    let training: Training
    var challenge: ChallengeTag? = nil

    @State private var playing = false

    private var history: [SessionResult] { store.recentResults(for: training) }
    private var bestTrailing: String? {
        (store.bestScores[training.id] ?? 0) > 0 ? nil : "No runs yet"
    }

    var body: some View {
        ScreenScaffold(title: training.name, subtitle: training.category.summary, back: true) {
            Card {
                HStack(spacing: Metrics.spaceS) {
                    Chip(text: training.category.title, color: palette.categoryColor(training.category))
                    Chip(text: training.difficulty.title, color: palette.primary)
                    Chip(text: "\(training.duration)s", color: palette.secondaryText)
                }
                Text(training.movement.title).font(.kHeadline).foregroundColor(palette.text)
                Text(training.movement.summary).font(.kBody).foregroundColor(palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                PathPreview(movement: training.movement, motion: store.motion, palette: palette)
                    .frame(height: 150)
                if let note = training.note, !note.isEmpty {
                    HStack(alignment: .top, spacing: Metrics.spaceS) {
                        Glyph(kind: .info, size: 16, color: palette.accent)
                        Text(note).font(.kCaption).foregroundColor(palette.accent)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            HStack(spacing: Metrics.spaceS) {
                StatTile(label: "TARGET", value: "\(Int(training.targetRadius.rounded()))pt")
                StatTile(label: "SPEED", value: String(format: "x%.2f",
                                                       training.difficulty.speedMultiplier * store.settings.speed))
                StatTile(label: "WINDOW", value: String(format: "%.2fs", training.difficulty.targetLifetime))
            }

            PrimaryButton(title: "Start Session", glyph: .play) { playing = true }

            Button {
                store.toggleFavorite(training)
            } label: {
                HStack(spacing: Metrics.spaceS) {
                    Glyph(kind: store.favorites.contains(training.id) ? .starFilled : .star,
                          size: 20, color: palette.warning)
                    Text(store.favorites.contains(training.id) ? "Remove from Favorites" : "Add to Favorites")
                        .font(.kBody).foregroundColor(palette.text)
                    Spacer(minLength: 0)
                }
                .padding(Metrics.spaceM)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: Metrics.cornerSmall).fill(palette.elevated))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if training.isCustom {
                PrimaryButton(title: "Delete Custom Training", glyph: .trash, tone: .danger) {
                    store.deleteCustom(training)
                }
            }

            SectionTitle(text: "Personal Best", trailing: bestTrailing)
            Card {
                HStack(spacing: Metrics.spaceM) {
                    RankBadge(rank: store.bestRanks[training.id] ?? .d, size: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(store.bestScores[training.id] ?? 0)")
                            .font(.kNumber).foregroundColor(palette.text)
                            .lineLimit(1).minimumScaleFactor(0.6)
                        Text("best score").font(.kCaption).foregroundColor(palette.secondaryText)
                    }
                    Spacer(minLength: 0)
                }
            }

            if history.count > 1 {
                SectionTitle(text: "Score Trend")
                Card {
                    LineChartCanvas(values: history.reversed().map { Double($0.score) })
                }
            }

            if !history.isEmpty {
                SectionTitle(text: "Recent Runs", trailing: "\(history.count)")
                ForEach(history.prefix(6)) { r in
                    ResultRow(result: r)
                }
            }
        }
        .fullScreenCover(isPresented: $playing) {
            GameFlowView(training: training, challenge: challenge)
                .environmentObject(store)
                .environment(\.palette, palette)
        }
    }
}

// MARK: - Result row

struct ResultRow: View {
    @Environment(\.palette) private var palette
    let result: SessionResult
    var showName: Bool = false

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, HH:mm"
        return f
    }()

    var body: some View {
        HStack(spacing: Metrics.spaceM) {
            RankBadge(rank: result.rank, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                if showName {
                    Text(result.trainingName).font(.kBody).foregroundColor(palette.text).lineLimit(1)
                }
                Text("\(result.score) pts · \(Int((result.accuracy * 100).rounded()))% · combo \(result.combo)")
                    .font(.kCaption).foregroundColor(palette.secondaryText).lineLimit(1)
                Text(ResultRow.formatter.string(from: result.date))
                    .font(.system(size: 10, design: .rounded)).foregroundColor(palette.secondaryText.opacity(0.8))
            }
            Spacer(minLength: 0)
            Text(result.averageReaction > 0 ? String(format: "%.2fs", result.averageReaction) : "—")
                .font(.kCaption).foregroundColor(palette.accent)
        }
        .padding(Metrics.spaceM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Metrics.cornerSmall).fill(palette.surface))
        .overlay(RoundedRectangle(cornerRadius: Metrics.cornerSmall).stroke(palette.grid, lineWidth: 1))
    }
}

// MARK: - Path preview

/// Traces the trajectory a movement type produces, drawn by hand.
struct PathPreview: View {
    let movement: MovementType
    let motion: MotionEngine
    let palette: Palette
    var speed: Double = 1.0

    var body: some View {
        GeometryReader { geo in
            let size = geo.size          // parent geometry, not the Canvas closure size
            Canvas { ctx, _ in
                guard size.width > 4, size.height > 4 else { return }
                // Inscribe a SQUARE so a circular path reads as a circle, never an ellipse.
                let inset: CGFloat = 14
                let side = max(1, min(size.width, size.height) - inset * 2)
                let box = CGRect(x: (size.width - side) / 2, y: (size.height - side) / 2,
                                 width: side, height: side)
                var border = Path()
                border.addRoundedRect(in: CGRect(origin: .zero, size: size),
                                      cornerSize: CGSize(width: 12, height: 12))
                ctx.stroke(border, with: .color(palette.grid), lineWidth: 1)

                let samples = motion.samplePath(movement: movement, samples: 300, span: 10, speed: speed, seed: 21)
                var path = Path()
                for (i, n) in samples.enumerated() {
                    let p = CGPoint(x: box.minX + CGFloat(n.x) * box.width,
                                    y: box.minY + CGFloat(n.y) * box.height)
                    if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
                }
                ctx.stroke(path, with: .color(palette.primary.opacity(0.85)),
                           style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))

                if let last = samples.last {
                    let p = CGPoint(x: box.minX + CGFloat(last.x) * box.width,
                                    y: box.minY + CGFloat(last.y) * box.height)
                    var dot = Path()
                    dot.addEllipse(in: CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10))
                    ctx.fill(dot, with: .color(palette.accent))
                }
            }
        }
    }
}
