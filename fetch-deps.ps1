# ===========================================================================
#  fetch-deps.ps1 - download the runtime binaries this kit needs.
#
#  bin/ is deliberately excluded from the repository:
#    - ffmpeg.exe alone is ~200 MB, above GitHub's 100 MB per-file limit
#    - both are GPL builds, so redistributing them inside the repo would drag
#      the source-offer obligation into every clone
#
#  Downloads into <repo>\bin, so nothing is installed system-wide:
#    bin\ffmpeg.exe          ffmpeg full build (static)
#    bin\vlc\                VLC portable (same layout the scripts expect)
#
#  Usage:
#    powershell -ExecutionPolicy Bypass -File .\fetch-deps.ps1
#    powershell -ExecutionPolicy Bypass -File .\fetch-deps.ps1 -Force
# ===========================================================================
param(
    [string]$FfmpegVersion = '9.0.2',
    [string]$VlcVersion    = '3.0.24',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$bin  = Join-Path $root 'bin'
$tmp  = Join-Path ([System.IO.Path]::GetTempPath()) ('xcpc-deps-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))

$ffmpegExe = Join-Path $bin 'ffmpeg.exe'
$vlcExe    = Join-Path $bin 'vlc\vlc.exe'

function Write-Step($msg) { Write-Host "[deps] $msg" }

function Get-Zip($url, $dest) {
    Write-Step "downloading $url"
    $ProgressPreference = 'SilentlyContinue'   # much faster in PS 5.1
    Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
    if (-not (Test-Path -LiteralPath $dest)) { throw "download failed: $url" }
    $mb = [math]::Round((Get-Item -LiteralPath $dest).Length / 1MB, 1)
    Write-Step "  got $mb MB"
}

New-Item -ItemType Directory -Path $bin -Force | Out-Null
New-Item -ItemType Directory -Path $tmp -Force | Out-Null

try {
    # ---------------- ffmpeg ----------------
    if ((Test-Path -LiteralPath $ffmpegExe) -and -not $Force) {
        Write-Step "ffmpeg.exe already present, skipping (use -Force to redownload)"
    } else {
        $url = "https://github.com/GyanD/codexffmpeg/releases/download/$FfmpegVersion/ffmpeg-$FfmpegVersion-full_build.zip"
        $zip = Join-Path $tmp 'ffmpeg.zip'
        Get-Zip $url $zip

        Write-Step "extracting ffmpeg"
        Expand-Archive -LiteralPath $zip -DestinationPath (Join-Path $tmp 'ff') -Force
        $found = Get-ChildItem -LiteralPath (Join-Path $tmp 'ff') -Recurse -Filter 'ffmpeg.exe' |
                 Where-Object { $_.FullName -match '\\bin\\' } | Select-Object -First 1
        if (-not $found) { throw 'ffmpeg.exe not found inside the archive' }
        Copy-Item -LiteralPath $found.FullName -Destination $ffmpegExe -Force
        Write-Step "  installed bin\ffmpeg.exe"
    }

    # ---------------- VLC portable ----------------
    if ((Test-Path -LiteralPath $vlcExe) -and -not $Force) {
        Write-Step "bin\vlc\vlc.exe already present, skipping (use -Force to redownload)"
    } else {
        $url = "https://get.videolan.org/vlc/$VlcVersion/win64/vlc-$VlcVersion-win64.zip"
        $zip = Join-Path $tmp 'vlc.zip'
        Get-Zip $url $zip

        Write-Step "extracting VLC"
        $dest = Join-Path $tmp 'vlc'
        Expand-Archive -LiteralPath $zip -DestinationPath $dest -Force
        $inner = Get-ChildItem -LiteralPath $dest -Directory |
                 Where-Object { Test-Path (Join-Path $_.FullName 'vlc.exe') } | Select-Object -First 1
        if (-not $inner) { throw 'vlc.exe not found inside the archive' }

        $target = Join-Path $bin 'vlc'
        if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
        Move-Item -LiteralPath $inner.FullName -Destination $target
        Write-Step "  installed bin\vlc\"

        # Build the plugin cache once, otherwise every VLC start rescans
        # ~140 MB of plugins (adds seconds to each reconnect).
        $cachegen = Join-Path $target 'vlc-cache-gen.exe'
        if (Test-Path -LiteralPath $cachegen) {
            Write-Step "building VLC plugin cache"
            & $cachegen (Join-Path $target 'plugins') 2>$null | Out-Null
        }
    }
} finally {
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host ''
Write-Host '[deps] done.'
Write-Host "       ffmpeg : $ffmpegExe"
Write-Host "       vlc    : $vlcExe"
Write-Host ''
Write-Host 'Next: run install.bat as administrator (or start-silent.vbs for a one-off run).'
