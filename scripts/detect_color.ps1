# ===========================================================================
#  Detect the "Automatic Colour Management" (ACM / Advanced Colour) darkening
#
#  When ACM is on, DWM composites in linear light and Desktop Duplication
#  hands out those LINEAR pixels while still labelling them sRGB. Captured
#  frames then look very dark (shadows crushed). GDI BitBlt is not affected,
#  so we grab one frame each way and compare average luma.
#
#  Exit codes:  0 = dda capture looks correct, no fix needed
#               1 = dda capture is too dark, apply inverse gamma
#               2 = could not tell (black screen / grab failed), leave as is
#
#  ASCII only.
# ===========================================================================
param(
    [Parameter(Mandatory = $true)][string]$Ffmpeg,
    [Parameter(Mandatory = $true)][string]$WorkDir
)

$ErrorActionPreference = 'Continue'

$ddaPng = Join-Path $WorkDir '_probe_dda.png'
$gdiPng = Join-Path $WorkDir '_probe_gdi.png'

& $Ffmpeg -hide_banner -loglevel error -f lavfi -i 'ddagrab=0:framerate=1:draw_mouse=0' `
    -frames:v 1 -vf 'hwdownload,format=bgra' -update 1 -y $ddaPng 2>$null
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $ddaPng)) { exit 2 }

& $Ffmpeg -hide_banner -loglevel error -f gdigrab -framerate 1 -draw_mouse 0 `
    -i desktop -frames:v 1 -update 1 -y $gdiPng 2>$null
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $gdiPng)) { exit 2 }

function Get-LumaAvg([string]$Image) {
    $raw = & $Ffmpeg -hide_banner -loglevel error -i $Image `
        -vf 'format=gray,signalstats,metadata=print:file=-' -f null - 2>$null
    $text = ($raw | Out-String)
    $m = [regex]::Match($text, 'signalstats\.YAVG=([0-9]+\.?[0-9]*)')
    if ($m.Success) { return [double]$m.Groups[1].Value }
    return -1
}

$ddaLuma = Get-LumaAvg $ddaPng
$gdiLuma = Get-LumaAvg $gdiPng

Remove-Item $ddaPng, $gdiPng -Force -ErrorAction SilentlyContinue

if ($ddaLuma -lt 0 -or $gdiLuma -lt 0) { exit 2 }
# A nearly black desktop (lock screen, screen off) gives no usable ratio.
if ($gdiLuma -lt 8) { exit 2 }

# ACM darkening pushes the capture to roughly 1/4 of the GDI reference.
# Anything under 70% of the reference means the shadows are being crushed.
if (($ddaLuma / $gdiLuma) -lt 0.7) { exit 1 }
exit 0
