import SwiftUI

// MARK: - Screen scaffold

/// Standard page chrome: background, title row, scrolling body with bottom clearance
/// for the floating tab bar.
struct ScreenScaffold<Content: View>: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    let title: String
    var subtitle: String? = nil
    var scrolls: Bool = true
    /// Shows the app's own back control. The system navigation bar is always hidden so no
    /// SF Symbol chevron is ever drawn.
    var back: Bool = false
    /// Extra bottom padding so the last row is never flush against the tab bar.
    var bottomClearance: CGFloat = 28
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Metrics.spaceM) {
                HStack(alignment: .top, spacing: Metrics.spaceS) {
                    if back {
                        GlyphButton(kind: .back, size: 18, box: 40) { dismiss() }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title).font(.kTitle).foregroundColor(palette.text)
                            .fixedSize(horizontal: false, vertical: true)
                        if let subtitle {
                            Text(subtitle).font(.kCaption).foregroundColor(palette.secondaryText)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Metrics.spaceM)
                .padding(.top, Metrics.spaceS)

                if scrolls {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: Metrics.spaceM) {
                            content()
                        }
                        .padding(.horizontal, Metrics.spaceM)
                        .padding(.bottom, bottomClearance)
                    }
                } else {
                    VStack(alignment: .leading, spacing: Metrics.spaceM) {
                        content()
                    }
                    .padding(.horizontal, Metrics.spaceM)
                    .padding(.bottom, bottomClearance)
                    .frame(maxHeight: .infinity, alignment: .top)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Cards

struct Card<Content: View>: View {
    @Environment(\.palette) private var palette
    var padding: CGFloat = Metrics.spaceM
    var corner: CGFloat = Metrics.cornerMedium
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spaceS) { content() }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(palette.grid, lineWidth: 1)
            )
    }
}

// MARK: - Buttons

struct PrimaryButton: View {
    @Environment(\.palette) private var palette
    let title: String
    var glyph: GlyphKind? = nil
    var tone: Tone = .primary
    var action: () -> Void

    enum Tone { case primary, accent, neutral, danger }

    private var fill: Color {
        switch tone {
        case .primary: return palette.primary
        case .accent: return palette.accent
        case .neutral: return palette.elevated
        case .danger: return palette.error
        }
    }

    private var label: Color {
        switch tone {
        case .neutral: return palette.text
        case .accent: return palette.isDark ? Color.black : Color.white
        default: return .white
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Metrics.spaceS) {
                if let glyph { Glyph(kind: glyph, size: 20, color: label, filled: true) }
                Text(title).font(.kHeadline).foregroundColor(label)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: Metrics.cornerSmall, style: .continuous).fill(fill))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A button whose label is only a glyph. `.contentShape` is applied to the SIZED LABEL —
/// a Canvas glyph over a clear background has no hit area otherwise.
struct GlyphButton: View {
    @Environment(\.palette) private var palette
    let kind: GlyphKind
    var size: CGFloat = 22
    var box: CGFloat = 44
    var color: Color? = nil
    var background: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if background {
                    RoundedRectangle(cornerRadius: Metrics.cornerSmall, style: .continuous)
                        .fill(palette.elevated)
                }
                Glyph(kind: kind, size: size, color: color ?? palette.text)
            }
            .frame(width: box, height: box)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Navigation row

struct NavRow: View {
    @Environment(\.palette) private var palette
    let glyph: GlyphKind
    let title: String
    var detail: String? = nil
    var tint: Color? = nil

    var body: some View {
        HStack(spacing: Metrics.spaceM) {
            ZStack {
                RoundedRectangle(cornerRadius: Metrics.cornerSmall, style: .continuous)
                    .fill((tint ?? palette.primary).opacity(0.16))
                Glyph(kind: glyph, size: 22, color: tint ?? palette.primary)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.kBody).foregroundColor(palette.text)
                if let detail {
                    Text(detail).font(.kCaption).foregroundColor(palette.secondaryText)
                }
            }
            Spacer(minLength: Metrics.spaceS)
            Glyph(kind: .forward, size: 16, color: palette.secondaryText)
        }
        .padding(Metrics.spaceM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Metrics.cornerMedium, style: .continuous).fill(palette.surface))
        .overlay(RoundedRectangle(cornerRadius: Metrics.cornerMedium, style: .continuous).stroke(palette.grid, lineWidth: 1))
        .contentShape(Rectangle())
    }
}

// MARK: - Badges and tiles

struct RankBadge: View {
    @Environment(\.palette) private var palette
    let rank: Rank
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle().fill(palette.rankColor(rank).opacity(0.18))
            Circle().stroke(palette.rankColor(rank), lineWidth: 2)
            Text(rank.title)
                .font(.system(size: size * (rank == .sss ? 0.30 : 0.38), weight: .bold, design: .rounded))
                .foregroundColor(palette.rankColor(rank))
        }
        .frame(width: size, height: size)
    }
}

