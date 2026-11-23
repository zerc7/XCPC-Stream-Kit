# stop.ps1 - kill only the processes that belong to this package.
# Other VLC windows (playing videos etc.) are left alone.
#
# IMPORTANT: the stream scripts run as a cmd.exe restart loop. Killing only
# ffmpeg/vlc makes that loop respawn them 5 s later (and, worse, with the old
# copy of the .bat it had already read). So the wrapper cmd.exe processes are
# killed FIRST, then the media processes.
param([string]$BasePath = ".")

$ErrorActionPreference = 'SilentlyContinue'
try { $base = (Resolve-Path -LiteralPath $BasePath).Path.TrimEnd('\') }
catch { $base = $BasePath }

Write-Host "[stop] base = $base"
$killed = 0

# --- 1) batch wrappers (restart loops) -------------------------------------
# Match on the script name rather than on $base: the loops are often started
# with a relative path, so their command line does not necessarily contain the
# absolute package folder.
$wrappers = Get-CimInstance Win32_Process -Filter "Name='cmd.exe' OR Name='wscript.exe'" |
    Where-Object {
        $_.CommandLine -and
        $_.CommandLine -match '(?i)stream_screen\.bat|stream_camera\.bat|fallback-vlc-screen\.bat|start-silent\.vbs'
    }
foreach ($w in $wrappers) {
    Write-Host ("  kill " + $w.Name + " (pid " + $w.ProcessId + ")")
    try { Stop-Process -Id $w.ProcessId -Force; $killed++ } catch { Write-Host "  cannot kill pid $($w.ProcessId)" }
}

# --- 2) media processes ----------------------------------------------------
foreach ($n in @('vlc', 'ffmpeg', 'vlc-cache-gen')) {
    $procs = Get-Process -Name $n -ErrorAction SilentlyContinue
    foreach ($p in $procs) {
        $path = $null
        try { $path = $p.Path } catch { }
        # trailing separator: "D:\x\Kit" must not match "D:\x\Kit-old\vlc.exe"
        if ($path -and $path.StartsWith($base + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
            Write-Host ("  kill " + $p.ProcessName + " (pid " + $p.Id + ")")
            try { $p.Kill(); $killed++ } catch { Write-Host "  cannot kill pid $($p.Id)" }
        }
    }
}

Write-Host "[stop] killed $killed process(es)"

# --- 3) leave a marker in the logs -----------------------------------------
# Killing VLC closes the pipe and ffmpeg then logs
#   "Error submitting a packet to the muxer: Invalid argument" (-22)
# which reads exactly like a real failure. The marker has to be written AFTER
# the kill: while ffmpeg is alive it holds the log file open for appending and
# our write would be refused.
if ($killed -gt 0) {
    Start-Sleep -Milliseconds 300
    $stamp = Get-Date -Format 'yyyy/MM/dd HH:mm:ss'
    New-Item -ItemType Directory -Path (Join-Path $base 'logs') -Force | Out-Null
    foreach ($n in @('screen.log', 'camera.log', 'screen-fallback.log')) {
        $p = Join-Path $base "logs\$n"
        if (Test-Path -LiteralPath $p) {
            Add-Content -LiteralPath $p -Value "[$stamp] ===== stopped on purpose by stop.bat =====" -ErrorAction SilentlyContinue
        }
    }
}
