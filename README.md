# ContinuityCapture

아이폰/아이패드 Continuity Camera(사진 찍기·문서 스캔)를 단축키 한 번으로 실행하고,
결과물을 **Preview를 거치지 않고 바로 파일로 저장**하는 초소형 네이티브 헬퍼 앱.

- 사진 → `~/Pictures/from_iphone/IMG_yyyyMMdd_HHmmss.jpg`
- 스캔 → `~/Pictures/from_iphone/Scan_yyyyMMdd_HHmmss.pdf`
- 상주 프로세스 없음: 호출 순간에만 실행, 저장/취소/타임아웃 시 즉시 종료
- 손쉬운 사용(Accessibility) 권한, UI 스크립팅, iCloud 불필요 — 로컬 직접 전송
- 저장 성공 시 "Glass" 사운드, 기기를 못 찾으면 "Basso" 사운드

## 사용법

앱은 `~/Applications/ContinuityCapture.app`에 설치되며(build.sh가 자동 설치),
경로와 무관하게 이름으로 실행한다:

```sh
open -na ContinuityCapture --args photo
open -na ContinuityCapture --args scan
```

옵션:

| 플래그 | 설명 | 기본값 |
|---|---|---|
| `photo` / `scan` | 사진 찍기 / 문서 스캔 | `photo` |
| `--out DIR` | 저장 폴더 | `~/Pictures/from_iphone` |
| `--device HINT` | 선호 기기 이름 일부 (없으면 첫 기기로 폴백) | `iPhone` |
| `--timeout SEC` | 캡처 대기 시간 | `300` |
| `--regular` | Dock 아이콘 표시 모드 (디버깅용) | 숨김 |
| `--self-test` | 기기 목록만 출력하고 종료 (실행 안 함) | — |

로그: `/tmp/continuitycapture.log`

## 단축키 연결

### 단축어(Shortcuts) 앱 — `shortcuts/` 폴더
1. `iPhone Photo.shortcut`, `iPhone Scan.shortcut` 더블클릭 → 가져오기
2. 단축어 앱 → 설정 → 고급 → **"스크립트 실행 허용"** 켜기 (1회)
3. 각 단축어 상세(ⓘ) → **키보드 단축키 지정** (예: ⌥⌘P 사진, ⌥⌘S 스캔)

### Alfred
Keyword(또는 Hotkey) → Run Script(/bin/zsh)에 위의 `open -na … --args photo` 한 줄.

## 동작 원리

Apple 공식 API인 `NSMenuItem.importFromDeviceIdentifier`(Continuity Camera 매직
메뉴 항목)를 앱 메인 메뉴에 넣으면 시스템이 기기 목록 하위 메뉴를 붙여준다.
macOS 26 기준, 메뉴를 화면에 표시하지 않아도 `submenu.update()` 호출만으로
목록이 채워지며(`SidecarMenuController`가 target), `performActionForItem`으로
헤드리스 발화가 가능. 캡처 결과는 창 안의 NSTextView에 첨부(attachment)로
도착 → 파일로 추출 저장.

주의: 컨텍스트 메뉴 자동 주입(`allowsContextMenuPlugIns`) 경로는 macOS 26에서
서드파티 앱에 동작하지 않았음(2026-07 실측). 메인 메뉴 경로만 사용할 것.

## 빌드 / 설치

```sh
./build.sh   # 유니버설(arm64+x86_64) 빌드 → ad-hoc 서명 → ~/Applications 설치
```

## 새 Mac에 설치 (맥북 / 리셋 후 복원)

**어느 폴더에 클론해도, 사용자명이 무엇이든 상관없다.** 단축어는 앱을 경로가
아닌 LaunchServices 이름(`open -na ContinuityCapture`)으로 찾는다.

```sh
xcode-select --install   # Command Line Tools (이미 있으면 생략)
git clone git@github.com:techjuicelab/continuity-capture.git
cd continuity-capture && ./build.sh
```

이후 `shortcuts/`의 두 파일을 더블클릭해 가져오고 키보드 단축키를 지정하면 끝.

빌드 없이 쓰려면: 다른 Mac의 `~/Applications/ContinuityCapture.app`을 AirDrop·
USB·SMB로 복사해 `~/Applications`에 넣기만 해도 동작한다(자기완결 번들, 외부
의존성 없음, Apple Silicon+Intel 유니버설). 단, 웹 브라우저로 내려받은 경우엔
격리 속성 때문에 첫 실행 시 우클릭→열기가 필요하다. `.app` 번들은 빌드
산출물이라 저장소에는 포함하지 않는다.

## 데이터/보안 노트

- 앱이 만드는 파일은 캡처 결과물과 `/tmp/continuitycapture.log`(실행마다 초기화,
  재부팅 시 자동 삭제) 뿐이다. 설정·캐시·네트워크 접근 없음.
- 필요 권한 없음(카메라·마이크·손쉬운 사용 전부 불필요 — 캡처와 전송은 macOS의
  Continuity 서비스가 수행하고 앱은 결과 데이터만 받는다).
