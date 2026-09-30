import AppKit
import UserNotifications

// limitless-codex.app has two jobs:
//   LimitlessCodex --notify "<message>"   post one notification and exit (called by the monitor)
//   LimitlessCodex                        open the setup window
let args = CommandLine.arguments
let app = NSApplication.shared
let delegate: NSApplicationDelegate

if let i = args.firstIndex(of: "--notify"), i + 1 < args.count {
    delegate = NotifyOnce(message: args[i + 1])
} else {
    delegate = SetupApp()
}
app.delegate = delegate
app.run()

/// Posts a single notification, then quits.
final class NotifyOnce: NSObject, NSApplicationDelegate {
    let message: String
    init(message: String) { self.message = message }

    func applicationDidFinishLaunching(_ note: Notification) {
        Notifier.post(message) { DispatchQueue.main.asyncAfter(deadline: .now() + 1) { NSApp.terminate(nil) } }
    }
}

/// The setup window. Opening the app again after setup lands on the status page.
final class SetupApp: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var setup: SetupWindow?

    func applicationDidFinishLaunching(_ note: Notification) {
        UNUserNotificationCenter.current().delegate = self
        NSApp.setActivationPolicy(.regular)
        setup = SetupWindow()
        setup?.show()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool { true }

    // Show the test notification even though our window is in front.
    func userNotificationCenter(_ c: UNUserNotificationCenter, willPresent n: UNNotification,
                                withCompletionHandler done: @escaping (UNNotificationPresentationOptions) -> Void) {
        done([.banner, .sound])
    }
}

enum Notifier {
    static func post(_ body: String, then: @escaping () -> Void = {}) {
        let content = UNMutableNotificationContent()
        content.title = "limitless-codex"
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { _ in then() }
    }
}
