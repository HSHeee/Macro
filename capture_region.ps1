# Captures a specific screen region and saves it as a PNG file.
# Called from color_click_macro_single_sequence.ahk via RunWait.
param(
    [Parameter(Mandatory=$true)][int]$X1,
    [Parameter(Mandatory=$true)][int]$Y1,
    [Parameter(Mandatory=$true)][int]$X2,
    [Parameter(Mandatory=$true)][int]$Y2,
    [Parameter(Mandatory=$true)][string]$OutPath
)

try {
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing

    # Force per-monitor DPI awareness so the capture matches true physical pixels
    # (same coordinate space AHK's PixelSearch/Click already use).
    Add-Type -ErrorAction SilentlyContinue @"
using System;
using System.Runtime.InteropServices;
public class DpiHelperCap {
    [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr value);
}
"@
    [void][DpiHelperCap]::SetProcessDpiAwarenessContext([IntPtr]-4)  # PER_MONITOR_AWARE_V2

    $w = $X2 - $X1
    $h = $Y2 - $Y1

    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($X1, $Y1, 0, 0, (New-Object System.Drawing.Size $w, $h))
    $bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
}
catch {
    exit 1
}
