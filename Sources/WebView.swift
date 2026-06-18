import SwiftUI
import WebKit

/// Renders an HTML string and wires up the `nativeCall` bridge so the
/// AI-generated UI can talk to the native app.
struct WebView: UIViewRepresentable {
    let html: String

    func makeCoordinator() -> NativeBridge { NativeBridge() }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()

        // Inject the `nativeCall` helper before any page script runs. It turns
        // postMessage (which returns a Promise via the reply handler) into a
        // clean async function the model can call.
        let helper = """
        window.nativeCall = function(action, payload) {
            return window.webkit.messageHandlers.native.postMessage({
                action: action,
                payload: payload || {}
            });
        };
        """
        controller.addUserScript(WKUserScript(source: helper,
                                              injectionTime: .atDocumentStart,
                                              forMainFrameOnly: false))
        controller.addScriptMessageHandler(context.coordinator,
                                           contentWorld: .page,
                                           name: "native")

        let config = WKWebViewConfiguration()
        config.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Only reload when the HTML actually changes, so taps inside the
        // current screen aren't wiped out by SwiftUI re-renders.
        if context.coordinator.lastHTML != html {
            context.coordinator.lastHTML = html
            webView.loadHTMLString(html, baseURL: nil)
        }
    }
}
