import SwiftUI
import WebKit

/// Shared web surface. Serves both the fullscreen stage raised at launch and the
/// Privacy Policy sheet inside Settings.
struct TouchcadenceWebStage: UIViewRepresentable {
    let urlString: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        // REQUIRED, not optional: the frame extends under the home indicator and this is what
        // insets scrollable content back out of it. NEVER .never.
        webView.scrollView.contentInsetAdjustmentBehavior = .always
        // Opaque + solid bg keeps the safe-area band clean (no white flash).
        webView.isOpaque = true
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        // The branch presenting this runs in the dark scheme so the status bar glyphs turn
        // white. Pin the page back to light so that trait never reaches the site as
        // prefers-color-scheme: dark.
        webView.overrideUserInterfaceStyle = .light
        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    // MUST stay empty — reloading here would restart the page on every SwiftUI re-render.
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

/// Shown while the launch check resolves, before the store bootstraps. Uses the palette the
/// user actually picked — `TrainingStore.palettes` is built in `init()` and `settings` loads
/// synchronously, so the right theme is available before `bootstrap()` ever runs.
struct TouchcadenceStageLoadingScreen: View {
    let palette: Palette

    @State private var pulse = false
    @State private var spin: Double = 0

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()

            VStack(spacing: Metrics.spaceL) {
                ZStack {
                    ForEach(0..<3, id: \.self) { ring in
                        Circle()
                            .stroke(palette.accent.opacity(pulse ? 0.08 : 0.30), lineWidth: 2)
                            .frame(width: 150 + CGFloat(ring) * 34,
                                   height: 150 + CGFloat(ring) * 34)
                            .scaleEffect(pulse ? 1.06 : 0.96)
                            .animation(.easeInOut(duration: 1.1)
                                .repeatForever(autoreverses: true)
                                .delay(Double(ring) * 0.18), value: pulse)
                    }
                    TouchcadenceMark(size: 132, color: palette.text,
                                     accent: palette.accent, phase: spin)
                }
                .frame(width: 226, height: 226)

                VStack(spacing: 6) {
                    Text("TOUCHCADENCE")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .tracking(6)
                        .foregroundColor(palette.text)
                    Text("Calibrating...")
                        .font(.kCaption)
                        .foregroundColor(palette.secondaryText)
                }
            }
        }
        .onAppear {
            pulse = true
            withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) { spin = 1 }
        }
    }
}

/// Watches the whole redirect chain — the check domain may only appear mid-chain and never in
/// the final URL, so both are inspected. The chain is never stopped.
final class TouchcadenceRedirectObserver: NSObject, URLSessionTaskDelegate {
    var resolvedURL: URL?
    var foundCheckDomain = false
    private let checkDomain: String

    init(checkDomain: String) { self.checkDomain = checkDomain }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        if let url = request.url?.absoluteString, url.contains(checkDomain) {
            foundCheckDomain = true
        }
        resolvedURL = request.url
        completionHandler(request) // never stop the chain
    }
}
