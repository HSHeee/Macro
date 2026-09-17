#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Event"
SetMouseDelay -1          ; 클릭 사이 인위적 지연 제거 (속도 최우선)
SetKeyDelay -1, -1
CoordMode "Pixel", "Screen"
CoordMode "Mouse", "Screen"

; =======================================================
;  설정값 로딩 - 실제 값은 config\config.txt, config\sequence_a.txt,
;  config\sequence_b.txt 에서 읽어옵니다. 좌표/색상/텔레그램 등을 바꾸고
;  싶으면 이 .ahk가 아니라 그 파일들을 메모장으로 고치고 다시 실행하세요
;  (재컴파일 불필요).
; =======================================================
GetField(f, i) {
    return (f.Length >= i) ? Trim(f[i]) : ""
}

; ";" 이후는 전부 주석으로 잘라냄 - 줄 전체 주석("; ...")도, 데이터 뒤에 붙인
; 한 줄 끝 주석(예: "1272|283 ; 날짜")도 둘 다 이걸로 처리됨.
; 주의: run= 에 넣는 명령어 자체에 ";" 글자가 필요하면 이 방식으로는 못 씀.
StripComment(line) {
    pos := InStr(line, ";")
    return Trim(pos ? SubStr(line, 1, pos - 1) : line)
}

LoadConfig(path) {
    if !FileExist(path)
        throw Error("설정 파일을 찾을 수 없음: " path)
    cfg := Map()
    Loop Read, path {
        line := StripComment(A_LoopReadLine)
        if (line = "")
            continue
        parts := StrSplit(line, "=", , 2)
        if (parts.Length = 2)
            cfg[Trim(parts[1])] := Trim(parts[2])
    }
    return cfg
}

LoadSequence(path, exePath, modelPath) {
    if !FileExist(path)
        throw Error("시퀀스 파일을 찾을 수 없음: " path)
    seq := []
    Loop Read, path {
        line := StripComment(A_LoopReadLine)
        if (line = "")
            continue
        f := StrSplit(line, "|")
        step := {x: Integer(GetField(f, 1)), y: Integer(GetField(f, 2))}
        if (GetField(f, 3) != "")
            step.delay := Integer(GetField(f, 3))
        if (GetField(f, 4) != "")
            step.button := GetField(f, 4)
        if (GetField(f, 5) != "")
            step.count := Integer(GetField(f, 5))
        if (GetField(f, 6) != "")
            step.capture := GetField(f, 6)
        if (GetField(f, 7) != "") {
            run := StrReplace(GetField(f, 7), "{EXE}", exePath)
            run := StrReplace(run, "{MODEL}", modelPath)
            step.run := run
        }
        if (GetField(f, 8) = "1")
            step.pressEnter := true
        seq.Push(step)
    }
    return seq
}

cfg := LoadConfig(A_ScriptDir "\config\config.txt")

SearchX1 := Integer(cfg["SearchX1"])
SearchY1 := Integer(cfg["SearchY1"])
SearchX2 := Integer(cfg["SearchX2"])
SearchY2 := Integer(cfg["SearchY2"])
TargetColor := Integer(cfg["TargetColor"])
Variation := Integer(cfg["Variation"])

ZoneX1 := Integer(cfg["ZoneX1"])
ZoneX2 := Integer(cfg["ZoneX2"])
ZoneY1 := Integer(cfg["ZoneY1"])
ZoneY2 := Integer(cfg["ZoneY2"])

CaptureX1 := Integer(cfg["CaptureX1"])
CaptureY1 := Integer(cfg["CaptureY1"])
CaptureX2 := Integer(cfg["CaptureX2"])
CaptureY2 := Integer(cfg["CaptureY2"])

OffsetX := Integer(cfg["OffsetX"])
OffsetY := Integer(cfg["OffsetY"])

SequenceDelayMs := Integer(cfg["SequenceDelayMs"])
CaptureDelayMs := Integer(cfg["CaptureDelayMs"])
PollDelay := Integer(cfg["PollDelay"])
CooldownAfterClick := Integer(cfg["CooldownAfterClick"])

EnableSound := (cfg["EnableSound"] = "1")
BeepFreq := Integer(cfg["BeepFreq"])
BeepDurMs := Integer(cfg["BeepDurMs"])

EnableTelegram := (cfg["EnableTelegram"] = "1")
EnableScreenshot := (cfg["EnableScreenshot"] = "1")
TelegramBotToken := cfg["TelegramBotToken"]
TelegramChatId := cfg["TelegramChatId"]

PythonWorkDir := A_ScriptDir
ScreenshotDir := A_ScriptDir "\Screenshot"
LogFile := A_ScriptDir "\ocr_log.txt"

