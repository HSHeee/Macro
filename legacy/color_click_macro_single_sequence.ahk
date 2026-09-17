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

; 감지된 위치(fx,fy)가 이 사각형 범위 안이면 A시퀀스, 그 밖이면 B시퀀스 실행
ZoneX1 := 1100
ZoneX2 := 1700
ZoneY1 := 900
ZoneY2 := 980

; 외부 프로그램(예: OCR 스크립트) 실행 시 작업 폴더 - an.py 등이 이 폴더 기준으로 찾아짐
; 다른 폴더에 있으면 여기 경로를 바꾸세요
PythonWorkDir := A_ScriptDir

; 화면 캡처본을 저장할 폴더 (매크로 폴더 밑에 자동 생성됨)
ScreenshotDir := A_ScriptDir "\Screenshot"

; python(run 스텝) 실행 결과를 남길 로그 파일
LogFile := A_ScriptDir "\ocr_log.txt"

; 캡처할 영역 (캐릭터 이름 부분만 잘라서 캡처)
CaptureX1 := 1300
CaptureY1 := 721
CaptureX2 := 1568
CaptureY2 := 796

SequenceDelayMs := 2000   ; A클릭 -> 1번째 버튼, 1번째 -> 2번째... 각 클릭 사이 대기시간(ms)
CaptureDelayMs := 5000   ; 캡처 실행 전 대기시간(ms). 화면 전환/렌더링 끝나길 기다리는 용도

; A구역일 때 순서대로 실행할 스텝들 - 필요한 만큼 추가하면 됨
; 클릭:   {x:.., y:..}                              (button 생략시 Left, count 생략시 1)
; 스크롤: {x:.., y:.., button:"WheelDown", count:5}  (WheelUp/WheelDown/WheelLeft/WheelRight)
; 실행+타이핑: {x:.., y:.., capture:"a.png", run:'python an.py "{IMG}"', pressEnter:true}
;   -> (x,y) 클릭해서 입력창 포커스
;   -> capture가 있으면: CaptureDelayMs만큼 기다렸다가 (CaptureX1,Y1)~(CaptureX2,Y2) 영역을
;      캡처해서 ScreenshotDir\capture 경로에 저장
;   -> run 문자열 안의 {IMG}를 방금 저장한 파일의 전체경로로 바꿔서 실행
;   -> 그 표준출력 텍스트를 그대로 타이핑 -> pressEnter:true면 마지막에 Enter까지
; 특정 스텝만 대기시간 다르게: delay:.. 추가 (생략하면 SequenceDelayMs 사용)
; (좌표는 F8로 그 위치에 마우스 올리고 확인하면 됨 - 색상 말고 X,Y 값 참고)


ClickSequenceA := [
     {x: 1875, y: 403, delay:4000} ;
    ,{x: 2063, y: 906, delay:2500} ;
    ; 캐릭터 이름 부분 화면 캡처 -> OCR 실행 -> 결과를 채팅창에 입력
    ,{x: 1410, y: 985, capture: "a.png", run: 'python C:\Project\web-image-ML\predict.py "{IMG}"', pressEnter: true}
    ;,{x: 1450, y: 1221, delay:2500} ;
    ,{x: 1042, y: 743} ;
]

; A구역이 아닐 때(그 외) 순서대로 실행할 스텝들
ClickSequenceB := [
    {x: 2504, y: 1600} ;하기
    ,{x: 2774, y: 512} ; +
    ,{x: 2504, y: 1600, delay:3000} ;하기
    ,{x: 800, y: 1402, delay:3000} ;전체동의
    ,{x: 1200, y: 800, button: "WheelDown", count: 10}
    ,{x: 845, y: 1379} ;스크롤후 진행
    ,{x: 2122, y: 805, delay:4000} ;하러 가기
    ,{x: 2400, y: 842, delay:6000} ; 선택
    ,{x: 1458, y: 680, delay:10000} ; 선택
    ,{x: 1458, y: 680, delay:2000} ; 선택 1트 더
    ,{x: 1578, y: 807} ;현금영수증 선택
    ,{x: 1455, y: 1198} ;발급안함
    ,{x: 1350, y: 1276} ;필수
    ,{x: 1451, y: 1392, delay:6000} ;확인
]


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
CancelSequence := false   ; F4 누르면 true 됨 - 진행중인 시퀀스만 끊음
CaptureCounter := 0       ; 캡처마다 고유 파일명을 만들기 위한 카운터
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
F4:: CancelSequenceHotkey()  ; 진행 중인 시퀀스만 중단 (감지 루프는 계속 돔)
F3:: OpenLogFile()  ; OCR 실행 로그 파일 열기

