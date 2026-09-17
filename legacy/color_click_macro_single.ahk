#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Event"
SetMouseDelay -1          ; 클릭 사이 인위적 지연 제거 (속도 최우선)
SetKeyDelay -1, -1
CoordMode "Pixel", "Screen"
CoordMode "Mouse", "Screen"

; =======================================================
;  설정값 - 필요하면 여기만 수정하세요
; =======================================================
SearchX1 := 1
SearchY1 := 150
SearchX2 := 2200
SearchY2 := 1700

TargetColor := 0xD1CAF9   ; F8로 확인한 실제 색상값 #D1CAF9
Variation   := 15         ; 색상 오차 허용치(0~255). 감지가 안 되면 늘리고,
                           ; 엉뚱한 곳에서 반응하면 줄이세요.

Bx := 2510
By := 1610

; A클릭 좌표 보정값 - F5 테스트로 어긋난 만큼 확인 후 조정하세요
OffsetX := 0
OffsetY := 5

PollDelay := 1             ; 색상을 못 찾았을 때 다음 검색까지 대기(ms). 낮을수록 반응 빠름
CooldownAfterClick := 300  ; 클릭 후 다음 감지까지 대기(ms). 너무 낮으면 같은 지점 연타됨

EnableSound := true        ; 감지시 소리 On/Off (F11로도 토글 가능)
BeepFreq  := 1500          ; 비프음 주파수(Hz)
BeepDurMs := 60             ; 비프음 길이(ms)

EnableTelegram   := true                  ; 감지시 텔레그램 전송 켜짐
TelegramBotToken := "000000000:DUMMY-BOT-TOKEN-발급받아_교체하세요"   ; @BotFather에서 발급받은 실제 토큰으로 교체
TelegramChatId   := "여기에_챗ID_입력"      ; 본인 Chat ID(숫자)로 교체
EnableScreenshot := true                  ; true면 텍스트 대신 "화면 캡처+캡션"으로 전송

Running := false
LoadedAt := A_Now   ; 이 스크립트 인스턴스가 로드된 시각 (재시작 확인용)
TrayTip "매크로 로드됨", "로드시각 " LoadedAt " / F10으로 현재 설정 확인", 1

; =======================================================
;  단축키
; =======================================================
F6:: StartMacro()
F7:: StopMacro("F7로 정지")
Esc:: ExitApp()   ; 스크립트 자체를 완전히 강제종료
F9:: TestDetect()   ; 클릭 없이 감지 위치로 커서만 이동 (좌표 보정용)
F8:: PickColor()    ; 현재 커서가 가리키는 지점의 실제 HEX 색상 확인용
F10:: ShowConfig()  ; 지금 메모리에 실제로 로드된 설정값 확인용
F11:: ToggleSound()  ; 감지음 On/Off 토글
F12:: TestTelegram()  ; 텔레그램 연동 테스트용 (스크린샷 켜져있으면 스크린샷으로 테스트)

ToggleSound() {
    global EnableSound
    EnableSound := !EnableSound
    ToolTip "감지음: " (EnableSound ? "켜짐" : "꺼짐")
    SetTimer () => ToolTip(), -1000
}

ShowConfig() {
    global TargetColor, Variation, SearchX1, SearchY1, SearchX2, SearchY2
    global Bx, By, OffsetX, OffsetY, LoadedAt
    global EnableTelegram, TelegramBotToken, TelegramChatId, EnableScreenshot
    MsgBox(
        "로드시각: " LoadedAt "`n"
        "TargetColor: " TargetColor "`n"
        "Variation: " Variation "`n"
        "검색범위: (" SearchX1 "," SearchY1 ") ~ (" SearchX2 "," SearchY2 ")`n"
        "B좌표: (" Bx "," By ")`n"
        "A보정(Offset): (" OffsetX "," OffsetY ")`n"
        "텔레그램: " (EnableTelegram ? "켜짐" : "꺼짐") " / 스크린샷: " (EnableScreenshot ? "켜짐" : "꺼짐") " (토큰 " (StrLen(TelegramBotToken)>10 ? "설정됨" : "미설정") ", ChatId " (StrLen(TelegramChatId)>0 && TelegramChatId!="여기에_챗ID_입력" ? "설정됨" : "미설정") ")",
        "현재 메모리에 로드된 설정값"
    )
}

