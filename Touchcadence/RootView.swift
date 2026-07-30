import SwiftUI

/// Custom tab bar: an HStack of Buttons plus a switch on the selected index.
/// SwiftUI's TabView renders Canvas icon views as nothing, so it is never used.
struct RootView: View {
    @EnvironmentObject private var store: TrainingStore
    @Environment(\.palette) private var palette
    @State private var tab: Int = min(4, max(0, SettingsStore.lastScreen))

    private struct TabItem {
        let title: String
        let glyph: GlyphKind
    }

    private let items: [TabItem] = [
        .init(title: "Home", glyph: .home),
        .init(title: "Challenges", glyph: .challenge),
        .init(title: "Statistics", glyph: .stats),
        .init(title: "Programs", glyph: .programs),
        .init(title: "Settings", glyph: .settings)
    ]

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch tab {
                case 0: NavigationStack { HomeView() }
                case 1: NavigationStack { ChallengesView() }
                case 2: NavigationStack { StatisticsView() }
                case 3: NavigationStack { ProgramsView() }
                default: NavigationStack { SettingsView() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            tabBar
        }
        .background(palette.background.ignoresSafeArea())
        .onChange(of: tab) { newValue in SettingsStore.lastScreen = newValue }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Button {
                    withAnimation(.easeInOut(duration: Metrics.animation)) { tab = index }
                } label: {
                    VStack(spacing: 4) {
                        Glyph(kind: item.glyph, size: 24,
                              color: tab == index ? palette.primary : palette.secondaryText.opacity(0.75))
                        Text(item.title)
                            .font(.system(size: 10, weight: tab == index ? .semibold : .regular, design: .rounded))
                            .foregroundColor(tab == index ? palette.primary : palette.secondaryText.opacity(0.75))
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 2)
        .background(
            palette.surface
                .overlay(Rectangle().fill(palette.grid).frame(height: 1), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}