CancelSequenceHotkey() {
    global CancelSequence
    CancelSequence := true
    ToolTip "시퀀스 중단 요청됨 (다음 클릭 전에 멈춤)"
    SetTimer () => ToolTip(), -1000
}

ToggleSound() {
    global EnableSound
    EnableSound := !EnableSound
    ToolTip "감지음: " (EnableSound ? "켜짐" : "꺼짐")
    SetTimer () => ToolTip(), -1000
}

; 감지된 (x,y)가 ZoneX1~X2, ZoneY1~Y2 사각형 범위 안이면 A구역(true), 아니면 B구역(false)
IsInZoneA(x, y) {
    global ZoneX1, ZoneX2, ZoneY1, ZoneY2
    return x >= ZoneX1 && x <= ZoneX2 && y >= ZoneY1 && y <= ZoneY2
}

; dir\baseName(예: a.png)을 캡처마다 겹치지 않는 고유 파일명으로 바꿔줌
; 예: a.png -> a_20260906_142530_412_1.png (타임스탬프+밀리초+카운터)
UniqueCapturePath(dir, baseName) {
    global CaptureCounter
    CaptureCounter += 1
    SplitPath baseName, , , &ext, &nameNoExt
    stamp := FormatTime(A_Now, "yyyyMMdd_HHmmss") "_" Format("{:03}", A_MSec) "_" CaptureCounter
    return dir "\" nameNoExt "_" stamp (ext != "" ? "." ext : "")
}

; 화면(지정 영역)을 캡처해서 PNG로 저장. capture_region.ps1을 RunWait로 동기 실행
; (예전엔 AHK 자체 GDI+ DllCall로 직접 캡처했는데 포인터 문제로 네이티브 크래시가 나서,
;  텔레그램 스크린샷에 쓰던 것과 동일한, 이미 검증된 PowerShell 방식으로 교체함)
; x2,y2를 생략하면(0,0) 전체 가상화면(모든 모니터)을 캡처함
CaptureScreenToFile(path, x1 := 0, y1 := 0, x2 := 0, y2 := 0) {
    if (x2 = 0 && y2 = 0) {
        x1 := SysGet(76)   ; SM_XVIRTUALSCREEN
        y1 := SysGet(77)   ; SM_YVIRTUALSCREEN
        x2 := x1 + SysGet(78)  ; + SM_CXVIRTUALSCREEN
        y2 := y1 + SysGet(79)  ; + SM_CYVIRTUALSCREEN
    }
    scriptPath := A_ScriptDir "\capture_region.ps1"
    cmd := 'powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "'
        . scriptPath '" -X1 ' x1 ' -Y1 ' y1 ' -X2 ' x2 ' -Y2 ' y2 ' -OutPath "' path '"'
    try
        RunWait(cmd, , "Hide")
    catch as e
        LogLine("CaptureScreenToFile 실패: " e.Message)
}

