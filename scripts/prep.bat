@echo off
REM ===========================================================================
REM  One-time preparation, run before the two stream scripts
REM  (started by start-silent.vbs / start-debug.bat; hidden and quick).
REM    1. create logs\
REM    2. clear the STOP.flag left by stop.bat
REM    3. build the VLC plugin cache on first run (otherwise every VLC start
REM       rescans 140 MB of plugins)
REM    4. print local IP / stream URLs / tool paths, and append them to
REM       logs\prep.log
REM  ASCII only (see config.bat header).
REM ===========================================================================

call "%~dp0_common.bat"
if errorlevel 1 exit /b 2

setlocal EnableExtensions EnableDelayedExpansion
set "PREPLOG=%LOGDIR%\prep.log"

if exist "%BASE%\STOP.flag" del /q "%BASE%\STOP.flag" >nul 2>&1

REM keep prep.log bounded: it is appended to on every start and never rotated
REM otherwise. 256 KB is roughly a thousand starts.
if exist "%PREPLOG%" for %%A in ("%PREPLOG%") do if %%~zA GTR 262144 del /q "%PREPLOG%" >nul 2>&1

set "CACHE=%BASE%\bin\vlc\plugins\plugins.dat"
if not exist "%CACHE%" if exist "%BASE%\bin\vlc\vlc-cache-gen.exe" (
    call :say "first run: building VLC plugin cache (~2s)"
    "%BASE%\bin\vlc\vlc-cache-gen.exe" "%BASE%\bin\vlc\plugins" >nul 2>&1
)

REM ---- local IP (this is the address to put in CDS cdsConfig.xml) ----
REM The streams themselves listen on BIND_ADDR; this value is only what we print
REM and log. Picking "the first non-loopback IPv4" is wrong on most contest PCs
REM (VMware / Hyper-V / WSL / Bluetooth adapters), so detect_ip.ps1 walks the
REM routing table instead. ADVERTISE_IP in config.bat overrides everything.
set "MYIP="
if /i not "%ADVERTISE_IP%"=="auto" set "MYIP=%ADVERTISE_IP%"
if defined MYIP call :say "using ADVERTISE_IP from config.bat"

if not defined MYIP (
    for /f "usebackq delims=" %%a in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0detect_ip.ps1" 2^>nul`) do if not defined MYIP set "MYIP=%%a"
)

if not defined MYIP (
    REM fallback for pre-Win8 / when PowerShell is unavailable
    for /f "tokens=2 delims=:" %%a in ('ipconfig 2^>nul ^| findstr /c:"IPv4"') do (
        set "CAND=%%a"
        set "CAND=!CAND: =!"
        if not defined MYIP (
            echo !CAND! | findstr /r "^127\. ^169\.254\." >nul || set "MYIP=!CAND!"
        )
    )
)
if not defined MYIP set "MYIP=0.0.0.0"

REM log every candidate so a wrong pick is visible without guessing
for /f "usebackq delims=" %%a in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0detect_ip.ps1" -All 2^>nul`) do echo [%date:~0,10% %time:~0,8%]   candidate: %%a >>"%PREPLOG%"

if "!MYIP!"=="0.0.0.0" call :say "WARNING: no usable IPv4 found, the URLs below are not reachable"
call :say "  if this IP is wrong, set ADVERTISE_IP in config.bat (see logs\prep.log for all adapters)"

call :say "=========================================================="
call :say "XCPC-Stream-Kit ready"
call :say "  local IP      : !MYIP!"
call :say "  screen stream : http://!MYIP!:%SCREEN_PORT%/"
call :say "  camera stream : http://!MYIP!:%CAM_PORT%/"
call :say "  screen        : %SCREEN_W%x%SCREEN_H% @ %SCREEN_FPS%fps  %SCREEN_BITRATE%k  %ENCODER%"
call :say "  camera        : %CAM_W%x%CAM_H% @ %CAM_FPS%fps  %CAM_BITRATE%k  %ENCODER%"
call :say "  ffmpeg        : %FFMPEG%"
call :say "  vlc           : %VLCEXE%"
exit /b 0

REM ---------------------------------------------------------------------------
REM  print to console and append to logs\prep.log
REM ---------------------------------------------------------------------------
:say
echo %~1
echo [%date:~0,10% %time:~0,8%] %~1 >>"%PREPLOG%"
exit /b 0
