@echo off
REM ===========================================================================
REM  SCREEN STREAM
REM  ffmpeg (desktop capture + h264 encode) --pipe--> VLC (serves HTTP MPEG-TS)
REM  Ported from unicup-finals-2025  ansible/files/start-vlc-screen (MODE=ffmpeg).
REM    - ffmpeg grabs and encodes, VLC only distributes: many clients can pull
REM      the same stream (CDS, OBS, a browser) without re-encoding.
REM    - restarts itself after a broken pipe (like systemd Restart=always).
REM    - exits when STOP.flag exists (created by stop.bat).
REM  Do not double click this; use start-silent.vbs or start-debug.bat.
REM  ASCII only (see config.bat header).
REM ===========================================================================

call "%~dp0_common.bat"
if errorlevel 1 exit /b 2

setlocal EnableExtensions EnableDelayedExpansion
set "LOG=%LOGDIR%\screen.log"
set "LOGV=%LOGDIR%\screen-vlc.log"
set "STOPFLAG=%BASE%\STOP.flag"
set "FAILS=0"

REM ---- single instance: check the port BEFORE touching the log files, because a
REM running instance holds screen.log open and a second one would fail there ----
call :port_busy %SCREEN_PORT%
if not errorlevel 1 goto :already_running

REM VLC needs a few seconds to load its plugins and bind the port. A second
REM instance started inside that window would still see the port as free, and
REM both would then fight over it in an endless restart loop. Re-check after a
REM short pause so the window shrinks to "double clicked within 3 seconds".
ping -n 4 127.0.0.1 >nul 2>&1
call :port_busy %SCREEN_PORT%
if not errorlevel 1 goto :already_running

echo. > "%LOG%"
echo. > "%LOGV%"

REM ---- scale filter ----
REM  0:0  = keep the native desktop size (odd sizes rounded down to even)
REM  0:H  = keep the aspect ratio, fit the height to H
REM  W:0  = keep the aspect ratio, fit the width to W
REM  W:H  = force that exact size
set "VFSCALE="
if "%SCREEN_W%"=="0" if "%SCREEN_H%"=="0" set "VFSCALE=scale=trunc(iw/2)*2:trunc(ih/2)*2,setsar=1"
if "%SCREEN_W%"=="0" if not "%SCREEN_H%"=="0" set "VFSCALE=scale=-2:%SCREEN_H%,setsar=1"
if not "%SCREEN_W%"=="0" if "%SCREEN_H%"=="0" set "VFSCALE=scale=%SCREEN_W%:-2,setsar=1"
if not "%SCREEN_W%"=="0" if not "%SCREEN_H%"=="0" set "VFSCALE=scale=%SCREEN_W%:%SCREEN_H%:flags=fast_bilinear,setsar=1"

REM ---- capture backend ----
REM  dda = Desktop Duplication API. Reads the frame DWM already composited, so
REM        the real cursor layer is never touched -> no blinking pointer, and
REM        roughly half the CPU of gdigrab.
REM  gdi = old GDI BitBlt with CAPTUREBLT. CAPTUREBLT forces DWM to redraw the
REM        cursor onto the desktop DC on every single grab; at 25 fps that is
REM        what makes the local mouse pointer flicker. Kept as a fallback only.
set "CAPMODE="
if /i "%SCREEN_CAPTURE%"=="gdi" set "CAPMODE=gdi"
if /i "%SCREEN_CAPTURE%"=="dda" set "CAPMODE=dda"
if defined CAPMODE goto :cap_ready

REM auto: probe ddagrab once (one frame, no output). Fails on pre-Win8 or when
REM the D3D11 device cannot be created, then we fall back to gdi.
"%FFMPEG%" -hide_banner -loglevel error -f lavfi -i "ddagrab=%SCREEN_OUTPUT%:framerate=1:draw_mouse=%DRAW_MOUSE%" -frames:v 1 -vf "hwdownload,format=bgra" -f null - >nul 2>&1
if errorlevel 1 (set "CAPMODE=gdi") else (set "CAPMODE=dda")
:cap_ready

set "CAPIN=-thread_queue_size 1024 -f gdigrab -framerate %SCREEN_FPS% -draw_mouse %DRAW_MOUSE% -i desktop"
set "VF=!VFSCALE!"
if /i "!CAPMODE!"=="dda" set "CAPIN=-f lavfi -i ddagrab=%SCREEN_OUTPUT%:framerate=%SCREEN_FPS%:draw_mouse=%DRAW_MOUSE%"
if /i "!CAPMODE!"=="dda" set "VF=hwdownload,format=bgra,!VFSCALE!"