; LogFile에 시각 찍어서 한 줄 추가 (파일 없으면 자동 생성)
LogLine(msg) {
    global LogFile
    try FileAppend(FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") " - " msg "`n", LogFile, "UTF-8")
}

OpenLogFile() {
    global LogFile
    if !FileExist(LogFile)
        FileAppend("", LogFile, "UTF-8")   ; 아직 없으면 빈 파일 생성
    Run('notepad.exe "' LogFile '"')
}

; cmdLine을 실행해서 표준출력(stdout)을 그대로 텍스트로 반환. PythonWorkDir을 작업폴더로 씀.
; 이 호출은 프로그램이 끝날 때까지 기다림(그 결과 텍스트가 있어야 다음 타이핑을 할 수 있어서 의도된 대기)
; stdout/stderr를 파일로 리다이렉트해서 실행함 (WshExec로 파이프를 직접 읽으면 파이썬이
; stderr에 뭔가만 찍어도 파이프가 막혀 영원히 멈추는 경우가 있어서 - 그 문제를 피하기 위함)
RunAndCaptureOutput(cmdLine) {
    global PythonWorkDir
    outFile := A_Temp "\macro_ocr_out_" A_TickCount ".txt"
    errFile := A_Temp "\macro_ocr_err_" A_TickCount ".txt"
    try {
        ; PYTHONIOENCODING=utf-8: 파이썬 stdout/stderr을 UTF-8로 강제 (한글 결과 깨짐 방지)
        fullCmd := A_ComSpec ' /C set PYTHONIOENCODING=utf-8&&' cmdLine ' > "' outFile '" 2> "' errFile '"'
        exitCode := RunWait(fullCmd, PythonWorkDir, "Hide")

        stdout := FileExist(outFile) ? Trim(FileRead(outFile, "UTF-8"), "`r`n `t") : ""
        stderr := FileExist(errFile) ? Trim(FileRead(errFile, "UTF-8"), "`r`n `t") : ""
        LogLine("cmd=[" cmdLine "] exitCode=" exitCode " stdout=[" stdout "] stderr=[" stderr "]")

        return stdout
    } catch as e {
        LogLine("RunAndCaptureOutput 실패: " e.Message)
        ToolTip "외부 프로그램 실행 실패: " e.Message
        SetTimer () => ToolTip(), -3000
        return ""
    } finally {
        try FileDelete(outFile)
        try FileDelete(errFile)
    }
}

