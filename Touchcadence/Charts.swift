import SwiftUI

/// Every chart in the app is drawn by hand with `Canvas`. No charting framework is used.

// MARK: - Line chart

struct LineChartCanvas: View {
    @Environment(\.palette) private var palette
    /// Oldest value first.
    let values: [Double]
    var height: CGFloat = 160
    var fill: Bool = true
    var tint: Color? = nil
    var valueLabel: (Double) -> String = { String(Int($0.rounded())) }

    var body: some View {
        GeometryReader { geo in
            // Size comes from the parent geometry, not from the Canvas closure.
            let size = geo.size
            Canvas { ctx, _ in
                draw(ctx: &ctx, size: size)
            }
        }
        .frame(height: height)
    }

    private func draw(ctx: inout GraphicsContext, size: CGSize) {
        let inset = CGSize(width: 8, height: 12)
        let plot = CGRect(x: inset.width, y: inset.height,
                          width: max(1, size.width - inset.width * 2),
                          height: max(1, size.height - inset.height * 2 - 14))
        let color = tint ?? palette.primary

        // Baseline grid
        var grid = Path()
        for i in 0...3 {
            let y = plot.minY + plot.height * CGFloat(i) / 3
            grid.move(to: CGPoint(x: plot.minX, y: y))
            grid.addLine(to: CGPoint(x: plot.maxX, y: y))
        }
        ctx.stroke(grid, with: .color(palette.grid), lineWidth: 0.6)

        guard values.count > 1 else {
            let text = ctx.resolve(Text("Not enough data yet")
                .font(.kCaption).foregroundColor(palette.secondaryText))
            ctx.draw(text, at: CGPoint(x: size.width / 2, y: size.height / 2))
            return
        }

        let maxV = max(values.max() ?? 1, 1)
        let minV = min(values.min() ?? 0, 0)
        let span = max(1, maxV - minV)

        func point(_ i: Int) -> CGPoint {
            let x = plot.minX + plot.width * CGFloat(i) / CGFloat(values.count - 1)
            let norm = (values[i] - minV) / span
            let y = plot.maxY - CGFloat(norm) * plot.height
            return CGPoint(x: x, y: y)
        }

        if fill {
            var area = Path()
            area.move(to: CGPoint(x: point(0).x, y: plot.maxY))
            for i in values.indices { area.addLine(to: point(i)) }
            area.addLine(to: CGPoint(x: point(values.count - 1).x, y: plot.maxY))
            area.closeSubpath()
            ctx.fill(area, with: .linearGradient(
                Gradient(colors: [color.opacity(0.35), color.opacity(0.02)]),
                startPoint: CGPoint(x: plot.midX, y: plot.minY),
                endPoint: CGPoint(x: plot.midX, y: plot.maxY)))
        }

        var line = Path()
        for i in values.indices {
            if i == 0 { line.move(to: point(i)) } else { line.addLine(to: point(i)) }
        }
        ctx.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))

        for i in values.indices where values.count <= 24 {
            var dot = Path()
            let p = point(i)
            dot.addEllipse(in: CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6))
            ctx.fill(dot, with: .color(color))
        }

        let hi = ctx.resolve(Text(valueLabel(maxV)).font(.kCaption).foregroundColor(palette.secondaryText))
        ctx.draw(hi, at: CGPoint(x: plot.minX + 18, y: plot.minY + 2))
        let lo = ctx.resolve(Text(valueLabel(minV)).font(.kCaption).foregroundColor(palette.secondaryText))
        ctx.draw(lo, at: CGPoint(x: plot.minX + 18, y: plot.maxY - 2))
        let caption = ctx.resolve(Text("\(values.count) sessions")
            .font(.kCaption).foregroundColor(palette.secondaryText))
        ctx.draw(caption, at: CGPoint(x: plot.maxX - 40, y: size.height - 6))
    }
}

// MARK: - Bar chart

struct BarChartCanvas: View {
    @Environment(\.palette) private var palette
    let items: [(label: String, value: Double, color: Color)]
    var height: CGFloat = 190

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            Canvas { ctx, _ in draw(ctx: &ctx, size: size) }
        }
        .frame(height: height)
    }

    private func draw(ctx: inout GraphicsContext, size: CGSize) {
        guard !items.isEmpty else { return }
        if items.allSatisfy({ $0.value <= 0 }) {
            let note = ctx.resolve(Text("No data yet")
                .font(.kCaption).foregroundColor(palette.secondaryText))
            ctx.draw(note, at: CGPoint(x: size.width / 2, y: size.height / 2))
            return
        }
        let labelBand: CGFloat = 26
        let plot = CGRect(x: 6, y: 8, width: max(1, size.width - 12), height: max(1, size.height - labelBand - 12))
        let maxV = max(items.map { $0.value }.max() ?? 1, 0.0001)
        let slot = plot.width / CGFloat(items.count)
        let barW = min(slot * 0.6, 34)

        var axis = Path()
        axis.move(to: CGPoint(x: plot.minX, y: plot.maxY))
        axis.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
        ctx.stroke(axis, with: .color(palette.grid), lineWidth: 1)

        for (i, item) in items.enumerated() {
            let cx = plot.minX + slot * (CGFloat(i) + 0.5)
            let h = plot.height * CGFloat(item.value / maxV)
            let rect = CGRect(x: cx - barW / 2, y: plot.maxY - max(2, h), width: barW, height: max(2, h))
            var bar = Path()
            bar.addRoundedRect(in: rect, cornerSize: CGSize(width: 5, height: 5))
            ctx.fill(bar, with: .color(item.color))

            let label = ctx.resolve(Text(item.label).font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(palette.secondaryText))
            ctx.draw(label, at: CGPoint(x: cx, y: plot.maxY + 10))

            if item.value > 0 {
                let v = ctx.resolve(Text(String(Int(item.value.rounded())))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(palette.text))
                ctx.draw(v, at: CGPoint(x: cx, y: rect.minY - 8))
            }
        }
    }
}

