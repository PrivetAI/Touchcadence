import SwiftUI

@main
struct TouchcadenceApp: App {
    @StateObject private var store = TrainingStore()

    var body: some Scene {
        WindowGroup {
            LaunchFlow()
                .environmentObject(store)
                .environment(\.palette, store.palette)
                // Always explicit — the app never follows the device appearance.
                .preferredColorScheme(store.palette.colorScheme)
        }
    }
}

/// Splash while the SQLite store opens and the bundled catalogue is seeded.
private struct LaunchFlow: View {
    @EnvironmentObject private var store: TrainingStore
    @State private var showApp = false
    @State private var spin: Double = 0

    var body: some View {
        ZStack {
            if showApp && store.ready {
                RootView()
                    .transition(.opacity)
            } else {
                SplashScreen(spin: spin)
            }
        }
        .animation(.easeInOut(duration: Metrics.animation), value: showApp)
        .task {
            FeedbackEngine.shared.prepare()
            withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) { spin = 1 }
            await store.bootstrap()
            try? await Task.sleep(nanoseconds: 500_000_000)
            showApp = true
        }
    }
}

private struct SplashScreen: View {
    @Environment(\.palette) private var palette
    let spin: Double

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()
            VStack(spacing: Metrics.spaceL) {
                TouchcadenceMark(size: 132, color: palette.text, accent: palette.accent, phase: spin)
                VStack(spacing: 6) {
                    Text("TOUCHCADENCE")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .tracking(6)
                        .foregroundColor(palette.text)
                    Text("Offline precision trainer")
                        .font(.kCaption)
                        .foregroundColor(palette.secondaryText)
                }
            }
        }
    }
}
