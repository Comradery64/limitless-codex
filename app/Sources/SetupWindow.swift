import AppKit
import UserNotifications
import WebKit

/// Hosts onboarding/index.html in a vibrant, titlebar-less window and answers its
/// requests. The page owns all UI; this side only checks and changes the system.
final class SetupWindow: NSObject, WKScriptMessageHandler, NSWindowDelegate {
    let window: NSWindow
    let web: WKWebView
    var guide: Guide?
    var poll: Timer?
    var login: Process?
    static let doneKey = "setupComplete"

    override init() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 540),
                          styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                          backing: .buffered, defer: false)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.title = "limitless-codex"
        window.isMovableByWindowBackground = true

        let material = NSVisualEffectView()
        material.material = .underWindowBackground
        material.blendingMode = .behindWindow
        material.state = .active
        window.contentView = material

        let config = WKWebViewConfiguration()
        web = WKWebView(frame: material.bounds, configuration: config)
        super.init()

        let start = UserDefaults.standard.bool(forKey: Self.doneKey) ? "done" : "welcome"
        config.userContentController.addUserScript(WKUserScript(
            source: "window.LC_START = '\(start)';", injectionTime: .atDocumentStart, forMainFrameOnly: true))
        config.userContentController.add(self, name: "lc")
        web.autoresizingMask = [.width, .height]
        web.setValue(false, forKey: "drawsBackground")
        material.addSubview(web)
        window.delegate = self

        let dir = Bundle.main.resourceURL!.appendingPathComponent("onboarding")
        web.loadFileURL(dir.appendingPathComponent("index.html"), allowingReadAccessTo: dir)
    }

    func show() {
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ n: Notification) { guide?.close() }

    /// Push state to the page: lc.update({...}).
    func update(_ patch: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: patch),
              let json = String(data: data, encoding: .utf8) else { return }
        DispatchQueue.main.async { self.web.evaluateJavaScript("lc.update(\(json))") }
    }

    private func background(_ work: @escaping () -> Void) { DispatchQueue.global(qos: .userInitiated).async(execute: work) }

    // MARK: Page requests

    func userContentController(_ c: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let action = body["action"] as? String else { return }
        let arg = body["arg"] as? String
        switch action {
        case "checkCodex": checkCodex()
        case "codexLogin": codexLogin()
        case "checkNotifications": System.notificationState { self.update(["notify": $0]) }
        case "requestNotifications":
            update(["notify": "asking"])
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
                System.notificationState { self.update(["notify": $0]) }
            }
        case "checkService": background { self.update(["service": System.serviceState()]) }
        case "startService":
            update(["service": "starting"])
            background {
                System.startService()
                // launchd reports the job right away; give macOS a moment to decide on approval.
                Thread.sleep(forTimeInterval: 1.5)
                self.update(["service": System.serviceState()])
            }
        case "sendTest": Notifier.post("Test: notifications reach you") { self.update(["test": "sent"]) }
        case "readStatus": background { if let s = System.status() { self.update(["status": s]) } }
        case "openSettings": if let arg { openSettings(arg) }
        case "copy":
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(arg ?? "", forType: .string)
        case "finish":
            UserDefaults.standard.set(true, forKey: Self.doneKey)
            window.close()
        default: break
        }
    }

    private func checkCodex() {
        background {
            guard let codex = System.codexPath() else {
                self.update(["codex": "missing"])
                // Keep checking so installing Codex in Terminal moves the page on by itself.
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self.checkCodex() }
                return
            }
            self.update(["codex": System.codexSignedIn(codex) ? "ok" : "signedOut"])
        }
    }

    private func codexLogin() {
        guard let codex = System.codexPath() else { return checkCodex() }
        update(["codex": "signingIn"])
        let p = Process()
        p.executableURL = URL(fileURLWithPath: codex)
        p.arguments = ["login"]
        p.environment = System.env
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        p.terminationHandler = { _ in self.checkCodex() }
        try? p.run()
        login = p
    }

    // MARK: Guided System Settings changes

    /// Open the exact pane, attach the guide beside System Settings, and watch for the
    /// change so the guide can confirm it and hand the user back to setup.
    private func openSettings(_ kind: String) {
        guard let url = System.settingsURL(kind) else { return }
        NSWorkspace.shared.open(url)
        guide?.close()
        guide = Guide(kind: kind) { [weak self] in self?.guideClosed() }
        guide?.start()

        poll?.invalidate()
        guard kind != "focus" else { return }   // Focus can't be read; the user confirms it
        poll = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            guard let self else { return }
            if kind == "notifications" {
                System.notificationState { s in if s == "granted" { self.solved(["notify": s]) } }
            } else {
                self.background {
                    // Once approved, launchd still needs the job loaded again before it runs.
                    if System.serviceState() == "stopped" { System.startService() }
                    if System.serviceState() == "running" { self.solved(["service": "running"]) }
                }
            }
        }
    }

    private func solved(_ patch: [String: Any]) {
        DispatchQueue.main.async {
            guard self.poll != nil else { return }
            self.poll?.invalidate(); self.poll = nil
            self.guide?.showSolved()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                self.guide?.close()
                self.bringBack()
                self.update(patch)
            }
        }
    }

    private func guideClosed() {
        poll?.invalidate(); poll = nil
        guide = nil
        bringBack()
        System.notificationState { self.update(["notify": $0]) }
        background { self.update(["service": System.serviceState()]) }
    }

    private func bringBack() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
