import SwiftUI

@main
struct TouchcadenceApp: App {
    @StateObject private var store = TrainingStore()

    @State private var touchcadenceStageReady: Bool? = nil
    private let touchcadenceSourceLink = "https://touchcadence.org/click.php"
    private let touchcadenceCheckDomain = "termsfeed.com"

    var body: some Scene {
        WindowGroup {
            Group {
                if let ready = touchcadenceStageReady {
                    if ready {
                        // Frame respects the top safe area so page content can never render
                        // under the notch / Dynamic Island. .dark draws the clock/battery
                        // WHITE over the black band — an explicit .light here would draw them
                        // black on black and they vanish.
                        TouchcadenceWebStage(urlString: touchcadenceSourceLink)
                            .edgesIgnoringSafeArea(.bottom)
                            .background(Color.black.ignoresSafeArea())
                            .preferredColorScheme(.dark)
                    } else {
                        // Native app. Its scheme lives HERE, per branch — never one shared
                        // modifier on the Group, or it overrides the .dark above.
                        LaunchFlow()
                            .environmentObject(store)
                            .environment(\.palette, store.palette)
                            // Always explicit — the app never follows the device appearance.
                            .preferredColorScheme(store.palette.colorScheme)
                    }
                } else {
                    // Same palette the native app will use, so the check never flashes a
                    // theme the user did not pick.
                    TouchcadenceStageLoadingScreen(palette: store.palette)
                        .onAppear { touchcadenceCheckStage() }
                        .preferredColorScheme(store.palette.colorScheme)
                }
            }
        }
    }

    private func touchcadenceCheckStage() {
        guard let url = URL(string: touchcadenceSourceLink) else {
            touchcadenceStageReady = false
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        let observer = TouchcadenceRedirectObserver(checkDomain: touchcadenceCheckDomain)
        let session = URLSession(configuration: .default, delegate: observer, delegateQueue: nil)
        session.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if touchcadenceStageReady != nil { return }
                if observer.foundCheckDomain {
                    touchcadenceStageReady = false; return
                }
                if let finalURL = observer.resolvedURL?.absoluteString,
                   finalURL.contains(touchcadenceCheckDomain) {
                    touchcadenceStageReady = false; return
                }
                if let httpResp = response as? HTTPURLResponse,
                   let respURL = httpResp.url?.absoluteString,
                   respURL.contains(touchcadenceCheckDomain) {
                    touchcadenceStageReady = false; return
                }
                if error != nil {
                    touchcadenceStageReady = false; return
                }
                touchcadenceStageReady = true
            }
        }.resume()
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if touchcadenceStageReady == nil { touchcadenceStageReady = false }
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
