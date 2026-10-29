// Dim all displays, then restore on the next key press, click, or screen unlock.

import CoreGraphics
import Foundation

struct State: Codable {
    var pid: Int32
    var displays: [Saved]
}

final class Dimmer {
    static let dimLevel: Float = 0.0           // 0~1 of each display's range
    static let graceSeconds = 0.8              // ignore input right after the hotkey itself
    static let statePath = NSHomeDirectory() + "/.screendim-state.json"
    static let restoredPath = NSHomeDirectory() + "/.screendim-restored"

    private var state: State?
    private var timer: Timer?
    private var unlockObserver: NSObjectProtocol?
    var onRestore: (() -> Void)?

    var isDimmed: Bool { state != nil }

    // MARK: State file shared between the agent and one-shot CLI runs

    static func loadState() -> State? {
        guard let data = FileManager.default.contents(atPath: statePath) else { return nil }
        return try? JSONDecoder().decode(State.self, from: data)
    }

    static func isAlive(_ pid: Int32) -> Bool { kill(pid, 0) == 0 }

    /// Another live process is holding the screens dark.
    static func dimmedElsewhere() -> State? {
        guard let s = loadState(), s.pid != getpid(), isAlive(s.pid) else { return nil }
        return s
    }

    static func restoredRecently() -> Bool {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: restoredPath),
              let t = attrs[.modificationDate] as? Date else { return false }
        return Date().timeIntervalSince(t) < 1.5
    }

    static func restore(_ s: State) {
        s.displays.forEach { Displays.set($0, raw: $0.value) }
        try? FileManager.default.removeItem(atPath: statePath)
        FileManager.default.createFile(atPath: restoredPath, contents: nil)
    }

    // MARK: Dim / restore

    /// Hotkey behaviour: dim, or restore if already dimmed.
    func toggle() {
        if isDimmed { restore(); return }
        if let other = Dimmer.dimmedElsewhere() { kill(other.pid, SIGUSR1); return }
        if Dimmer.restoredRecently() { return }   // this key press just woke the screens
        if let stale = Dimmer.loadState() { Dimmer.restore(stale); return }
        dim()
    }

    @discardableResult
    func dim() -> Bool {
        guard !isDimmed else { return true }
        if Dimmer.dimmedElsewhere() != nil { return true }
        if let stale = Dimmer.loadState() { Dimmer.restore(stale) }

        let saved = Displays.snapshot()
        guard !saved.isEmpty else { return false }
        let s = State(pid: getpid(), displays: saved)
        try? JSONEncoder().encode(s).write(to: URL(fileURLWithPath: Dimmer.statePath))
        state = s
        saved.forEach { Displays.set($0, fraction: Dimmer.dimLevel) }
        watch(start: Date())
        return true
    }

    func restore() {
        guard let s = state else { return }
        state = nil
        timer?.invalidate()
        timer = nil
        if let o = unlockObserver { DistributedNotificationCenter.default().removeObserver(o) }
        unlockObserver = nil
        Dimmer.restore(s)
        onRestore?()
    }

    private func watch(start: Date) {
        // Touch ID / password unlock while dimmed → restore.
        unlockObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main
        ) { [weak self] _ in self?.restore() }

        var lastPin = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            guard let self, let s = self.state else { return }
            let elapsed = Date().timeIntervalSince(start)
            // Key press or click (not mouse movement). Ignored while locked; unlock handles that.
            if !Dimmer.screenIsLocked() && elapsed > Dimmer.graceSeconds {
                let src = CGEventSourceStateID.combinedSessionState
                let idle = [CGEventType.keyDown, .leftMouseDown, .rightMouseDown]
                    .map { CGEventSource.secondsSinceLastEventType(src, eventType: $0) }
                    .min() ?? .infinity
                if idle < elapsed - Dimmer.graceSeconds { self.restore(); return }
            }
            // Auto-brightness on the built-in display can creep back up; pin native displays.
            if Date().timeIntervalSince(lastPin) > 3 {
                lastPin = Date()
                s.displays.filter { $0.kind == "native" }.forEach { Displays.set($0, fraction: Dimmer.dimLevel) }
            }
        }
    }

    static func screenIsLocked() -> Bool {
        guard let d = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return (d["CGSSessionScreenIsLocked"] as? Bool) ?? false
    }
}