REM ---- colour correction: Windows ACM only affects the dda path ----
REM  With ACM on, the dda frame is linear light labelled as sRGB -> far too
REM  dark. GDI grabs are already correct, so this is dda-only. The probe
REM  compares one dda frame against one GDI frame and only enables the fix
REM  when the dda capture is clearly darker, so non-ACM machines are left
REM  alone. Exit codes: 0 = fine, 1 = too dark, 2 = cannot tell.
set "COLORFIX=0"
if /i not "!CAPMODE!"=="dda" goto :color_ready
if /i "%SCREEN_COLOR_FIX%"=="off" goto :color_ready
if /i "%SCREEN_COLOR_FIX%"=="on" goto :color_force
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0detect_color.ps1" -Ffmpeg "%FFMPEG%" -WorkDir "%LOGDIR%" >nul 2>&1
if errorlevel 2 goto :color_ready
if errorlevel 1 set "COLORFIX=1"
goto :color_ready
:color_force
set "COLORFIX=1"
:color_ready

REM  Apply the inverse transfer function per RGB channel (linear -> sRGB is
REM  pow(x, 1/gamma), NOT pow(x, gamma)). It must run on the RGB samples and
REM  BEFORE the pixel format conversion, which is left to -pix_fmt so that
REM  h264_qsv (nv12) and libx264 (yuv420p) both work without a conflicting
REM  format filter at the end of the chain.
if "!COLORFIX!"=="1" set "VF=!VF!,lutrgb=r='pow(val/255,1/%SCREEN_GAMMA%)*255':g='pow(val/255,1/%SCREEN_GAMMA%)*255':b='pow(val/255,1/%SCREEN_GAMMA%)*255'"

echo [%date:~0,10% %time:~0,8%] ===== screen stream start  port=%SCREEN_PORT%  %SCREEN_W%x%SCREEN_H%@%SCREEN_FPS%  enc=%ENCODER% ===== >> "%LOG%"
echo   ffmpeg  = %FFMPEG% >> "%LOG%"
echo   vlc     = %VLCEXE% >> "%LOG%"
echo   capture = !CAPMODE! >> "%LOG%"
echo   colour  = gamma_fix=!COLORFIX!  gamma=%SCREEN_GAMMA% >> "%LOG%"

REM ---- per-encoder options ----
set "ENC=-pix_fmt yuv420p"
if /i "%ENCODER%"=="libx264"    set "ENC=-preset %PRESET% -tune %X264_TUNE% -profile:v main -pix_fmt yuv420p"
if /i "%ENCODER%"=="h264_nvenc" set "ENC=-preset p4 -profile:v main -pix_fmt yuv420p"
if /i "%ENCODER%"=="h264_qsv"   set "ENC=-preset veryfast -profile:v main -pix_fmt nv12"

:loop
if exist "%STOPFLAG%" (
    echo [%date:~0,10% %time:~0,8%] STOP.flag seen, screen stream exit >> "%LOG%"
    goto :eof
)

echo [%date:~0,10% %time:~0,8%] capturing desktop, serving on %BIND_ADDR%:%SCREEN_PORT% >> "%LOG%"

REM ffmpeg stderr -> screen.log, VLC stdout/stderr -> screen-vlc.log.
REM Never point both sides of a pipe at the same file: cmd locks it.
REM VLC runs without --quiet on purpose: when it bails out at startup (for
REM example "playlist is empty" because stdin was not usable) that message is
REM the only clue we get, and --quiet swallows it. Its exit code is logged too,
REM because in "a | b" cmd only reports the exit code of b.
"%FFMPEG%" -hide_banner -loglevel %LOGLEVEL% %CAPIN% -vf "!VF!" -c:v %ENCODER% %ENC% -g %KEYINT% -b:v %SCREEN_BITRATE%k -maxrate %SCREEN_BITRATE%k -bufsize %SCREEN_BITRATE%k -f mpegts - 2>>"%LOG%" | "%VLCEXE%" -I dummy --ignore-config --no-one-instance --no-stats --no-osd --no-video-title-show --play-and-exit --sout-keep - "--sout=#standard{access=http,mux=ts,dst=%BIND_ADDR%:%SCREEN_PORT%,name=stream,mime=video/ts}" >>"%LOGV%" 2>&1
set "VLEXIT=!errorlevel!"
echo [%date:~0,10% %time:~0,8%] vlc exited with code !VLEXIT! >> "%LOG%"

set /a FAILS+=1
set "DELAY=%RESTART_DELAY%"
if !FAILS! GEQ 5 set "DELAY=30"
if !FAILS! GEQ 5 (
    echo [%date:~0,10% %time:~0,8%] failed !FAILS! times in a row, retrying every !DELAY!s. Desktop locked or moved to another session? >> "%LOG%"
) else (
    echo [%date:~0,10% %time:~0,8%] stream broken, attempt !FAILS!, restart in !DELAY!s >> "%LOG%"
)
set /a PINGN=!DELAY!+1
ping -n !PINGN! 127.0.0.1 >nul 2>&1
goto loop

:already_running
echo [XCPC-Stream-Kit] port %SCREEN_PORT% already in use - screen stream already running, nothing to do.
exit /b 0

REM ---------------------------------------------------------------------------
REM  port check: errorlevel 1 = free, 0 = already listening
REM ---------------------------------------------------------------------------
:port_busy
netstat -ano -p TCP 2>nul | findstr /c:":%~1 " | findstr /c:"LISTENING" >nul 2>&1
if errorlevel 1 exit /b 1
exit /b 0
