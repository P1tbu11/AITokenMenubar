import AppKit
import WebKit

class AuthWindowController: NSObject {
    private var window: NSWindow?
    private let onComplete: () -> Void
    private var webView: WKWebView?

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        super.init()
    }

    func show() {
        let width: CGFloat = 480
        let height: CGFloat = 620

        let webConfig = WKWebViewConfiguration()
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: width, height: height),
                            configuration: webConfig)
        webView?.navigationDelegate = self
        webView?.allowsBackForwardNavigationGestures = false

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window?.title = "登录 AI Token"
        window?.contentView = webView
        window?.center()
        window?.isReleasedWhenClosed = false
        window?.delegate = self
        window?.makeKeyAndOrderFront(nil)

        let request = URLRequest(url: URL(string: "https://aitoken.woa.com/profile/usage")!)
        webView?.load(request)
    }

    func close() {
        window?.close()
        window = nil
        webView = nil
    }
}

extension AuthWindowController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url else { return }

        if url.host == "aitoken.woa.com" && url.path == "/profile/usage" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.onComplete()
            }
        }
    }
}

extension AuthWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // user manually closed the auth window
    }
}
