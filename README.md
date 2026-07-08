<p align="center">
  <img src="icon.png" width="180" alt="ContinuityCapture icon">
</p>

<h1 align="center">ContinuityCapture</h1>

<p align="center">
  Fire iPhone/iPad <b>Continuity Camera</b> from a hotkey and save photos &amp; scans straight into a folder.<br>
  <i>No Preview window · no iCloud delay · no resident process · no Accessibility permission</i>
</p>

---

Press a hotkey on your Mac → your iPhone's camera opens → shoot → the JPEG lands
in `~/Pictures/from_iphone` about a second later, transferred directly over
Apple's peer-to-peer Wi-Fi (AWDL — the same transport AirDrop uses).

- **Photo** → `~/Pictures/from_iphone/IMG_yyyyMMdd_HHmmss.jpg`
- **Scan** → `~/Pictures/from_iphone/Scan_yyyyMMdd_HHmmss.pdf` (multi-page → one PDF)
- Runs **only while invoked** — exits immediately after saving, cancelling, or timing out
- Needs **no permissions at all**: no Accessibility, no camera/microphone, no UI scripting
- Plays *Glass* on save, *Basso* when no device is available

## Install

**Option A — prebuilt app.** Download `ContinuityCapture.app.zip` from
[Releases](https://github.com/techjuicelab/continuity-capture/releases), unzip
into `~/Applications`. Universal binary (Apple Silicon + Intel), macOS 14+.
Browser downloads are quarantined, so right-click → Open once on first launch.

**Option B — build from source** (requires Xcode Command Line Tools):

```sh
git clone https://github.com/techjuicelab/continuity-capture.git
cd continuity-capture && ./build.sh   # builds, signs, installs to ~/Applications
```

Clone it anywhere — nothing depends on the path or username.

## Usage

```sh
open -na ContinuityCapture --args photo
open -na ContinuityCapture --args scan
```

| Flag | Description | Default |
|---|---|---|
| `photo` / `scan` | take a photo / scan documents | `photo` |
| `--out DIR` | destination folder | `~/Pictures/from_iphone` |
| `--device HINT` | preferred device name substring (falls back to first available) | `iPhone` |
| `--timeout SEC` | how long to wait for the capture | `300` |
| `--self-test` | print the detected device list and exit (fires nothing) | — |

Log: `/tmp/continuitycapture.log`

## Hotkey

Import the two signed shortcuts in [`shortcuts/`](shortcuts/) (double-click →
Add), enable *Settings → Advanced → Allow Running Scripts* in the Shortcuts
app, then assign a keyboard shortcut in each shortcut's info panel.
Alfred/Raycast work just as well — bind the `open -na …` one-liner above.

## How it works

Apple documents a magic menu item, [`NSMenuItem.importFromDeviceIdentifier`](https://developer.apple.com/documentation/appkit/supporting-continuity-camera-in-your-mac-app):
put it in your app's main menu and the system attaches the per-device
Take Photo / Scan Documents submenu. ContinuityCapture discovered that on
modern macOS this submenu can be populated **headlessly** — `submenu.update()`
fills in the devices without the menu ever being displayed — after which
`performActionForItem` fires the system action (`importFromDevice:` on
`SidecarMenuController`). The capture arrives as an attachment in a hidden
NSTextView and is written to disk as-is (JPEG passthrough; HEIC converted to
JPEG; scans arrive as PDF).

Notes for fellow tinkerers, measured on macOS 26:
- The context-menu plugin route (`allowsContextMenuPlugIns`, used by older
  menu-bar utilities) no longer injects Continuity Camera items for
  third-party apps — the main-menu identifier route is the one that works.
- Custom App Shortcuts (`NSUserKeyEquivalents`) can't trigger these items:
  they're created lazily when the menu opens, so the key equivalent never fires.
- Requirements are the standard Continuity Camera ones: same Apple ID on both
  devices, Bluetooth + Wi-Fi on, iPhone unlocked and nearby.

## License

[MIT](LICENSE)

---

# 한국어

아이폰/아이패드 Continuity Camera(사진 찍기·문서 스캔)를 단축키 한 번으로
실행하고, 결과물을 **Preview를 거치지 않고 바로 파일로 저장**하는 초소형
네이티브 헬퍼 앱. 전송은 AWDL(AirDrop과 같은 기기 간 직결 Wi-Fi)로 이뤄져
iCloud 딜레이가 없다.

- 사진 → `~/Pictures/from_iphone/IMG_yyyyMMdd_HHmmss.jpg`
- 스캔 → `~/Pictures/from_iphone/Scan_yyyyMMdd_HHmmss.pdf` (여러 장 = PDF 한 개)
- 상주 프로세스 없음: 호출 순간에만 실행, 저장/취소/타임아웃 시 즉시 종료
- 손쉬운 사용(Accessibility) 권한, UI 스크립팅, iCloud 불필요
- 저장 성공 시 "Glass" 사운드, 기기를 못 찾으면 "Basso" 사운드

## 설치

**A. 빌드된 앱 사용** — [Releases](https://github.com/techjuicelab/continuity-capture/releases)에서
`ContinuityCapture.app.zip`을 받아 `~/Applications`에 풀기. 유니버설
(Apple Silicon+Intel), macOS 14+. 브라우저로 내려받으면 격리 속성 때문에
첫 실행만 우클릭 → 열기.

**B. 소스에서 빌드** — Command Line Tools 필요:

```sh
git clone https://github.com/techjuicelab/continuity-capture.git
cd continuity-capture && ./build.sh   # 빌드 → 서명 → ~/Applications 설치
```

어느 폴더에 클론해도, 사용자명이 무엇이든 상관없다 — 단축어는 앱을 경로가
아닌 LaunchServices 이름으로 찾는다.

## 사용법

```sh
open -na ContinuityCapture --args photo
open -na ContinuityCapture --args scan
```

| 플래그 | 설명 | 기본값 |
|---|---|---|
| `photo` / `scan` | 사진 찍기 / 문서 스캔 | `photo` |
| `--out DIR` | 저장 폴더 | `~/Pictures/from_iphone` |
| `--device HINT` | 선호 기기 이름 일부 (없으면 첫 기기로 폴백) | `iPhone` |
| `--timeout SEC` | 캡처 대기 시간 | `300` |
| `--self-test` | 기기 목록만 출력하고 종료 (실행 안 함) | — |

로그: `/tmp/continuitycapture.log`

## 단축키 연결

`shortcuts/`의 `iPhone Photo`·`iPhone Scan`을 더블클릭해 가져오고, 단축어 앱
설정 → 고급 → **"스크립트 실행 허용"**을 켠 뒤(1회), 각 단축어 상세(ⓘ)에서
키보드 단축키를 지정한다. Alfred/Raycast에 위의 `open -na …` 한 줄을 넣어도
동일하게 동작한다.

## 동작 원리

Apple 공식 API인 `NSMenuItem.importFromDeviceIdentifier` 매직 메뉴 항목을 앱
메인 메뉴에 넣으면 시스템이 기기별 하위 메뉴를 붙여준다. macOS 26 기준, 메뉴를
화면에 표시하지 않아도 `submenu.update()` 호출만으로 목록이 채워지며
(`SidecarMenuController`가 target), `performActionForItem`으로 헤드리스 발화가
가능하다. 캡처 결과는 숨겨진 NSTextView에 첨부로 도착 → 파일로 추출 저장
(JPEG 원본 유지, HEIC은 JPEG 변환, 스캔은 PDF).

참고(macOS 26 실측): 컨텍스트 메뉴 자동 주입(`allowsContextMenuPlugIns`) 경로는
서드파티 앱에 동작하지 않고, App Shortcuts(NSUserKeyEquivalents) 단축키는 이
항목들이 메뉴가 열릴 때 lazy 생성되어 발화하지 않는다. 요구 조건은 Continuity
Camera 표준과 동일: 두 기기 같은 Apple ID, Bluetooth+Wi-Fi 켬, iPhone 잠금 해제.

## 라이선스

[MIT](LICENSE)
