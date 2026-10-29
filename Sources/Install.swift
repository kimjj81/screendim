// Login item via a per-user LaunchAgent. No app bundle, no Dock or menu bar icon.

import Foundation

enum Installer {
    static let label = "io.github.kimjj81.screendim"
    static let plistPath = NSHomeDirectory() + "/Library/LaunchAgents/\(label).plist"
    static let localBin = NSHomeDirectory() + "/.local/bin/screendim"
    static var domain: String { "gui/\(getuid())" }

    /// Path of the running binary as invoked (symlinks kept), e.g. /opt/homebrew/bin/screendim.
    static func invokedPath() -> String {
        let arg0 = CommandLine.arguments[0]
        if arg0.contains("/") {
            return URL(fileURLWithPath: arg0, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
                .standardizedFileURL.path
        }
        for dir in (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":") {
            let p = "\(dir)/\(arg0)"
            if FileManager.default.isExecutableFile(atPath: p) { return p }
        }
        return arg0
    }

    /// Stable binary path for the LaunchAgent. Homebrew installs use the `opt` link so upgrades keep working;
    /// anything else is copied to ~/.local/bin.
    static func stableBinary() throws -> String {
        let invoked = invokedPath()
        let real = URL(fileURLWithPath: invoked).resolvingSymlinksInPath().path
        if let r = real.range(of: "/Cellar/screendim/") {
            return String(real[..<r.lowerBound]) + "/opt/screendim/bin/screendim"
        }
        if real != localBin {
            let fm = FileManager.default
            try fm.createDirectory(atPath: (localBin as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
            if fm.fileExists(atPath: localBin) { try fm.removeItem(atPath: localBin) }
            try fm.copyItem(atPath: real, toPath: localBin)
        }
        return localBin
    }

    static func install(hotkey: Hotkey) throws -> String {
        let bin = try stableBinary()
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [bin, "agent", "--hotkey", hotkey.text],
            "RunAtLoad": true,
            "KeepAlive": ["SuccessfulExit": false],
            "LimitLoadToSessionType": "Aqua",
            "ProcessType": "Interactive",
        ]
        try FileManager.default.createDirectory(atPath: (plistPath as NSString).deletingLastPathComponent,
                                                withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: URL(fileURLWithPath: plistPath))

        launchctl(["bootout", "\(domain)/\(label)"])
        guard launchctl(["bootstrap", domain, plistPath]) == 0 else {
            throw NSError(domain: "screendim", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "launchctl bootstrap failed"])
        }
        return bin
    }

    static func uninstall() {
        launchctl(["bootout", "\(domain)/\(label)"])
        try? FileManager.default.removeItem(atPath: plistPath)
        if FileManager.default.fileExists(atPath: localBin) { try? FileManager.default.removeItem(atPath: localBin) }
    }

    static var isInstalled: Bool { FileManager.default.fileExists(atPath: plistPath) }

    static var isRunning: Bool { launchctl(["print", "\(domain)/\(label)"]) == 0 }

    static var installedHotkey: String? {
        guard let data = FileManager.default.contents(atPath: plistPath),
              let p = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let args = p["ProgramArguments"] as? [String],
              let i = args.firstIndex(of: "--hotkey"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    @discardableResult
    static func launchctl(_ args: [String]) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return -1 }
        p.waitUntilExit()
        return p.terminationStatus
    }
}
