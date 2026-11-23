# status.ps1 - health check for XCPC-Stream-Kit (processes, ports, TS payload, logs).
param(
    [string]$BasePath  = ".",
    [int]   $ScreenPort = 9090,
    [int]   $CamPort    = 9092,
    [int]   $TailLines  = 8
)

$ErrorActionPreference = 'SilentlyContinue'
try { $base = (Resolve-Path -LiteralPath $BasePath).Path.TrimEnd('\') } catch { $base = $BasePath }

# VLC's http output is a real HTTP server: it starts sending only after a GET.
function Test-TsStream([int]$port) {
    $c = New-Object System.Net.Sockets.TcpClient
    try {
        $iar = $c.BeginConnect('127.0.0.1', $port, $null, $null)
        if (-not $iar.AsyncWaitHandle.WaitOne(1000)) { return 'FAIL: connect timeout' }
        $c.EndConnect($iar)

        $s = $c.GetStream()
        $s.ReadTimeout = 2000
        $req = [System.Text.Encoding]::ASCII.GetBytes("GET / HTTP/1.0`r`nHost: 127.0.0.1`r`n`r`n")
        $s.Write($req, 0, $req.Length)

        $ms  = New-Object System.IO.MemoryStream
        $buf = New-Object byte[] 8192
        $sw  = [System.Diagnostics.Stopwatch]::StartNew()
        while ($ms.Length -lt 16384 -and $sw.ElapsedMilliseconds -lt 4000) {
            try { $r = $s.Read($buf, 0, $buf.Length) } catch { break }
            if ($r -le 0) { break }
            $ms.Write($buf, 0, $r)
        }
        $data = $ms.ToArray()
        if ($data.Length -lt 200) { return "FAIL: only $($data.Length) bytes received" }

        # body starts after the HTTP header block
        $start = 0
        $limit = [Math]::Min($data.Length - 4, 2048)
        for ($i = 0; $i -lt $limit; $i++) {
            if ($data[$i] -eq 13 -and $data[$i+1] -eq 10 -and $data[$i+2] -eq 13 -and $data[$i+3] -eq 10) { $start = $i + 4; break }
        }

        # TS sync byte 0x47 every 188 bytes
        $sync = -1
        $scan = [Math]::Min($data.Length - 189, $start + 512)
        for ($i = $start; $i -lt $scan; $i++) {
            if ($data[$i] -eq 0x47) {
                if (($i + 188) -lt $data.Length -and $data[$i+188] -eq 0x47) { $sync = $i; break }
                if (($i + 188) -ge $data.Length) { $sync = $i; break }
            }
        }
        if ($sync -lt 0) { return "FAIL: got $($data.Length) bytes but no MPEG-TS sync" }
        return "OK: MPEG-TS, $($data.Length) bytes, sync byte 0x47"
    } catch {
        return "FAIL: " + $_.Exception.Message
    } finally {
        $c.Close()
    }
}

Write-Host "=== XCPC-Stream-Kit status ==="
Write-Host "base : $base"
Write-Host ""

Write-Host "[processes]"
$found = $false
foreach ($n in @('ffmpeg', 'vlc')) {
    foreach ($p in (Get-Process -Name $n -ErrorAction SilentlyContinue)) {
        $path = $null
        try { $path = $p.Path } catch { }
        # trailing separator is required: without it "D:\x\Kit" also matches
        # "D:\x\Kit-old\bin\ffmpeg.exe", i.e. a zip extracted next to this one
        if ($path -and $path.StartsWith($base + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
            $found = $true
            $up = ''
            try {
                $ts = [DateTime]::Now - $p.StartTime
                if ($ts.TotalDays -ge 1) { $up = [string]::Format('{0}d {1:00}:{2:00}:{3:00}', $ts.Days, $ts.Hours, $ts.Minutes, $ts.Seconds) }
                else { $up = $ts.ToString('hh\:mm\:ss') }
            } catch { }
            Write-Host ("  {0,-8} pid={1,-6} cpu={2,-8} up={3}" -f $p.ProcessName, $p.Id, [math]::Round($p.CPU, 1), $up)
        }
    }
}
if (-not $found) { Write-Host "  none - not running" }
Write-Host ""

Write-Host "[streams]"
Write-Host ("  screen  tcp/{0}  {1}" -f $ScreenPort, (Test-TsStream $ScreenPort))
Write-Host ("  camera  tcp/{0}  {1}" -f $CamPort,    (Test-TsStream $CamPort))
Write-Host ""

Write-Host "[logs]"
foreach ($f in @('prep.log', 'screen.log', 'screen-vlc.log', 'camera.log', 'camera-vlc.log', 'screen-fallback.log')) {
    $p = Join-Path $base ("logs\" + $f)
    if ((Test-Path -LiteralPath $p) -and (Get-Item -LiteralPath $p).Length -gt 3) {
        Write-Host "  --- $f ---"
        Get-Content -LiteralPath $p -Tail $TailLines -Encoding Default | ForEach-Object { Write-Host ("  " + $_) }
    }
}
