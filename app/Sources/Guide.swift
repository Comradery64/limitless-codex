import AppKit
import WebKit

/// A floating card that rides along the edge of the System Settings window and tells
/// the user which switch to flip. It follows the window as it moves, hides when
/// System Settings isn't on screen, and never takes focus away from it.
final class Guide: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    let kind: String
    let onClose: () -> Void
    let panel: NSPanel
    let web: WKWebView
    var follow: Timer?
    let size = NSSize(width: 360, height: 330)
    /// Where the arrow points, measured down from the top of System Settings.
    let pointAt: CGFloat = 150
    /// The arrow tip sits this far inside the panel (body padding + arrow width).
    let tipInset: CGFloat = 16

    init(kind: String, onClose: @escaping () -> Void) {
        self.kind = kind
        self.onClose = onClose
        panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false                      // the card draws its own
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false

        let config = WKWebViewConfiguration()
        web = WKWebView(frame: NSRect(origin: .zero, size: size), configuration: config)
        super.init()
        config.userContentController.add(self, name: "lc")
        web.setValue(false, forKey: "drawsBackground")
        web.navigationDelegate = self
        panel.contentView = web

        let dir = Bundle.main.resourceURL!.appendingPathComponent("onboarding")
        web.loadFileURL(dir.appendingPathComponent("overlay.html"), allowingReadAccessTo: dir)
    }

    func start() {
        follow = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in self?.reposition() }
    }

    func webView(_ w: WKWebView, didFinish n: WKNavigation!) { w.evaluateJavaScript("lc.show('\(kind)')") }

    func showSolved() { web.evaluateJavaScript("lc.solved()") }

    func close() {
        follow?.invalidate(); follow = nil
        panel.orderOut(nil)
    }

    func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {
        if (m.body as? [String: Any])?["action"] as? String == "closeGuide" { close(); onClose() }
    }

    // MARK: Following System Settings

    /// The frontmost System Settings window, in Cocoa screen coordinates. Window bounds
    /// come from the window server and need no extra permission.
    private func settingsFrame() -> NSRect? {
        guard let pid = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.systempreferences").first?.processIdentifier,
              let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        else { return nil }
        for w in list where (w[kCGWindowOwnerPID as String] as? pid_t) == pid && (w[kCGWindowLayer as String] as? Int) == 0 {
            guard let b = w[kCGWindowBounds as String] as? NSDictionary, let r = CGRect(dictionaryRepresentation: b), r.width > 200 else { continue }
            let top = NSScreen.screens.first?.frame.maxY ?? 0     // CG measures from the top of the main screen
            return NSRect(x: r.minX, y: top - r.maxY, width: r.width, height: r.height)
        }
        return nil
    }

    private func reposition() {
        guard let s = settingsFrame() else { panel.orderOut(nil); return }
        let screen = NSScreen.screens.first { $0.frame.intersects(s) }?.visibleFrame ?? .infinite
        let gap: CGFloat = 6
        var x = s.maxX + gap - tipInset
        var flip = false
        if x + size.width > screen.maxX {                     // no room on the right: sit on the left
            x = s.minX - gap - size.width + tipInset
            flip = true
        }
        let y = min(max(s.maxY - pointAt - size.height / 2, screen.minY), screen.maxY - size.height)
        let frame = NSRect(x: x, y: y, width: size.width, height: size.height)
        if panel.frame != frame { panel.setFrame(frame, display: true) }
        // Keep the arrow on target even when the panel was clamped to the screen edge.
        let arrowY = (frame.maxY - (s.maxY - pointAt))
        web.evaluateJavaScript("lc.place(\(flip), \(Int(arrowY)))")
        if !panel.isVisible { panel.orderFrontRegardless() }
    }
}
