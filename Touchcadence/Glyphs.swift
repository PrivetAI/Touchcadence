import SwiftUI

/// The single icon set for the whole app. Every glyph is drawn with `Canvas`.
/// No SF Symbols and no emoji anywhere in the UI.
enum GlyphKind {
    case home, challenge, stats, programs, settings
    case back, forward, close, play, pause, restart
    case target, star, starFilled, plus, minus, check, trash
    case clock, bolt, wave, rings, layers, medal, gauge, spark, grid, lock, info
}

struct Glyph: View {
    let kind: GlyphKind
    var size: CGFloat = 24
    var color: Color = .white
    var lineWidth: CGFloat = 2
    /// Fill weight for solid glyphs.
    var filled: Bool = false

    var body: some View {
        Canvas { ctx, canvasSize in
            // Anchor to the canvas box we asked for; the frame below fixes it to `size`.
            let s = min(canvasSize.width, canvasSize.height)
            let r = CGRect(x: (canvasSize.width - s) / 2, y: (canvasSize.height - s) / 2, width: s, height: s)
            draw(in: &ctx, box: r, unit: s)
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
    }

    private func p(_ box: CGRect, _ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: box.minX + box.width * x, y: box.minY + box.height * y)
    }

    private func draw(in ctx: inout GraphicsContext, box: CGRect, unit: CGFloat) {
        let lw = max(1.2, lineWidth * unit / 24)
        let stroke = StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round)

