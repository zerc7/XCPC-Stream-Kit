# detect_camera.ps1 - list the first usable DirectShow video device.
# Prints the device alternative name (pure ASCII, e.g. @device_pnp_\\?\usb#vid_...)
# so Chinese / spaces / parentheses in friendly names never break the cmd pipeline.
# Falls back to the friendly name if ffmpeg reports no alternative name, and says
# so on stderr, because that name may be localized and then depends on the ANSI
# code page of the console that calls ffmpeg.
# No output = no camera.
#
# Note: ffmpeg output is captured through raw pipes on purpose. Piping it through
# PowerShell's error stream wraps long lines at the console width, which cuts the
# "@device_pnp_..." string in half.
param([string]$Ffmpeg = "ffmpeg.exe")

$ErrorActionPreference = 'SilentlyContinue'

if (-not (Test-Path -LiteralPath $Ffmpeg)) { exit 0 }

try {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName               = $Ffmpeg
    $psi.Arguments              = '-hide_banner -list_devices true -f dshow -i dummy'
    $psi.UseShellExecute        = $false
    $psi.CreateNoWindow         = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $p = [System.Diagnostics.Process]::Start($psi)

    # Read both pipes concurrently. Reading one to the end before touching the
    # other blocks forever as soon as the other pipe buffer (4 KB) fills up.
    $errTask = $p.StandardError.ReadToEndAsync()
    $outTask = $p.StandardOutput.ReadToEndAsync()
    $p.WaitForExit()
    $err = $errTask.Result
    $null = $outTask.Result
} catch {
    exit 0
}

$exclude = 'OBS Virtual|ManyCam|Snap Camera|CyberLink|XDK|Windows Hello|IR Camera|Virtual Camera|Depth'

$bestAlt  = $null
$bestName = $null
$lines    = $err -split "`r?`n"

for ($i = 0; $i -lt $lines.Count; $i++) {
    $m = [regex]::Match($lines[$i], '"([^"]+)"\s*\(video\)')
    if (-not $m.Success) { continue }

    $name = $m.Groups[1].Value
    if ($name -match $exclude) { continue }

    $alt = $null
    if (($i + 1) -lt $lines.Count) {
        $m2 = [regex]::Match($lines[$i + 1], 'Alternative name "([^"]+)"')
        if ($m2.Success) { $alt = $m2.Groups[1].Value }
    }

    if ($alt) {
        $bestAlt  = $alt
        $bestName = $name
        break
    }
    if (-not $bestName) { $bestName = $name }
}

if ($bestAlt) {
    Write-Output $bestAlt
} elseif ($bestName) {
    [Console]::Error.WriteLine("[detect_camera] WARNING: device has no ASCII alternative name, falling back to friendly name '$bestName'. If the stream cannot open it, run list-cameras.bat and set CAMERA_DEVICE in config.bat by hand.")
    Write-Output $bestName
}
exit 0
