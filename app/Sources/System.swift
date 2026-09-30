import AppKit
import ServiceManagement
import UserNotifications

/// Everything setup needs from macOS and Codex, with no UI.
enum System {
    static let label = "io.github.comradery64.limitless-codex"
    static let agentPlist = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    static let logPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/limitless-codex.log").path

    // MARK: Processes

    @discardableResult
    static func run(_ path: String, _ args: [String], env: [String: String]? = nil) -> (status: Int32, out: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        if let env { p.environment = env }
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return (-1, "") }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (p.terminationStatus, String(decoding: data, as: UTF8.self))
    }

    /// PATH from the user's login shell. Apps opened from Finder get a bare PATH,
    /// which can't find a Codex installed through npm, pnpm, or Homebrew.
    static let shellPath: String = {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let out = run(shell, ["-ilc", "printf '__LC__%s__LC__' \"$PATH\""]).out
        let parts = out.components(separatedBy: "__LC__")
        let fallback = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        return parts.count >= 3 && !parts[1].isEmpty ? parts[1] : fallback
    }()

    static var env: [String: String] {
        var e = ProcessInfo.processInfo.environment
        e["PATH"] = shellPath
        return e
    }

    // MARK: Codex

    static func codexPath() -> String? {
        if let bin = ProcessInfo.processInfo.environment["CODEX_BIN"], FileManager.default.isExecutableFile(atPath: bin) { return bin }
        for dir in shellPath.split(separator: ":") {
            let p = "\(dir)/codex"
            if FileManager.default.isExecutableFile(atPath: p) { return p }
        }
        return nil
    }

    static func codexSignedIn(_ codex: String) -> Bool {
        run(codex, ["login", "status"], env: env).status == 0
    }

    // MARK: Notifications

    static func notificationState(_ done: @escaping (String) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { s in
            switch s.authorizationStatus {
            case .authorized, .provisional: done(s.alertSetting == .disabled ? "denied" : "granted")
            case .denied: done("denied")
            default: done("unknown")
            }
        }
    }

    // MARK: Background monitor

    /// The monitor binary inside this app. Homebrew installs into a versioned Cellar
    /// path, so point at the stable `opt` link instead; upgrades then keep working.
    static var monitorPath: String {
        let path = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/limitless-codex").path
        if let r = path.range(of: #"/Cellar/limitless-codex/[^/]+/"#, options: .regularExpression) {
            return path.replacingCharacters(in: r, with: "/opt/limitless-codex/")
        }
        return path
    }

    static func serviceState() -> String {
        guard FileManager.default.fileExists(atPath: agentPlist.path) else { return "stopped" }
        if #available(macOS 13, *), SMAppService.statusForLegacyPlist(at: agentPlist) == .requiresApproval { return "blocked" }
        return run("/bin/launchctl", ["print", "gui/\(getuid())/\(label)"]).status == 0 ? "running" : "stopped"
    }

    static func startService() {
        var envVars = ["PATH": shellPath, "THRESHOLD": "99"]
        if let codex = codexPath() { envVars["CODEX_BIN"] = codex }
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [monitorPath, "--mode=daemon"],
            "EnvironmentVariables": envVars,
            "RunAtLoad": true,
            "KeepAlive": true,
            "StandardOutPath": logPath,
            "StandardErrorPath": logPath,
        ]
        try? FileManager.default.createDirectory(at: agentPlist.deletingLastPathComponent(), withIntermediateDirectories: true)
        (plist as NSDictionary).write(to: agentPlist, atomically: true)
        let domain = "gui/\(getuid())"
        run("/bin/launchctl", ["bootout", "\(domain)/\(label)"])
        run("/bin/launchctl", ["bootstrap", domain, agentPlist.path])
    }

    /// Current usage from the monitor, as JSON the setup page renders directly.
    static func status() -> [String: Any]? {
        var e = env
        if let codex = codexPath() { e["CODEX_BIN"] = codex }
        let out = run(monitorPath, ["--mode=status"], env: e).out
        return (try? JSONSerialization.jsonObject(with: Data(out.utf8))) as? [String: Any]
    }

    // MARK: System Settings

    /// Deep links straight to the pane with the switch to change.
    static func settingsURL(_ kind: String) -> URL? {
        let base = "x-apple.systempreferences:"
        switch kind {
        case "notifications": return URL(string: base + "com.apple.Notifications-Settings.extension?id=" + (Bundle.main.bundleIdentifier ?? label))
        case "loginItems": return URL(string: base + "com.apple.LoginItems-Settings.extension")
        case "focus": return URL(string: base + "com.apple.Focus-Settings.extension")
        default: return nil
        }
    }
}
