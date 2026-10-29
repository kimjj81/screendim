import AppKit
import Foundation

let version = "0.1.0"

func usage() {
    let status: String
    if Installer.isInstalled {
        let hk = Installer.installedHotkey ?? Hotkey.default
        status = "installed — hotkey \(hk), agent \(Installer.isRunning ? "running" : "not running")"
    } else {
        status = "not installed — run `screendim install` to set up the hotkey and start at login"
    }
    print("""
    screendim \(version) — dim every display to 0 with one hotkey; any key, click or unlock restores.

    Status: \(status)

    Usage:
      screendim install [--hotkey KEYS]   start at login and listen for the hotkey (default: \(Hotkey.default))
      screendim uninstall                 remove the login item
      screendim dim                       dim now; waits until a key, click or unlock restores
      screendim restore                   restore saved brightness
      screendim status                    show brightness of each display
      screendim agent [--hotkey KEYS]     run the hotkey listener in the foreground (used by install)

    KEYS: modifiers ctrl, opt, cmd, shift joined with "+" and a key, e.g. ctrl+opt+cmd+b, cmd+shift+f12
    """)
}

func hotkeyArg(_ args: [String]) -> Hotkey {
    guard let i = args.firstIndex(of: "--hotkey") else { return Hotkey(Hotkey.default)! }
    guard i + 1 < args.count, let hk = Hotkey(args[i + 1]) else {
        fputs("invalid --hotkey value\n", stderr)
        exit(2)
    }
    return hk
}

/// Restore on SIGUSR1 (another screendim asked); restore then quit on SIGTERM/SIGINT.
func handleSignals(_ dimmer: Dimmer) -> [DispatchSourceSignal] {
    [(SIGUSR1, false), (SIGTERM, true), (SIGINT, true)].map { sig, quit in
        signal(sig, SIG_IGN)
        let src = DispatchSource.makeSignalSource(signal: sig, queue: .main)
        src.setEventHandler {
            dimmer.restore()
            if quit { exit(0) }
        }
        src.resume()
        return src
    }
}

let args = Array(CommandLine.arguments.dropFirst())
switch args.first ?? "help" {
case "install":
    let hk = hotkeyArg(args)
    do {
        let bin = try Installer.install(hotkey: hk)
        print("Installed. Press \(hk.text) to dim all displays; any key, click or unlock restores.")
        print("Login item: \(Installer.plistPath)")
        print("Binary:     \(bin)")
    } catch {
        fputs("install failed: \(error.localizedDescription)\n", stderr)
        exit(1)
    }

case "uninstall":
    Installer.uninstall()
    print("Uninstalled the login item.")

case "dim":
    let dimmer = Dimmer()
    let signals = handleSignals(dimmer)
    dimmer.onRestore = { exit(0) }
    guard dimmer.dim() else { fputs("no controllable displays\n", stderr); exit(1) }
    if !dimmer.isDimmed { exit(0) }   // another screendim already holds the screens dark
    withExtendedLifetime(signals) { RunLoop.main.run() }

case "restore":
    if let s = Dimmer.loadState() {
        if Dimmer.isAlive(s.pid) { kill(s.pid, SIGUSR1) } else { Dimmer.restore(s) }
    }

case "status":
    for d in Displays.snapshot() {
        let pct = Int((d.value / max(d.max, 1) * 100).rounded())
        print("\(d.name.padding(toLength: 10, withPad: " ", startingAt: 0)) \(d.kind.padding(toLength: 6, withPad: " ", startingAt: 0)) \(pct)%")
    }

case "agent":
    let hk = hotkeyArg(args)
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)   // no Dock icon, no menu bar
    let dimmer = Dimmer()
    let signals = handleSignals(dimmer)
    guard HotkeyCenter.register(hk, handler: { dimmer.toggle() }) else {
        fputs("could not register hotkey \(hk.text) (already in use?)\n", stderr)
        exit(1)
    }
    withExtendedLifetime(signals) { app.run() }

case "version", "--version", "-v":
    print(version)

default:
    usage()
}