ShowConfig() {
    global TargetColor, Variation, SearchX1, SearchY1, SearchX2, SearchY2
    global ZoneX1, ZoneX2, ZoneY1, ZoneY2, ClickSequenceA, ClickSequenceB, SequenceDelayMs
    global OffsetX, OffsetY, LoadedAt
    global EnableTelegram, TelegramBotToken, TelegramChatId, EnableScreenshot
    seqA := ""
    for step in ClickSequenceA
        seqA .= (seqA = "" ? "" : " -> ") "(" step.x "," step.y ")"
    seqB := ""
    for step in ClickSequenceB
        seqB .= (seqB = "" ? "" : " -> ") "(" step.x "," step.y ")"
    MsgBox(
        "로드시각: " LoadedAt "`n"
        "TargetColor: " TargetColor "`n"
        "Variation: " Variation "`n"
        "검색범위: (" SearchX1 "," SearchY1 ") ~ (" SearchX2 "," SearchY2 ")`n"
        "A구역 범위: x " ZoneX1 "~" ZoneX2 ", y " ZoneY1 "~" ZoneY2 "`n"
        "A시퀀스: " seqA "`n"
        "B시퀀스: " seqB "`n"
        "클릭 간 대기: " SequenceDelayMs "ms`n"
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
; 백그라운드 실행 (powershell.exe 자체를 Run으로 던지고 바로 반환되므로
; 캡처/업로드가 오래 걸려도 매크로 루프는 전혀 안 막힘)
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
        zone := IsInZoneA(fx, fy) ? "A구역 -> A시퀀스" : "B구역(그 외) -> B시퀀스"
        ToolTip "감지: raw=" fx "," fy "  보정후=" (fx+OffsetX) "," (fy+OffsetY) "`n판정: " zone "`n(클릭 안 함 - 커서 위치만 확인하세요)"
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
    ToolTip "매크로 시작 (F7: 정지, F4: 시퀀스만 중단, ESC: 완전종료)"
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
    global ClickSequenceA, ClickSequenceB, SequenceDelayMs, PollDelay, CooldownAfterClick, OffsetX, OffsetY
    global ScreenshotDir, CaptureX1, CaptureY1, CaptureX2, CaptureY2, CaptureDelayMs
    global EnableSound, BeepFreq, BeepDurMs, EnableTelegram, EnableScreenshot, CancelSequence

    wasFound := false   ; 직전 스캔에서 색을 찾았었는지 상태 저장

    while (Running) {
        found := PixelSearch(&fx, &fy, SearchX1, SearchY1, SearchX2, SearchY2, TargetColor, Variation)

        if (found && !wasFound) {
            ; 색이 "새로 나타난 순간"에만 A를 딱 1번 클릭 (클릭이 최우선, 소리/텔레그램은 그 다음)
            Click fx + OffsetX, fy + OffsetY
            if (EnableSound)
                SetTimer(() => SoundBeep(BeepFreq, BeepDurMs), -1)  ; 비동기 실행 - 클릭 타이밍에 영향 없음
            ; 감지 위치에 따라 A구역/B구역 판정해서 쓸 시퀀스 결정
            zoneA := IsInZoneA(fx, fy)
            seq := zoneA ? ClickSequenceA : ClickSequenceB
            if (EnableScreenshot)
                NotifyTelegramScreenshot("색 감지! (" fx "," fy ") -> " (zoneA ? "A시퀀스" : "B시퀀스"))
            else if (EnableTelegram)
                NotifyTelegram("색 감지! (" fx "," fy ") -> " (zoneA ? "A시퀀스" : "B시퀀스"))
            ; 선택된 시퀀스를 순서대로, 텀을 두고 실행 (F4 누르면 중간에 중단)
            ; 스텝에 run이 있으면: 클릭으로 포커스 -> 외부 프로그램 실행 -> 출력 텍스트 타이핑
            ; 스텝에 button/count가 있으면 스크롤(WheelUp/Down/Left/Right), 그 외엔 일반 클릭
            CancelSequence := false
            seqName := zoneA ? "A시퀀스" : "B시퀀스"
            LogLine(seqName " 시작 (" seq.Length "스텝)")
            stepNum := 0
            for step in seq {
                stepNum += 1
                Sleep (step.HasOwnProp("delay") ? step.delay : SequenceDelayMs)
                if (CancelSequence) {
                    LogLine(seqName " " stepNum "/" seq.Length " - F4로 중단됨")
                    break
                }
                try {
                    if (step.HasOwnProp("run")) {
                        Click step.x, step.y   ; 입력창 포커스
                        cmd := step.run
                        if (step.HasOwnProp("capture")) {
                            Sleep CaptureDelayMs   ; 캡처 전 대기 (렌더링/화면전환 끝나길 기다림)
                            DirExist(ScreenshotDir) || DirCreate(ScreenshotDir)
                            imgPath := UniqueCapturePath(ScreenshotDir, step.capture)
                            CaptureScreenToFile(imgPath, CaptureX1, CaptureY1, CaptureX2, CaptureY2)
                            cmd := StrReplace(cmd, "{IMG}", imgPath)
                        }
                        text := RunAndCaptureOutput(cmd)  ; 내부에서 LogFile에 stdout/stderr/exitCode 기록함
                        if (text != "")
                            SendText(text)
                        if (step.HasOwnProp("pressEnter") && step.pressEnter)
                            Send "{Enter}"
                    } else {
                        Click step.x, step.y
                            , (step.HasOwnProp("button") ? step.button : "Left")
                            , (step.HasOwnProp("count") ? step.count : 1)
                    }
                    LogLine(seqName " " stepNum "/" seq.Length " 완료: (" step.x "," step.y ")")
                } catch as e {
                    LogLine(seqName " " stepNum "/" seq.Length " 실패: (" step.x "," step.y ") - " e.Message)
                }
            }
            LogLine(seqName " 종료")
            CancelSequence := false
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