ClickSequenceA := LoadSequence(A_ScriptDir "\config\sequence_a.txt", cfg["PredictExe"], cfg["CaptchaModel"])
ClickSequenceB := LoadSequence(A_ScriptDir "\config\sequence_b.txt", cfg["PredictExe"], cfg["CaptchaModel"])

; =======================================================
;  여기부터는 로직 - 보통 손댈 필요 없음
; =======================================================

Running := false
CancelSequence := false   ; F4 누르면 true 됨 - 진행중인 시퀀스만 끊음
CaptureCounter := 0       ; 캡처마다 고유 파일명을 만들기 위한 카운터
LoadedAt := A_Now   ; 이 스크립트 인스턴스가 로드된 시각 (재시작 확인용)

g_ActiveWaitPID := 0
ChildPIDs := []

ExitCleanup(ExitReason, ExitCode) {
    global g_ActiveWaitPID, ChildPIDs
    if (g_ActiveWaitPID) {
        try RunWait(A_ComSpec ' /C taskkill /PID ' g_ActiveWaitPID ' /T /F', , "Hide")
        g_ActiveWaitPID := 0
    }
    for pid in ChildPIDs {
        try RunWait(A_ComSpec ' /C taskkill /PID ' pid ' /T /F', , "Hide")
    }
    ChildPIDs := []
    return 0
}
OnExit(ExitCleanup)

TrayTip "매크로 로드됨", "로드시각 " LoadedAt " / F10으로 현재 설정 확인", 1

; =======================================================
;  단축키
; =======================================================
F6:: StartMacro()
F7:: StopMacro("F7로 정지")
Esc:: ExitApp()   ; 스크립트 자체를 완전히 강제종료 (OnExit에서 하위 프로세스까지 다 정리함)
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

; pid를 ChildPIDs에 기록 (0/빈값이면 무시) - ESC로 완전 종료할 때 같이 강제 종료하기 위함
TrackPID(pid) {
    global ChildPIDs
    if (pid)
        ChildPIDs.Push(pid)
}

CaptureScreenToFile(path, x1 := 0, y1 := 0, x2 := 0, y2 := 0) {
    global g_ActiveWaitPID
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
        RunWait(cmd, , "Hide", &g_ActiveWaitPID)
    catch as e
        LogLine("CaptureScreenToFile 실패: " e.Message)
    g_ActiveWaitPID := 0
}

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

RunAndCaptureOutput(cmdLine) {
    global PythonWorkDir, g_ActiveWaitPID
    outFile := A_Temp "\macro_ocr_out_" A_TickCount ".txt"
    errFile := A_Temp "\macro_ocr_err_" A_TickCount ".txt"
    try {
        ; PYTHONIOENCODING=utf-8: 파이썬 stdout/stderr을 UTF-8로 강제 (한글 결과 깨짐 방지)
        fullCmd := A_ComSpec ' /C set PYTHONIOENCODING=utf-8&&' cmdLine ' > "' outFile '" 2> "' errFile '"'
        exitCode := RunWait(fullCmd, PythonWorkDir, "Hide", &g_ActiveWaitPID)
        g_ActiveWaitPID := 0
        stdout := FileExist(outFile) ? Trim(FileRead(outFile, "UTF-8"), "`r`n `t") : ""
        stderr := FileExist(errFile) ? Trim(FileRead(errFile, "UTF-8"), "`r`n `t") : ""
        LogLine("cmd=[" cmdLine "] exitCode=" exitCode " stdout=[" stdout "] stderr=[" stderr "]")
        return stdout
    } catch as e {
        g_ActiveWaitPID := 0
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

NotifyTelegram(msg) {
    url := "https://api.telegram.org/bot" TelegramBotToken "/sendMessage"
    cmd := 'curl.exe -s -X POST "' url '" -d "chat_id=' TelegramChatId '" --data-urlencode "text=' msg '"'
    try {
        Run(cmd, , "Hide", &pid)
        TrackPID(pid)
    } catch as e
        ToolTip "텔레그램 전송 실패: " e.Message
}

NotifyTelegramScreenshot(caption) {
    scriptPath := A_ScriptDir "\telegram_screenshot.ps1"
    cmd := 'powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "'
        . scriptPath '" -Token "' TelegramBotToken '" -ChatId "' TelegramChatId '" -Caption "' caption '"'
    try {
        Run(cmd, , "Hide", &pid)
        TrackPID(pid)
    } catch as e
        ToolTip "스크린샷 전송 실패: " e.Message
}

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
            for step in seq {
                Sleep (step.HasOwnProp("delay") ? step.delay : SequenceDelayMs)
                if (CancelSequence)
                    break

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
            }
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