        switch kind {
        case .home:
            var path = Path()
            path.move(to: p(box, 0.14, 0.50))
            path.addLine(to: p(box, 0.50, 0.16))
            path.addLine(to: p(box, 0.86, 0.50))
            ctx.stroke(path, with: .color(color), style: stroke)
            var base = Path()
            base.addRoundedRect(in: CGRect(x: p(box, 0.24, 0.48).x, y: p(box, 0.24, 0.48).y,
                                           width: box.width * 0.52, height: box.height * 0.36),
                                cornerSize: CGSize(width: lw, height: lw))
            ctx.stroke(base, with: .color(color), style: stroke)

        case .challenge:
            var path = Path()
            path.move(to: p(box, 0.26, 0.88))
            path.addLine(to: p(box, 0.26, 0.14))
            path.addLine(to: p(box, 0.78, 0.26))
            path.addLine(to: p(box, 0.26, 0.42))
            ctx.stroke(path, with: .color(color), style: stroke)
            var dot = Path()
            dot.addEllipse(in: CGRect(x: p(box, 0.58, 0.56).x, y: p(box, 0.58, 0.56).y,
                                      width: box.width * 0.20, height: box.height * 0.20))
            ctx.stroke(dot, with: .color(color), style: stroke)

        case .stats:
            for (i, h) in [0.34, 0.60, 0.46, 0.78].enumerated() {
                let x = 0.16 + Double(i) * 0.20
                var bar = Path()
                bar.move(to: p(box, CGFloat(x), 0.84))
                bar.addLine(to: p(box, CGFloat(x), CGFloat(0.84 - h)))
                ctx.stroke(bar, with: .color(color), style: StrokeStyle(lineWidth: lw * 1.6, lineCap: .round))
            }

        case .programs:
            for i in 0..<3 {
                let y = 0.26 + CGFloat(i) * 0.24
                var row = Path()
                row.addRoundedRect(in: CGRect(x: p(box, 0.16, y).x, y: p(box, 0.16, y).y,
                                              width: box.width * 0.68, height: box.height * 0.14),
                                   cornerSize: CGSize(width: lw, height: lw))
                ctx.stroke(row, with: .color(color), style: stroke)
            }

        case .settings:
            var outer = Path()
            outer.addEllipse(in: box.insetBy(dx: box.width * 0.12, dy: box.height * 0.12))
            ctx.stroke(outer, with: .color(color), style: stroke)
            for i in 0..<4 {
                let a = Double(i) * .pi / 2 + .pi / 4
                var tick = Path()
                let c = CGPoint(x: box.midX, y: box.midY)
                tick.move(to: CGPoint(x: c.x + cos(a) * box.width * 0.24, y: c.y + sin(a) * box.height * 0.24))
                tick.addLine(to: CGPoint(x: c.x + cos(a) * box.width * 0.44, y: c.y + sin(a) * box.height * 0.44))
                ctx.stroke(tick, with: .color(color), style: stroke)
            }
            var inner = Path()
            inner.addEllipse(in: box.insetBy(dx: box.width * 0.36, dy: box.height * 0.36))
            ctx.fill(inner, with: .color(color))

        case .back, .forward:
            var path = Path()
            if kind == .back {
                path.move(to: p(box, 0.62, 0.18))
                path.addLine(to: p(box, 0.32, 0.50))
                path.addLine(to: p(box, 0.62, 0.82))
            } else {
                path.move(to: p(box, 0.38, 0.18))
                path.addLine(to: p(box, 0.68, 0.50))
                path.addLine(to: p(box, 0.38, 0.82))
            }
            ctx.stroke(path, with: .color(color), style: stroke)

        case .close:
            var path = Path()
            path.move(to: p(box, 0.24, 0.24)); path.addLine(to: p(box, 0.76, 0.76))
            path.move(to: p(box, 0.76, 0.24)); path.addLine(to: p(box, 0.24, 0.76))
            ctx.stroke(path, with: .color(color), style: stroke)

        case .play:
            var path = Path()
            path.move(to: p(box, 0.30, 0.18))
            path.addLine(to: p(box, 0.80, 0.50))
            path.addLine(to: p(box, 0.30, 0.82))
            path.closeSubpath()
            if filled { ctx.fill(path, with: .color(color)) } else { ctx.stroke(path, with: .color(color), style: stroke) }

        case .pause:
            for x in [0.34, 0.62] {
                var bar = Path()
                bar.move(to: p(box, CGFloat(x), 0.22))
                bar.addLine(to: p(box, CGFloat(x), 0.78))
                ctx.stroke(bar, with: .color(color), style: StrokeStyle(lineWidth: lw * 1.8, lineCap: .round))
            }

        case .restart:
            var arc = Path()
            arc.addArc(center: CGPoint(x: box.midX, y: box.midY), radius: box.width * 0.32,
                       startAngle: .degrees(-40), endAngle: .degrees(260), clockwise: false)
            ctx.stroke(arc, with: .color(color), style: stroke)
            var head = Path()
            head.move(to: p(box, 0.72, 0.16))
            head.addLine(to: p(box, 0.86, 0.34))
            head.addLine(to: p(box, 0.64, 0.38))
            ctx.stroke(head, with: .color(color), style: stroke)

        case .target, .rings:
            let rings: [CGFloat] = kind == .target ? [0.44, 0.28] : [0.44, 0.30, 0.16]
            for f in rings {
                var ring = Path()
                ring.addEllipse(in: CGRect(x: box.midX - box.width * f, y: box.midY - box.height * f,
                                           width: box.width * f * 2, height: box.height * f * 2))
                ctx.stroke(ring, with: .color(color), style: stroke)
            }
            if kind == .target {
                var dot = Path()
                dot.addEllipse(in: CGRect(x: box.midX - box.width * 0.09, y: box.midY - box.height * 0.09,
                                          width: box.width * 0.18, height: box.height * 0.18))
                ctx.fill(dot, with: .color(color))
            }

        case .star, .starFilled:
            var path = Path()
            let c = CGPoint(x: box.midX, y: box.midY)
            let outerR = box.width * 0.40
            let innerR = box.width * 0.17
            for i in 0..<10 {
                let a = -Double.pi / 2 + Double(i) * .pi / 5
                let rr = i % 2 == 0 ? outerR : innerR
                let pt = CGPoint(x: c.x + cos(a) * rr, y: c.y + sin(a) * rr)
                if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
            path.closeSubpath()
            if kind == .starFilled || filled {
                ctx.fill(path, with: .color(color))
            } else {
                ctx.stroke(path, with: .color(color), style: stroke)
            }

        case .plus, .minus:
            var path = Path()
            path.move(to: p(box, 0.22, 0.50)); path.addLine(to: p(box, 0.78, 0.50))
            if kind == .plus {
                path.move(to: p(box, 0.50, 0.22)); path.addLine(to: p(box, 0.50, 0.78))
            }
            ctx.stroke(path, with: .color(color), style: stroke)

        case .check:
            var path = Path()
            path.move(to: p(box, 0.22, 0.54))
            path.addLine(to: p(box, 0.42, 0.74))
            path.addLine(to: p(box, 0.80, 0.28))
            ctx.stroke(path, with: .color(color), style: stroke)

        case .trash:
            var lid = Path()
            lid.move(to: p(box, 0.20, 0.28)); lid.addLine(to: p(box, 0.80, 0.28))
            lid.move(to: p(box, 0.40, 0.28)); lid.addLine(to: p(box, 0.40, 0.18))
            lid.addLine(to: p(box, 0.60, 0.18)); lid.addLine(to: p(box, 0.60, 0.28))
            ctx.stroke(lid, with: .color(color), style: stroke)
            var body = Path()
            body.move(to: p(box, 0.28, 0.28))
            body.addLine(to: p(box, 0.32, 0.82))
            body.addLine(to: p(box, 0.68, 0.82))
            body.addLine(to: p(box, 0.72, 0.28))
            ctx.stroke(body, with: .color(color), style: stroke)

        case .clock:
            var ring = Path()
            ring.addEllipse(in: box.insetBy(dx: box.width * 0.12, dy: box.height * 0.12))
            ctx.stroke(ring, with: .color(color), style: stroke)
            var hands = Path()
            hands.move(to: p(box, 0.50, 0.50)); hands.addLine(to: p(box, 0.50, 0.28))
            hands.move(to: p(box, 0.50, 0.50)); hands.addLine(to: p(box, 0.68, 0.58))
            ctx.stroke(hands, with: .color(color), style: stroke)

        case .bolt:
            var path = Path()
            path.move(to: p(box, 0.56, 0.12))
            path.addLine(to: p(box, 0.30, 0.54))
            path.addLine(to: p(box, 0.50, 0.54))
            path.addLine(to: p(box, 0.44, 0.88))
            path.addLine(to: p(box, 0.72, 0.44))
            path.addLine(to: p(box, 0.52, 0.44))
            path.closeSubpath()
            if filled { ctx.fill(path, with: .color(color)) } else { ctx.stroke(path, with: .color(color), style: stroke) }

        case .wave:
            var path = Path()
            let steps = 28
            for i in 0...steps {
                let t = CGFloat(i) / CGFloat(steps)
                let y = 0.5 + sin(Double(t) * .pi * 2.2) * 0.28
                let pt = p(box, 0.10 + t * 0.80, CGFloat(y))
                if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
            ctx.stroke(path, with: .color(color), style: stroke)

        case .layers:
            for i in 0..<3 {
                var dia = Path()
                let y = 0.28 + CGFloat(i) * 0.22
                dia.move(to: p(box, 0.50, y - 0.12))
                dia.addLine(to: p(box, 0.82, y))
                dia.addLine(to: p(box, 0.50, y + 0.12))
                dia.addLine(to: p(box, 0.18, y))
                dia.closeSubpath()
                ctx.stroke(dia, with: .color(color.opacity(1 - Double(i) * 0.22)), style: stroke)
            }

        case .medal:
            var ring = Path()
            ring.addEllipse(in: CGRect(x: box.minX + box.width * 0.26, y: box.minY + box.height * 0.36,
                                       width: box.width * 0.48, height: box.height * 0.48))
            ctx.stroke(ring, with: .color(color), style: stroke)
            var ribbon = Path()
            ribbon.move(to: p(box, 0.34, 0.14)); ribbon.addLine(to: p(box, 0.46, 0.42))
            ribbon.move(to: p(box, 0.66, 0.14)); ribbon.addLine(to: p(box, 0.54, 0.42))
            ctx.stroke(ribbon, with: .color(color), style: stroke)

        case .gauge:
            var arc = Path()
            arc.addArc(center: CGPoint(x: box.midX, y: box.midY + box.height * 0.16),
                       radius: box.width * 0.34,
                       startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            ctx.stroke(arc, with: .color(color), style: stroke)
            var needle = Path()
            needle.move(to: CGPoint(x: box.midX, y: box.midY + box.height * 0.16))
            needle.addLine(to: p(box, 0.68, 0.32))
            ctx.stroke(needle, with: .color(color), style: stroke)

        case .spark:
            for i in 0..<4 {
                let a = Double(i) * .pi / 4
                var line = Path()
                let c = CGPoint(x: box.midX, y: box.midY)
                line.move(to: CGPoint(x: c.x - cos(a) * box.width * 0.36, y: c.y - sin(a) * box.height * 0.36))
                line.addLine(to: CGPoint(x: c.x + cos(a) * box.width * 0.36, y: c.y + sin(a) * box.height * 0.36))
                ctx.stroke(line, with: .color(color), style: stroke)
            }

        case .grid:
            for i in 0..<2 {
                for j in 0..<2 {
                    var cell = Path()
                    cell.addRoundedRect(in: CGRect(x: box.minX + box.width * (0.18 + CGFloat(i) * 0.34),
                                                   y: box.minY + box.height * (0.18 + CGFloat(j) * 0.34),
                                                   width: box.width * 0.28, height: box.height * 0.28),
                                        cornerSize: CGSize(width: lw, height: lw))
                    ctx.stroke(cell, with: .color(color), style: stroke)
                }
            }

        case .lock:
            var shackle = Path()
            shackle.addArc(center: p(box, 0.50, 0.42), radius: box.width * 0.18,
                           startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            ctx.stroke(shackle, with: .color(color), style: stroke)
            var body = Path()
            body.addRoundedRect(in: CGRect(x: box.minX + box.width * 0.26, y: box.minY + box.height * 0.44,
                                           width: box.width * 0.48, height: box.height * 0.36),
                                cornerSize: CGSize(width: lw * 1.5, height: lw * 1.5))
            ctx.stroke(body, with: .color(color), style: stroke)

        case .info:
            var ring = Path()
            ring.addEllipse(in: box.insetBy(dx: box.width * 0.12, dy: box.height * 0.12))
            ctx.stroke(ring, with: .color(color), style: stroke)
            var dot = Path()
            dot.addEllipse(in: CGRect(x: box.midX - box.width * 0.05, y: box.minY + box.height * 0.26,
                                      width: box.width * 0.10, height: box.height * 0.10))
            ctx.fill(dot, with: .color(color))
            var stem = Path()
            stem.move(to: p(box, 0.50, 0.46)); stem.addLine(to: p(box, 0.50, 0.72))
            ctx.stroke(stem, with: .color(color), style: stroke)
        }
    }
}

/// The app wordmark drawn as concentric arcs, used on the splash screen.
struct TouchcadenceMark: View {
    var size: CGFloat = 96
    var color: Color
    var accent: Color
    /// 0...1 animation phase.
    var phase: Double = 0

    var body: some View {
        Canvas { ctx, canvasSize in
            let s = min(canvasSize.width, canvasSize.height)
            let c = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            for i in 0..<3 {
                let r = s * (0.20 + Double(i) * 0.14)
                var ring = Path()
                ring.addArc(center: c, radius: r,
                            startAngle: .degrees(phase * 360 + Double(i) * 40),
                            endAngle: .degrees(phase * 360 + Double(i) * 40 + 250),
                            clockwise: false)
                ctx.stroke(ring, with: .color(i == 1 ? accent : color.opacity(0.8)),
                           style: StrokeStyle(lineWidth: s * 0.035, lineCap: .round))
            }
            var dot = Path()
            dot.addEllipse(in: CGRect(x: c.x - s * 0.07, y: c.y - s * 0.07, width: s * 0.14, height: s * 0.14))
            ctx.fill(dot, with: .color(accent))
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
    }
}