; 텔레그램으로 텍스트만 전송 - curl.exe를 별도 프로세스로 백그라운드 실행해서
; 네트워크 응답을 기다리지 않음 (감지/클릭 루프에 전혀 영향 없음)
NotifyTelegram(msg) {
    global TelegramBotToken, TelegramChatId
    url := "https://api.telegram.org/bot" TelegramBotToken "/sendMessage"
    cmd := 'curl.exe -s -X POST "' url '" -d "chat_id=' TelegramChatId '" --data-urlencode "text=' msg '"'
    try
        Run(cmd, , "Hide")
    catch as e
        ToolTip "텔레그램 전송 실패: " e.Message
}

; 화면을 캡처해서 텔레그램으로 전송 - telegram_screenshot.ps1을 별도 프로세스로
; 백그라운드 실행 (캡처/업로드가 오래 걸려도 매크로 루프는 전혀 안 막힘)
NotifyTelegramScreenshot(caption) {
    global TelegramBotToken, TelegramChatId
    scriptPath := A_ScriptDir "\telegram_screenshot.ps1"
    cmd := 'powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "'
        . scriptPath '" -Token "' TelegramBotToken '" -ChatId "' TelegramChatId '" -Caption "' caption '"'
    try
        Run(cmd, , "Hide")
    catch as e
        ToolTip "스크린샷 전송 실패: " e.Message
}

; F12 테스트용 - EnableScreenshot 상태에 따라 스크린샷 or 텍스트로 테스트
TestTelegram() {
    global EnableScreenshot
    if (EnableScreenshot)
        NotifyTelegramScreenshot("테스트 스크린샷입니다 (F12로 보냄)")
    else
        NotifyTelegram("테스트 메시지입니다 (F12로 보냄)")
}

PickColor() {
    MouseGetPos &mx, &my
    c := PixelGetColor(mx, my)
    ToolTip "커서 위치 색상: " c "  (X=" mx ",Y=" my ")`n이 값을 TargetColor에 넣으세요"
    SetTimer () => ToolTip(), -4000
}

TestDetect() {
    global SearchX1, SearchY1, SearchX2, SearchY2, TargetColor, Variation, OffsetX, OffsetY
    found := PixelSearch(&fx, &fy, SearchX1, SearchY1, SearchX2, SearchY2, TargetColor, Variation)
    if (found) {
        MouseMove fx + OffsetX, fy + OffsetY
        ToolTip "감지: raw=" fx "," fy "  보정후=" (fx+OffsetX) "," (fy+OffsetY) "`n(클릭 안 함 - 커서 위치만 확인하세요)"
    } else {
        ToolTip "색을 찾지 못함 (Variation을 올려보세요)"
    }
    SetTimer () => ToolTip(), -3000
}

StartMacro() {
    global Running
    if (Running)
        return
    Running := true
    ToolTip "매크로 시작 (F7: 정지, ESC: 완전종료)"
    SetTimer () => ToolTip(), -1000
    RunLoop()
}

StopMacro(msg) {
    global Running
    Running := false
    ToolTip "매크로 " msg
    SetTimer () => ToolTip(), -1000
}

RunLoop() {
    global Running, SearchX1, SearchY1, SearchX2, SearchY2, TargetColor, Variation
    global Bx, By, PollDelay, CooldownAfterClick, OffsetX, OffsetY
    global EnableSound, BeepFreq, BeepDurMs, EnableTelegram, EnableScreenshot

    wasFound := false   ; 직전 스캔에서 색을 찾았었는지 상태 저장

    while (Running) {
        found := PixelSearch(&fx, &fy, SearchX1, SearchY1, SearchX2, SearchY2, TargetColor, Variation)

        if (found && !wasFound) {
            ; 색이 "새로 나타난 순간"에만 A를 딱 1번 클릭 (클릭이 최우선, 소리/텔레그램은 그 다음)
            Click fx + OffsetX, fy + OffsetY
            Click Bx, By
            if (EnableSound)
                SetTimer(() => SoundBeep(BeepFreq, BeepDurMs), -1)  ; 비동기 실행 - 클릭 타이밍에 영향 없음
            if (EnableScreenshot)
                NotifyTelegramScreenshot("색 감지! (" fx "," fy ")")  ; Run()이라 즉시 반환, 안 막힘
            else if (EnableTelegram)
                NotifyTelegram("색 감지! (" fx "," fy ")")
            wasFound := true
            Sleep CooldownAfterClick
        } else if (!found) {
            ; 색이 사라짐 -> 다음에 다시 나타나면 새 이벤트로 인정
            wasFound := false
            Sleep PollDelay
        } else {
            ; found && wasFound: 이미 처리한 동일 이벤트, A 재클릭 금지
            Sleep PollDelay
        }
    }
}
