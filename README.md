# screendim

**English** | [한국어](README.ko.md)

Dim every connected display to 0 with one hotkey. Any key press, click, or screen unlock (Touch ID or password) restores the previous brightness.

No app window, no Dock icon, no menu bar item: just a CLI and a per-user LaunchAgent.

- Built-in and natively supported displays (e.g. MacBook, Apple displays, some Dell Thunderbolt monitors) use DisplayServices.
- Other external displays use DDC/CI directly over IOAVService. No m1ddc or other helpers needed.
- Global hotkey via Carbon `RegisterEventHotKey`. No Karabiner and no Accessibility permission.

Requires an Apple Silicon Mac and Xcode Command Line Tools (to build from source).

## Install

### Homebrew (recommended)

```bash
brew tap kimjj81/screendim https://github.com/kimjj81/screendim
brew install --HEAD screendim
screendim install
```

`screendim install` registers the login item and starts the hotkey listener right away. It points at `$(brew --prefix)/opt/screendim/bin/screendim`, so `brew upgrade` keeps working without reinstalling.

To update:

```bash
brew upgrade --fetch-HEAD screendim
```

The running agent keeps the old binary until the next login. To use the new one right away, run `screendim install` again.

### From source

```bash
git clone https://github.com/kimjj81/screendim.git
cd screendim
make
./screendim install      # copies the binary to ~/.local/bin and registers the login item
```

Make sure `~/.local/bin` is on your `PATH` if you want to run `screendim` by name.

### Switching from a source install to Homebrew

Install with Homebrew, then run `screendim install` with the Homebrew binary. That removes the old `~/.local/bin/screendim` copy and repoints the login item:

```bash
$(brew --prefix)/bin/screendim install
hash -r                  # make the shell forget the old path
```

## Usage

```
screendim                          help and install status
screendim install [--hotkey KEYS]  start at login and listen for the hotkey (default ctrl+opt+cmd+b)
screendim uninstall                remove the login item (and the ~/.local/bin copy, if any)
screendim dim                      dim now; waits until a key, click or unlock restores
screendim restore                  restore saved brightness
screendim status                   brightness of each display
```

`KEYS` is modifiers (`ctrl`, `opt`, `cmd`, `shift`) joined with `+` and a key: a letter, a digit, `f1`–`f19`, `space`, `escape`, etc. Examples: `cmd+shift+f12`, `ctrl+opt+d`. To change the hotkey, run `screendim install --hotkey ...` again.

## Uninstall

```bash
screendim uninstall
brew uninstall screendim      # if installed with Homebrew
brew untap kimjj81/screendim
```

## How it works

- On dim, current brightness is saved to `~/.screendim-state.json` and every display is set to 0.
- A key press or mouse click restores it. Mouse movement and modifier keys alone don't count.
- While the screen is locked, keys are ignored; unlocking (Touch ID or password) restores it.
- The built-in display is pinned at 0 every 3 seconds so auto-brightness can't raise it.
- Merely touching the Touch ID sensor can't be detected: macOS doesn't expose it to apps.
- The login item lives at `~/Library/LaunchAgents/io.github.kimjj81.screendim.plist`. macOS may show a one-time "Background item added" notification; the item appears under System Settings → General → Login Items & Extensions.
- The agent runs as a UI element process: it never shows in the Dock, the menu bar, or ⌘-Tab.

## Troubleshooting

**`Your Command Line Tools (CLT) does not support macOS …`** during `brew install`
Your Command Line Tools are older than your macOS. Update them in System Settings → General → Software Update. If no update shows up, reinstall them:

```bash
sudo rm -rf /Library/Developer/CommandLineTools
sudo xcode-select --install
```

**`screendim executables are shadowed by commands in ~/.local/bin`**
A source-install copy comes first on `PATH`. See [Switching from a source install to Homebrew](#switching-from-a-source-install-to-homebrew).

**`could not register hotkey`**
Another app already owns that shortcut. Pick a different one with `screendim install --hotkey ...`.

**A display isn't dimmed**
Run `screendim status`. A display missing from the list doesn't support native brightness or DDC/CI; check that DDC/CI is enabled in the monitor's on-screen menu. Displays on the built-in HDMI port of M1 and base M2 Macs don't support DDC.

**Screens stayed dark**
Run `screendim restore`.

## Notes

- Built from source on your Mac, so no code signing or notarization is needed (the linker ad-hoc signs it, and no quarantine flag is set).
- Uses the private frameworks DisplayServices and IOAVService. They may change in future macOS releases.

## License

MIT
