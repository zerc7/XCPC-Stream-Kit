@echo off
REM ===========================================================================
REM  FALLBACK: screen streaming with VLC only, no ffmpeg.
REM  This is the ansible/files/start-vlc-screen MODE=vlc path. Use it only if
REM  stream_screen.bat cannot capture the desktop (gdigrab problems on some
REM  GPUs / driver setups). Never run it while stream_screen.bat is running:
REM  both would fight for the same port.
REM  ASCII only (see config.bat header).
REM ===========================================================================
call "%~dp0scripts\prep.bat" >nul
if errorlevel 1 exit /b 2

setlocal EnableExtensions EnableDelayedExpansion
set "LOG=%LOGDIR%\screen-fallback.log"
set "STOPFLAG=%BASE%\STOP.flag"
set "FAILS=0"

REM check the port before opening the log: a running stream holds its log file
call :port_busy %SCREEN_PORT%
if not errorlevel 1 (
    echo [XCPC-Stream-Kit] port %SCREEN_PORT% already in use, nothing to do.
    exit /b 0
)

echo. > "%LOG%"
echo [%date:~0,10% %time:~0,8%] ===== VLC-only screen capture  port=%SCREEN_PORT% ===== >> "%LOG%"

REM width/height only when both are pinned; 0 means "native" and VLC would
REM choke on width=0,height=0 in the transcode string
set "SCALEVLC="
if not "%SCREEN_W%"=="0" if not "%SCREEN_H%"=="0" set "SCALEVLC=,width=%SCREEN_W%,height=%SCREEN_H%"

:loop
if exist "%STOPFLAG%" (
    echo [%date:~0,10% %time:~0,8%] STOP.flag seen, exit >> "%LOG%"
    goto :eof
)
echo [%date:~0,10% %time:~0,8%] VLC screen:// on %BIND_ADDR%:%SCREEN_PORT% >> "%LOG%"
"%VLCEXE%" -I dummy --ignore-config --no-one-instance --no-stats --no-osd --no-video-title-show --play-and-exit --sout-keep screen:// --screen-fps=%SCREEN_FPS% "--sout=#transcode{vcodec=h264,vb=%SCREEN_BITRATE%,fps=%SCREEN_FPS%!SCALEVLC!,acodec=none}:standard{access=http,mux=ts,dst=%BIND_ADDR%:%SCREEN_PORT%,name=stream,mime=video/ts}" >>"%LOG%" 2>&1
set "VLEXIT=!errorlevel!"
echo [%date:~0,10% %time:~0,8%] VLC exited with code !VLEXIT! >> "%LOG%"

set /a FAILS+=1
echo [%date:~0,10% %time:~0,8%] VLC exited, attempt !FAILS!, restart in %RESTART_DELAY%s >> "%LOG%"
set /a PINGN=%RESTART_DELAY%+1
ping -n !PINGN! 127.0.0.1 >nul 2>&1
goto loop

REM ---------------------------------------------------------------------------
REM  port check: errorlevel 1 = free, 0 = already listening
REM ---------------------------------------------------------------------------
:port_busy
netstat -ano -p TCP 2>nul | findstr /c:":%~1 " | findstr /c:"LISTENING" >nul 2>&1
if errorlevel 1 exit /b 1
exit /b 0
