# Captures the screen and sends it to Telegram via sendPhoto.
# Called from color_click_macro_single_sequence.ahk via Run() in the background.
param(
    [Parameter(Mandatory=$true)][string]$Token,
    [Parameter(Mandatory=$true)][string]$ChatId,
    [string]$Caption = ""
)

$ErrorActionPreference = "Stop"
$path = $null

try {
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing, System.Net.Http

    # Force per-monitor DPI awareness so the capture matches true physical pixels
    # (Windows display scaling would otherwise shrink/blur a non-aware capture).
    Add-Type -ErrorAction SilentlyContinue @"
using System;
using System.Runtime.InteropServices;
public class DpiHelperShot {
    [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr value);
    [DllImport("user32.dll")] public static extern int GetSystemMetrics(int nIndex);
}
"@
    [void][DpiHelperShot]::SetProcessDpiAwarenessContext([IntPtr]-4)  # PER_MONITOR_AWARE_V2

    $w = [DpiHelperShot]::GetSystemMetrics(78)  # SM_CXVIRTUALSCREEN
    $h = [DpiHelperShot]::GetSystemMetrics(79)  # SM_CYVIRTUALSCREEN
    $x = [DpiHelperShot]::GetSystemMetrics(76)  # SM_XVIRTUALSCREEN
    $y = [DpiHelperShot]::GetSystemMetrics(77)  # SM_YVIRTUALSCREEN

    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($x, $y, 0, 0, (New-Object System.Drawing.Size $w, $h))

    $path = Join-Path $env:TEMP ("macro_shot_{0}.png" -f (Get-Date -Format "yyyyMMdd_HHmmss_fff"))
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()

    # Windows PowerShell 5.1 doesn't support Invoke-RestMethod -Form, so build
    # the multipart upload manually via HttpClient.
    $client = New-Object System.Net.Http.HttpClient
    $content = New-Object System.Net.Http.MultipartFormDataContent
    $content.Add((New-Object System.Net.Http.StringContent($ChatId)), "chat_id")
    if ($Caption) {
        $content.Add((New-Object System.Net.Http.StringContent($Caption)), "caption")
    }
    $fileStream = [System.IO.File]::OpenRead($path)
    $fileContent = New-Object System.Net.Http.StreamContent($fileStream)
    $fileContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("image/png")
    $content.Add($fileContent, "photo", [System.IO.Path]::GetFileName($path))

    $uri = "https://api.telegram.org/bot$Token/sendPhoto"
    $client.PostAsync($uri, $content).GetAwaiter().GetResult() | Out-Null
    $fileStream.Close()
}
catch {
    # Swallow errors here - this must never affect the macro's main behavior.
}
finally {
    if ($path -and (Test-Path $path)) {
        Remove-Item $path -Force -ErrorAction SilentlyContinue
    }
}
