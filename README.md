# screendim

Dim every connected display to 0 with one hotkey. Any key press, click, or screen unlock (Touch ID or password) restores the previous brightness.

No app window, no Dock icon, no menu bar item: just a CLI and a per-user LaunchAgent.

- Built-in and natively supported displays (e.g. MacBook, Apple displays, some Dell Thunderbolt monitors) use DisplayServices.
- Other external displays use DDC/CI directly over IOAVService. No m1ddc or other helpers needed.
- Global hotkey via Carbon `RegisterEventHotKey`. No Karabiner and no Accessibility permission.

Requires an Apple Silicon Mac.

## Install

### Homebrew

```bash
brew tap kimjj81/screendim https://github.com/kimjj81/screendim
brew install --HEAD screendim
screendim install
```

### From source

```bash
make
./screendim install      # copies the binary to ~/.local/bin and registers the login item
```

## Usage

```
screendim                          help and install status
screendim install [--hotkey KEYS]  start at login and listen for the hotkey (default ctrl+opt+cmd+b)
screendim uninstall                remove the login item
screendim dim                      dim now; waits until a key, click or unlock restores
screendim restore                  restore saved brightness
screendim status                   brightness of each display
```

`KEYS` is modifiers (`ctrl`, `opt`, `cmd`, `shift`) joined with `+` and a key, e.g. `cmd+shift+f12`.

## How it works

- On dim, current brightness is saved to `~/.screendim-state.json` and every display is set to 0.
- A key press or mouse click (mouse movement doesn't count) restores it. While the screen is locked, keys are ignored and unlocking restores it.
- The built-in display is pinned at 0 every 3 seconds so auto-brightness can't raise it.
- Merely touching the Touch ID sensor can't be detected: macOS doesn't expose it to apps. Unlocking with Touch ID works.
- The login item lives at `~/Library/LaunchAgents/io.github.kimjj81.screendim.plist`.

## 한국어 요약

단축키(기본 ⌃⌥⌘B) 하나로 모든 모니터 밝기를 0으로 내리고, 키 입력·클릭·Touch ID 잠금 해제 시 원래 밝기로 돌아옵니다. Dock·메뉴 막대 아이콘 없음, Karabiner·m1ddc 불필요. `screendim install` 한 번이면 로그인 시 자동 실행됩니다.

## License

MIT
