# screendim

[English](README.md) | **한국어**

단축키 하나로 연결된 모든 모니터 밝기를 0으로 내립니다. 아무 키나 누르거나, 클릭하거나, 화면 잠금을 해제(Touch ID 또는 암호)하면 이전 밝기로 돌아옵니다.

앱 창도, Dock 아이콘도, 메뉴 막대 항목도 없습니다. CLI 하나와 사용자별 LaunchAgent만 있습니다.

- 내장 디스플레이와 macOS가 기본 지원하는 디스플레이(MacBook, Apple 디스플레이, 일부 Dell Thunderbolt 모니터 등)는 DisplayServices로 조절합니다.
- 그 밖의 외장 모니터는 IOAVService로 DDC/CI를 직접 보냅니다. m1ddc 같은 별도 도구가 필요 없습니다.
- 전역 단축키는 Carbon `RegisterEventHotKey`를 씁니다. Karabiner도, 손쉬운 사용 권한도 필요 없습니다.

Apple Silicon Mac과 Xcode Command Line Tools(소스 빌드용)가 필요합니다.

## 설치

### Homebrew (권장)

```bash
brew tap kimjj81/screendim https://github.com/kimjj81/screendim
brew install --HEAD screendim
screendim install
```

`screendim install`은 로그인 항목을 등록하고 단축키 감시를 바로 시작합니다. 로그인 항목은 `$(brew --prefix)/opt/screendim/bin/screendim`을 가리키므로 `brew upgrade` 후에도 다시 설치할 필요가 없습니다.

업데이트:

```bash
brew upgrade --fetch-HEAD screendim
```

실행 중인 에이전트는 다음 로그인 때까지 이전 바이너리를 씁니다. 바로 새 버전을 쓰려면 `screendim install`을 다시 실행하세요.

### 소스에서 빌드

```bash
git clone https://github.com/kimjj81/screendim.git
cd screendim
make
./screendim install      # 바이너리를 ~/.local/bin에 복사하고 로그인 항목을 등록
```

`screendim`을 이름만으로 실행하려면 `~/.local/bin`이 `PATH`에 있어야 합니다.

### 소스 설치에서 Homebrew로 바꾸기

Homebrew로 설치한 뒤 Homebrew 바이너리로 `screendim install`을 실행하세요. 예전 `~/.local/bin/screendim` 복사본을 지우고 로그인 항목이 Homebrew 경로를 가리키도록 바꿉니다.

```bash
$(brew --prefix)/bin/screendim install
hash -r                  # 셸이 기억하는 예전 경로를 지움
```

## 사용법

```
screendim                          도움말과 설치 상태
screendim install [--hotkey KEYS]  로그인 시 실행 등록 + 단축키 감시 (기본 ctrl+opt+cmd+b)
screendim uninstall                로그인 항목 제거 (~/.local/bin 복사본이 있으면 함께 제거)
screendim dim                      지금 어둡게; 키·클릭·잠금 해제가 있을 때까지 대기
screendim restore                  저장된 밝기로 복원
screendim status                   디스플레이별 현재 밝기
```

`KEYS`는 수정 키(`ctrl`, `opt`, `cmd`, `shift`)와 키 하나를 `+`로 이은 것입니다. 키는 영문자, 숫자, `f1`–`f19`, `space`, `escape` 등을 쓸 수 있습니다. 예: `cmd+shift+f12`, `ctrl+opt+d`. 단축키를 바꾸려면 `screendim install --hotkey ...`를 다시 실행하세요.

## 제거

```bash
screendim uninstall
brew uninstall screendim      # Homebrew로 설치한 경우
brew untap kimjj81/screendim
```

## 동작 방식

- 어둡게 할 때 현재 밝기를 `~/.screendim-state.json`에 저장하고 모든 디스플레이를 0으로 설정합니다.
- 많은 모니터가 DDC 밝기 0에서도 백라이트가 꽤 밝게 남기 때문에, DDC로 조절하는 디스플레이는 소프트웨어(감마 테이블)로도 완전히 검게 만듭니다. 복원하면 원래 색으로 돌아옵니다.
- 키를 누르거나 마우스를 클릭하면 복원됩니다. 마우스 이동이나 수정 키만 누르는 것은 해당하지 않습니다.
- 화면이 잠긴 동안에는 키 입력을 무시하고, 잠금을 해제(Touch ID 또는 암호)하면 복원됩니다.
- 3초마다 내장 디스플레이를 0으로 다시 고정하고(자동 밝기 대응) 감마 블랙아웃도 다시 적용합니다.
- Touch ID 센서에 손가락만 대는 동작은 macOS가 앱에 알려주지 않아 감지할 수 없습니다.
- 로그인 항목은 `~/Library/LaunchAgents/io.github.kimjj81.screendim.plist`에 있습니다. 처음에 "백그라운드 항목이 추가됨" 알림이 한 번 뜰 수 있고, 시스템 설정 → 일반 → 로그인 항목 및 확장 프로그램에서 확인할 수 있습니다.
- 에이전트는 UI 요소 프로세스로 실행되어 Dock, 메뉴 막대, ⌘-Tab 어디에도 나타나지 않습니다.

## 문제 해결

**`brew install` 중 `Your Command Line Tools (CLT) does not support macOS …`**
Command Line Tools가 macOS보다 오래된 경우입니다. 시스템 설정 → 일반 → 소프트웨어 업데이트에서 갱신하세요. 업데이트가 보이지 않으면 다시 설치합니다.

```bash
sudo rm -rf /Library/Developer/CommandLineTools
sudo xcode-select --install
```

**`screendim executables are shadowed by commands in ~/.local/bin`**
소스 설치 복사본이 `PATH`에서 먼저 잡히는 경우입니다. [소스 설치에서 Homebrew로 바꾸기](#소스-설치에서-homebrew로-바꾸기)를 참고하세요.

**`could not register hotkey`**
다른 앱이 이미 그 단축키를 쓰고 있습니다. `screendim install --hotkey ...`로 다른 단축키를 지정하세요.

**어두워지지 않는 모니터가 있음**
`screendim status`를 실행해 보세요. 목록에 없는 디스플레이는 기본 밝기 조절도 DDC/CI도 지원하지 않는 경우입니다. 모니터 OSD 메뉴에서 DDC/CI가 켜져 있는지 확인하세요. M1 및 기본형 M2 Mac의 내장 HDMI 포트에 연결된 디스플레이는 DDC를 지원하지 않습니다.

**화면이 어두운 채로 남음**
`screendim restore`를 실행하세요.

## 참고

- 사용자 Mac에서 소스로 빌드하므로 코드 서명이나 노터라이즈가 필요 없습니다(링커가 임시 서명을 하고, 격리 표시가 붙지 않습니다).
- 비공개 프레임워크 DisplayServices와 IOAVService를 사용합니다. 향후 macOS 업데이트에서 바뀔 수 있습니다.

## 라이선스

MIT