struct StatTile: View {
    @Environment(\.palette) private var palette
    let label: String
    let value: String
    var tint: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(tint ?? palette.text)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label).font(.kCaption).foregroundColor(palette.secondaryText)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(Metrics.spaceM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Metrics.cornerSmall, style: .continuous).fill(palette.elevated))
    }
}

struct Chip: View {
    @Environment(\.palette) private var palette
    let text: String
    var color: Color? = nil

    var body: some View {
        Text(text)
            .font(.kCaption)
            .foregroundColor(color ?? palette.secondaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill((color ?? palette.secondaryText).opacity(0.14))
            )
    }
}

struct BarMeter: View {
    @Environment(\.palette) private var palette
    let value: Double        // 0...1
    var tint: Color? = nil
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(palette.grid)
                Capsule().fill(tint ?? palette.primary)
                    .frame(width: max(0, min(1, value)) * geo.size.width)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Option picker

/// Wrapping row of selectable options. Used instead of system pickers.
struct OptionGrid<T: Hashable>: View {
    @Environment(\.palette) private var palette
    let options: [T]
    let title: (T) -> String
    @Binding var selection: T
    var columns: Int = 3

    var body: some View {
        let rows = stride(from: 0, to: options.count, by: columns).map {
            Array(options[$0..<min($0 + columns, options.count)])
        }
        VStack(spacing: Metrics.spaceS) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: Metrics.spaceS) {
                    ForEach(row, id: \.self) { option in
                        Button { selection = option } label: {
                            Text(title(option))
                                .font(.kCaption)
                                .foregroundColor(selection == option ? (palette.isDark ? .black : .white) : palette.text)
                                .lineLimit(1).minimumScaleFactor(0.7)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: Metrics.cornerSmall, style: .continuous)
                                        .fill(selection == option ? palette.primary : palette.elevated)
                                )
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

// MARK: - Empty state

struct EmptyNote: View {
    @Environment(\.palette) private var palette
    let text: String

    var body: some View {
        HStack(spacing: Metrics.spaceM) {
            Glyph(kind: .info, size: 22, color: palette.secondaryText)
            Text(text).font(.kBody).foregroundColor(palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Metrics.spaceM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Metrics.cornerMedium, style: .continuous).fill(palette.surface))
    }
}

// MARK: - Section header

struct SectionTitle: View {
    @Environment(\.palette) private var palette
    let text: String
    var trailing: String? = nil

    var body: some View {
        HStack {
            Text(text).font(.kHeadline).foregroundColor(palette.text)
            Spacer()
            if let trailing {
                Text(trailing).font(.kCaption).foregroundColor(palette.secondaryText)
            }
        }
    }
}

// MARK: - Training row

struct TrainingRow: View {
    @Environment(\.palette) private var palette
    let training: Training
    var best: Int? = nil
    var rank: Rank? = nil
    var favorite: Bool = false

    var body: some View {
        HStack(spacing: Metrics.spaceM) {
            ZStack {
                RoundedRectangle(cornerRadius: Metrics.cornerSmall, style: .continuous)
                    .fill(palette.categoryColor(training.category).opacity(0.16))
                Glyph(kind: glyph(for: training.movement), size: 22,
                      color: palette.categoryColor(training.category))
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(training.name).font(.kBody).foregroundColor(palette.text)
                        .lineLimit(1)
                    if favorite {
                        Glyph(kind: .starFilled, size: 12, color: palette.warning)
                    }
                }
                Text("\(training.category.title) · \(training.difficulty.title) · \(training.duration)s")
                    .font(.kCaption).foregroundColor(palette.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 2) {
                if let rank { RankBadge(rank: rank, size: 30) }
                if let best, best > 0 {
                    Text("\(best)").font(.kCaption).foregroundColor(palette.secondaryText)
                }
            }
        }
        .padding(Metrics.spaceM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Metrics.cornerMedium, style: .continuous).fill(palette.surface))
        .overlay(RoundedRectangle(cornerRadius: Metrics.cornerMedium, style: .continuous).stroke(palette.grid, lineWidth: 1))
        .contentShape(Rectangle())
    }

    func glyph(for movement: MovementType) -> GlyphKind {
        switch movement {
        case .linear, .accelerate, .decelerate: return .bolt
        case .circle, .ellipse, .reverse: return .rings
        case .sine, .eight: return .wave
        case .zigzag, .dash: return .spark
        case .random, .teleport: return .grid
        case .pendulum, .spiral: return .gauge
        case .combined: return .layers
        }
    }
}