// MARK: - Radar chart

struct RadarChartCanvas: View {
    @Environment(\.palette) private var palette
    /// Values normalized 0...1 in draw order.
    let axes: [(label: String, value: Double)]
    var size: CGFloat = 240

    var body: some View {
        GeometryReader { geo in
            let box = geo.size
            Canvas { ctx, _ in draw(ctx: &ctx, box: box) }
        }
        .frame(height: size)
    }

    private func draw(ctx: inout GraphicsContext, box: CGSize) {
        guard axes.count >= 3 else { return }
        let center = CGPoint(x: box.width / 2, y: box.height / 2)
        let radius = min(box.width, box.height) / 2 - 30
        guard radius > 10 else { return }
        let n = axes.count

        func point(_ i: Int, _ f: Double) -> CGPoint {
            let a = -Double.pi / 2 + Double(i) * 2 * .pi / Double(n)
            return CGPoint(x: center.x + cos(a) * radius * f, y: center.y + sin(a) * radius * f)
        }

        for ring in [0.25, 0.5, 0.75, 1.0] {
            var web = Path()
            for i in 0..<n {
                let p = point(i, ring)
                if i == 0 { web.move(to: p) } else { web.addLine(to: p) }
            }
            web.closeSubpath()
            ctx.stroke(web, with: .color(palette.grid), lineWidth: 0.7)
        }
        for i in 0..<n {
            var spoke = Path()
            spoke.move(to: center); spoke.addLine(to: point(i, 1.0))
            ctx.stroke(spoke, with: .color(palette.grid), lineWidth: 0.7)
        }

        var shape = Path()
        for i in 0..<n {
            let p = point(i, max(0.02, min(1, axes[i].value)))
            if i == 0 { shape.move(to: p) } else { shape.addLine(to: p) }
        }
        shape.closeSubpath()
        ctx.fill(shape, with: .color(palette.primary.opacity(0.28)))
        ctx.stroke(shape, with: .color(palette.primary), lineWidth: 2)

        for i in 0..<n {
            var dot = Path()
            let p = point(i, max(0.02, min(1, axes[i].value)))
            dot.addEllipse(in: CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6))
            ctx.fill(dot, with: .color(palette.accent))

            let lp = point(i, 1.22)
            let label = ctx.resolve(Text(axes[i].label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(palette.secondaryText))
            ctx.draw(label, at: lp)
        }
    }
}

// MARK: - Ring gauge

struct RingGauge: View {
    @Environment(\.palette) private var palette
    let value: Double     // 0...1
    let caption: String
    var tint: Color? = nil
    var diameter: CGFloat = 96

    var body: some View {
        let d = diameter
        return Canvas { ctx, _ in
            let center = CGPoint(x: d / 2, y: d / 2)
            let radius = d / 2 - 8
            var track = Path()
            track.addArc(center: center, radius: radius, startAngle: .degrees(0),
                         endAngle: .degrees(360), clockwise: false)
            ctx.stroke(track, with: .color(palette.grid), style: StrokeStyle(lineWidth: 8))
            var arc = Path()
            arc.addArc(center: center, radius: radius, startAngle: .degrees(-90),
                       endAngle: .degrees(-90 + 360 * max(0, min(1, value))), clockwise: false)
            ctx.stroke(arc, with: .color(tint ?? palette.primary),
                       style: StrokeStyle(lineWidth: 8, lineCap: .round))
            let pct = ctx.resolve(Text("\(Int((max(0, min(1, value)) * 100).rounded()))%")
                .font(.system(size: d * 0.20, weight: .bold, design: .rounded))
                .foregroundColor(palette.text))
            ctx.draw(pct, at: CGPoint(x: center.x, y: center.y - d * 0.06))
            let cap = ctx.resolve(Text(caption)
                .font(.system(size: d * 0.11, weight: .regular, design: .rounded))
                .foregroundColor(palette.secondaryText))
            ctx.draw(cap, at: CGPoint(x: center.x, y: center.y + d * 0.16))
        }
        .frame(width: d, height: d)
    }
}
