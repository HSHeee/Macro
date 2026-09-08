# color-click-macro

화면에서 특정 **색상**이 나타나는 순간을 감지해 자동으로 클릭하고, 이어서 미리 정의한 클릭/스크롤/OCR 시퀀스를 순서대로 실행하는 AutoHotkey v2 매크로 모음입니다. "특정 UI가 뜨는 타이밍"을 기다렸다가 정해진 순서대로 조작해야 하는 작업을 자동화하려고 만들었습니다.

## 요구 사항

- Windows (멀티모니터·DPI 배율 환경 고려됨)
- [AutoHotkey v2.0](https://www.autohotkey.com/) 이상
- Windows PowerShell 5.1 (스크린샷/캡처 스크립트용, Windows 기본 포함)
- `curl.exe` (텔레그램 텍스트 전송용, Windows 10+ 기본 포함)
- (선택) OCR 시퀀스를 쓰려면 Python + 예측 스크립트 → 기본값은 `C:\Project\web-image-ML\predict.py` (본인 경로로 수정)

## 구성 파일

| 파일 | 설명 |
|------|------|
| `color_click_macro_single_sequence.ahk` | **메인.** 단일 색상 감지 → 감지 위치가 A구역이면 `ClickSequenceA`, 아니면 `ClickSequenceB` 실행. 화면 캡처 → 외부(OCR) 실행 → 결과 타이핑 스텝 지원, `ocr_log.txt`에 실행 로그 기록 |
| `color_click_macro_single.ahk` | 단일 색상 감지 → 감지 지점 + 고정 좌표(`Bx,By`) 클릭까지만. 시퀀스·OCR 없음 |
| `color_click_macro.ahk` | 위와 같으나 색상을 **여러 개**(`TargetColors` 목록) 순서대로 검색 |
| `capture_region.ps1` | 지정한 화면 영역을 PNG로 저장 (메인 스크립트가 `RunWait`로 동기 호출) |
| `telegram_screenshot.ps1` | 전체 화면을 캡처해 텔레그램 `sendPhoto`로 업로드 (백그라운드 호출) |
| `Screenshot/` | 실행 중 캡처 이미지 저장 폴더 (자동 생성, git 추적 안 함) |
| `ocr_log.txt` | 런타임 로그 (git 추적 안 함) |

## 사용법

1. AutoHotkey v2 설치 후 원하는 `.ahk` 파일을 실행합니다. 트레이 아이콘과 "매크로 로드됨" 알림이 뜹니다.
2. 대상 화면에서 `F8`로 감지할 색상의 HEX 값을 뽑아 스크립트 상단 `TargetColor`(또는 `TargetColors`)에 넣습니다.
3. `F9`로 감지 위치를, `F10`으로 현재 로드된 설정을 확인하며 좌표/구역 값을 맞춥니다.
4. `F6`으로 시작, `F7`로 정지합니다.

### 단축키 (메인 스크립트 기준)

| 키 | 기능 |
|----|------|
| `F6` | 매크로 시작 (색상 감지 루프) |
| `F7` | 매크로 정지 |
| `F4` | 진행 중인 시퀀스만 중단 (감지 루프는 유지) |
| `F3` | OCR 실행 로그(`ocr_log.txt`) 열기 |
| `Esc` | 스크립트 완전 종료 |
| `F8` | 커서 위치의 실제 HEX 색상값 확인 |
| `F9` | 클릭 없이 감지 위치로 커서만 이동 (좌표 보정) |
| `F10` | 현재 메모리에 로드된 설정값 표시 |
| `F11` | 감지음 On/Off 토글 |
| `F12` | 텔레그램 연동 테스트 |

(`color_click_macro.ahk` / `color_click_macro_single.ahk`에는 `F3`·`F4`가 없습니다.)

## 설정

모든 설정값은 각 `.ahk` 파일 상단의 `설정값` 블록에 모여 있습니다. 주요 항목:

- `SearchX1~SearchY2` — 색상을 찾을 화면 영역
- `TargetColor` / `TargetColors` / `Variation` — 감지할 색상과 오차 허용치
- `ZoneX1~ZoneY2` (메인) — 감지 위치가 이 사각형 안이면 A시퀀스, 밖이면 B시퀀스
- `ClickSequenceA` / `ClickSequenceB` (메인) — 순서대로 실행할 스텝
  - 클릭: `{x:.., y:..}`
  - 스크롤: `{x:.., y:.., button:"WheelDown", count:5}`
  - 캡처+실행+타이핑: `{x:.., y:.., capture:"a.png", run:'python ... "{IMG}"', pressEnter:true}`
  - 스텝별 지연: `delay:2500` (생략 시 `SequenceDelayMs`)
- `CaptureX1~CaptureY2` / `CaptureDelayMs` — OCR용 캡처 영역과 캡처 전 대기
- `OffsetX` / `OffsetY` — 클릭 좌표 보정
- 좌표·색상값은 모니터 해상도·창 위치·DPI 배율에 따라 달라지므로 환경에 맞게 직접 잡아야 합니다.

### 텔레그램 알림 (선택)

`.ahk` 파일의 `TelegramBotToken`, `TelegramChatId`는 **더미 placeholder**(`000000000:DUMMY-BOT-TOKEN-...`, `여기에_챗ID_입력`)로 채워져 있습니다. 쓰려면 본인 값으로 교체하세요.

- 봇 토큰: 텔레그램 [@BotFather](https://t.me/BotFather)에서 발급
- Chat ID: 본인 계정의 숫자 ID

> 실제 토큰을 저장소에 커밋하고 싶지 않으면 `config.local.ahk`(`.gitignore`에 포함됨)에 값을 넣고 스크립트에서 `#Include`로 불러오세요.

- 알림 끄기: `EnableTelegram := false`
- 스크린샷 대신 텍스트만 보내기: `EnableScreenshot := false`

## 주의

- 자동 클릭/매크로는 대상 서비스의 이용약관에 위배될 수 있습니다. 사용 책임은 사용자에게 있습니다.
- 유출됐던 실제 토큰은 이 저장소 정리 시 더미 값으로 교체했습니다. 이전에 노출된 토큰은 @BotFather에서 재발급(revoke)하는 것을 권장합니다.
