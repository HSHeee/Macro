# color-click-macro

화면에서 특정 **색상**이 나타나는 순간을 감지해 자동으로 클릭하고, 이어서 미리 정의한 클릭/스크롤/OCR 시퀀스를 순서대로 실행하는 AutoHotkey v2 매크로입니다. "특정 UI가 뜨는 타이밍"을 기다렸다가 정해진 순서대로 조작해야 하는 작업을 자동화하려고 만들었습니다.

좌표·색상·텔레그램 값은 `.ahk` 코드가 아니라 `config/` 폴더의 텍스트 파일에서 읽어오므로, **재컴파일 없이 메모장으로 값만 고치고 다시 실행**하면 됩니다.

## 요구 사항

- Windows (멀티모니터·DPI 배율 환경 고려됨)
- [AutoHotkey v2.0](https://www.autohotkey.com/) 이상
- Windows PowerShell 5.1 (스크린샷/캡처 스크립트용, Windows 기본 포함)
- `curl.exe` (텔레그램 텍스트 전송용, Windows 10+ 기본 포함)
- OCR 스텝용 `predict_for_macro/` 폴더 (아래 참고) - Python 설치 불필요, 미리 빌드된 exe를 그대로 씀

## 구성

```
color_click_macro_configurable.ahk   메인 스크립트 (이것만 실행하면 됨)
config/
  config.example.txt                 config.txt 템플릿 (git 추적됨, placeholder 값)
  config.txt                         실제 값 (git 추적 안 함 - 텔레그램 토큰 등 포함)
  sequence_a.txt                     A구역 클릭 시퀀스
  sequence_b.txt                     B구역(그 외) 클릭 시퀀스
predict_for_macro/
  predict_for_macro.exe              OCR 실행 파일 (+ _internal\ 의존 DLL들)
capture_region.ps1                   지정 영역을 PNG로 저장 (메인 스크립트가 동기 호출)
telegram_screenshot.ps1              화면 캡처 후 텔레그램 sendPhoto로 업로드
legacy/                              이전 버전들 (더 이상 유지보수 안 함, 참고용)
  color_click_macro.ahk
  color_click_macro_single.ahk
  color_click_macro_single_sequence.ahk
Screenshot/                          실행 중 캡처 이미지 저장 폴더 (자동 생성, git 추적 안 함)
ocr_log.txt                          런타임 로그 (git 추적 안 함)
```

## 처음 설정하기

1. `config/config.example.txt`를 복사해서 `config/config.txt`로 저장합니다.
2. `config.txt`를 열어 아래 값들을 본인 환경에 맞게 채웁니다.
   - `SearchX1~SearchY2`, `TargetColor`, `Variation` — 감지할 색상과 검색 영역
   - `ZoneX1~ZoneY2` — 감지 위치가 이 사각형 안이면 A시퀀스, 밖이면 B시퀀스
   - `CaptureX1~CaptureY2` — OCR용 캡처 영역
   - `OffsetX` / `OffsetY` — 클릭 좌표 보정
   - `TelegramBotToken` / `TelegramChatId` — 아래 [텔레그램 알림](#텔레그램-알림-선택) 참고
   - `PredictExe` / `CaptchaModel` — `predict_for_macro.exe`와 캡차 모델(`captcha.onnx`)의 절대경로
3. `config/sequence_a.txt`, `sequence_b.txt`에서 클릭 시퀀스를 본인 화면 좌표에 맞게 수정합니다 (형식은 아래 참고).
4. `color_click_macro_configurable.ahk`를 실행합니다. 트레이 아이콘과 "매크로 로드됨" 알림이 뜹니다.
5. `F8`로 감지할 색상의 HEX 값을 뽑아 `config.txt`의 `TargetColor`에 넣습니다.
6. `F9`로 감지 위치를, `F10`으로 현재 로드된 설정을 확인하며 좌표/구역 값을 맞춥니다.
7. `F6`으로 시작, `F7`로 정지합니다.

값을 바꿀 때마다 `config/*.txt`만 고치고 스크립트를 다시 실행하면 됩니다 — AutoHotkey 코드나 컴파일된 exe는 건드릴 필요 없습니다.

### 단축키

| 키 | 기능 |
|----|------|
| `F6` | 매크로 시작 (색상 감지 루프) |
| `F7` | 매크로 정지 |
| `F4` | 진행 중인 시퀀스만 중단 (감지 루프는 유지) |
| `F3` | OCR 실행 로그(`ocr_log.txt`) 열기 |
| `Esc` | 스크립트 완전 종료 (하위 프로세스까지 정리) |
| `F8` | 커서 위치의 실제 HEX 색상값 확인 |
| `F9` | 클릭 없이 감지 위치로 커서만 이동 (좌표 보정) |
| `F10` | 현재 메모리에 로드된 설정값 표시 |
| `F11` | 감지음 On/Off 토글 |
| `F12` | 텔레그램 연동 테스트 |

## config/*.txt 형식

**`config.txt`** — `key=값` 한 줄씩. `;` 뒤는 전부 주석.

**`sequence_a.txt` / `sequence_b.txt`** — 한 줄에 스텝 하나, `|`로 구분:

```
x|y|delay|button|count|capture|run|pressEnter
```

| 필드 | 설명 |
|------|------|
| `x`, `y` | 클릭 좌표 (필수) |
| `delay` | 이 스텝 전에 대기할 ms. 비우면 `config.txt`의 `SequenceDelayMs` 사용 |
| `button`, `count` | 스크롤용. `WheelUp`/`WheelDown`/`WheelLeft`/`WheelRight`와 횟수 |
| `capture` | 캡처해서 저장할 파일명 (예: `a.png`). `run`에서 `{IMG}`로 참조됨 |
| `run` | 실행할 명령. `{IMG}`=방금 캡처한 파일 경로, `{EXE}`/`{MODEL}`=`config.txt`의 `PredictExe`/`CaptchaModel` 값으로 치환 |
| `pressEnter` | `1`이면 `run`의 출력(stdout)을 타이핑한 뒤 Enter까지 누름 |

뒤쪽 빈 필드는 생략 가능합니다. `;`로 시작하는 줄은 통째로, 데이터 뒤에 붙는 `;`도 그 뒤는 전부 주석 처리됩니다.

예시 (캡처 → OCR → 결과 타이핑):
```
803|595||||a.png|"{EXE}" "{IMG}" --model "{MODEL}"|1 ; 보안문자 캡처 -> OCR -> 채팅창 입력 후 Enter
```

좌표는 `F9`(감지 확인)나 `F8`(색상 확인)로 마우스를 올려서 확인하세요.

## predict_for_macro (OCR 실행 파일)

`config/sequence_*.txt`의 `run=` 스텝이 호출하는 캡차 OCR 프로그램입니다. 소스는 이 저장소가 아니라 `captcha_ocr` 프로젝트의 `predict_for_macro.py`이고, PyInstaller로 미리 빌드해서 `predict_for_macro/` 폴더 전체를 여기 커밋해둔 것입니다.

- **`--onedir` 빌드라서 폴더 전체(`predict_for_macro.exe` + `_internal\`)가 하나의 배포 단위입니다.** exe 파일만 따로 복사하면 동작하지 않습니다.
- 재빌드가 필요하면 (모델 교체, 로직 변경 등):
  ```bash
  python -m venv .build_venv
  .build_venv\Scripts\pip install pyinstaller "onnxruntime==1.18.1" numpy pillow
  .build_venv\Scripts\python -m PyInstaller --onedir --name predict_for_macro predict_for_macro.py
  ```
  - **꼭 이 패키지들만 있는 깨끗한 venv에서 빌드하세요.** Anaconda 등 패키지가 잔뜩 깔린 환경에서 빌드하면 불필요한 라이브러리(torch, pandas 등)까지 딸려 들어가 용량이 크게 늘어납니다.
  - **onnxruntime은 반드시 `1.18.1`로 고정하세요.** 최신 버전(1.30.0 확인됨)은 PyInstaller로 얼린 뒤 실행하면 access violation(`0xC0000005`)으로 크래시합니다.
  - `--onefile`이 아니라 `--onedir`을 씁니다. 빌드된 `predict_for_macro/` 폴더를 통째로 이 저장소의 같은 위치에 덮어쓰면 됩니다.

## 텔레그램 알림 (선택)

`config/config.txt`의 `TelegramBotToken`, `TelegramChatId`에 실제 값을 넣으세요.

- 봇 토큰: 텔레그램 [@BotFather](https://t.me/BotFather)에서 발급
- Chat ID: 본인 계정의 숫자 ID

`config.txt`는 `.gitignore`에 포함돼 있어 git에 올라가지 않습니다. `config.example.txt`(placeholder 값)만 커밋됩니다.

- 알림 끄기: `config.txt`에서 `EnableTelegram=0`
- 스크린샷 대신 텍스트만 보내기: `EnableScreenshot=0`

## legacy/

`config/` 도입 이전의 이전 버전들입니다. 좌표·시퀀스가 `.ahk` 코드에 직접 하드코딩돼 있고 더 이상 유지보수하지 않습니다 — 참고용으로만 남겨뒀습니다. 새로 쓰거나 수정할 땐 `color_click_macro_configurable.ahk` + `config/`를 사용하세요.

## 주의

- 자동 클릭/매크로는 대상 서비스의 이용약관에 위배될 수 있습니다. 사용 책임은 사용자에게 있습니다.
- 과거 `color_click_macro_single_sequence_16inch_final.ahk`에 실제 텔레그램 봇 토큰이 평문으로 커밋된 적이 있어 해당 파일과 커밋을 히스토리에서 완전히 제거했습니다. 그 사이 원격 저장소에 노출됐던 적이 있으므로 해당 봇 토큰은 [@BotFather](https://t.me/BotFather)에서 재발급하는 것을 권장합니다 — 저장소를 이전에 클론/포크했다면 이력에 남아있을 수 있으니 확인하세요.
