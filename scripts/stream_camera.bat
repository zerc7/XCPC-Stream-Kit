@echo off
REM ===========================================================================
REM  CAMERA STREAM
REM  ffmpeg (dshow capture + h264 encode) --pipe--> VLC (serves HTTP MPEG-TS)
REM  Ported from unicup-finals-2025  ansible/files/start-vlc-dualwebcam (MODE=ffmpeg).
REM    - the device name is auto-detected by detect_camera.ps1, which returns the
REM      ASCII "@device_pnp_..." alternative name, so localized names such as a
REM      Chinese "Integrated Camera" can never break the command line.
REM    - that name contains "&", which is why it is only ever referenced with
REM      delayed expansion (!CAMDEV!): %CAMDEV% would be expanded before cmd
REM      parses the line and the "&" would split the command.
REM    - webcam unplugged / busy -> retry every 15s, recovers when replugged.
REM    - the device is re-probed after 3 consecutive failures, so swapping to a
REM      different camera also recovers without restarting the script.
REM  Do not double click this; use start-silent.vbs or start-debug.bat.
REM  ASCII only (see config.bat header).
REM ===========================================================================

call "%~dp0_common.bat"
if errorlevel 1 exit /b 2

setlocal EnableExtensions EnableDelayedExpansion
set "LOG=%LOGDIR%\camera.log"
set "LOGV=%LOGDIR%\camera-vlc.log"
set "STOPFLAG=%BASE%\STOP.flag"
set "CAMDEV="
set "FAILS=0"

REM ---- single instance: check the port BEFORE touching the log files, because a
REM running instance holds camera.log open and a second one would fail there ----
call :port_busy %CAM_PORT%
if not errorlevel 1 goto :already_running

REM VLC needs a few seconds to load its plugins and bind the port; re-check so a
REM double click inside that window does not start two instances.
ping -n 4 127.0.0.1 >nul 2>&1
call :port_busy %CAM_PORT%
if not errorlevel 1 goto :already_running

echo. > "%LOG%"
echo. > "%LOGV%"
echo [%date:~0,10% %time:~0,8%] ===== camera stream start  port=%CAM_PORT%  %CAM_W%x%CAM_H%@%CAM_FPS%  enc=%ENCODER% ===== >> "%LOG%"
echo   ffmpeg = %FFMPEG% >> "%LOG%"
echo   vlc    = %VLCEXE% >> "%LOG%"

REM ---- scale: fill the target box, then center-crop, so faces are not stretched ----
set "VF=fps=%CAM_FPS%,setsar=1"
if not "%CAM_W%"=="0" set "VF=fps=%CAM_FPS%,scale=%CAM_W%:%CAM_H%:force_original_aspect_ratio=increase,crop=%CAM_W%:%CAM_H%,setsar=1"

set "ENC=-pix_fmt yuv420p"
if /i "%ENCODER%"=="libx264"    set "ENC=-preset %PRESET% -tune %X264_TUNE% -profile:v main -pix_fmt yuv420p"
if /i "%ENCODER%"=="h264_nvenc" set "ENC=-preset p4 -profile:v main -pix_fmt yuv420p"
if /i "%ENCODER%"=="h264_qsv"   set "ENC=-preset veryfast -profile:v main -pix_fmt nv12"

:loop
if exist "%STOPFLAG%" (
    echo [%date:~0,10% %time:~0,8%] STOP.flag seen, camera stream exit >> "%LOG%"
    goto :eof
)

REM A camera that vanished (unplugged, or replaced by a different model) keeps
REM its old device name forever, so the stream would fail in a loop. Every 3rd
REM consecutive failure, throw the name away and look again.
set /a "PROBEMOD=!FAILS! %% 3"
if !FAILS! GTR 0 if !PROBEMOD! EQU 0 (
    set "CAMDEV="
    echo [%date:~0,10% %time:~0,8%] re-probing capture devices after !FAILS! failures >> "%LOG%"
)

if not defined CAMDEV call :detect
if not defined CAMDEV (
    echo [%date:~0,10% %time:~0,8%] no camera found, retry in 15s - check if another app is holding it >> "%LOG%"
    ping -n 16 127.0.0.1 >nul 2>&1
    set /a FAILS+=1
    goto loop
)

if /i "!AUDIO_DEVICE!"=="none" goto :run_mute

echo [%date:~0,10% %time:~0,8%] device=!CAMDEV!  mic=!AUDIO_DEVICE! >> "%LOG%"
"%FFMPEG%" -hide_banner -loglevel %LOGLEVEL% -thread_queue_size 512 -f dshow -rtbufsize 256M -i "video=!CAMDEV!" -thread_queue_size 512 -f dshow -rtbufsize 128M -i "audio=!AUDIO_DEVICE!" -map 0:v:0 -map 1:a:0 -vf "%VF%" -c:v %ENCODER% %ENC% -g %KEYINT% -b:v %CAM_BITRATE%k -maxrate %CAM_BITRATE%k -bufsize %CAM_BITRATE%k -c:a aac -b:a %AUDIO_BITRATE%k -ar 44100 -ac 2 -f mpegts - 2>>"%LOG%" | "%VLCEXE%" -I dummy --ignore-config --no-one-instance --no-stats --no-osd --no-video-title-show --play-and-exit --sout-keep - "--sout=#standard{access=http,mux=ts,dst=%BIND_ADDR%:%CAM_PORT%,name=stream,mime=video/ts}" >>"%LOGV%" 2>&1
set "VLEXIT=!errorlevel!"
echo [%date:~0,10% %time:~0,8%] vlc exited with code !VLEXIT! >> "%LOG%"
goto :after

:run_mute
echo [%date:~0,10% %time:~0,8%] device=!CAMDEV!  mic=none >> "%LOG%"
"%FFMPEG%" -hide_banner -loglevel %LOGLEVEL% -thread_queue_size 512 -f dshow -rtbufsize 256M -i "video=!CAMDEV!" -vf "%VF%" -c:v %ENCODER% %ENC% -g %KEYINT% -b:v %CAM_BITRATE%k -maxrate %CAM_BITRATE%k -bufsize %CAM_BITRATE%k -an -f mpegts - 2>>"%LOG%" | "%VLCEXE%" -I dummy --ignore-config --no-one-instance --no-stats --no-osd --no-video-title-show --play-and-exit --sout-keep - "--sout=#standard{access=http,mux=ts,dst=%BIND_ADDR%:%CAM_PORT%,name=stream,mime=video/ts}" >>"%LOGV%" 2>&1
set "VLEXIT=!errorlevel!"
echo [%date:~0,10% %time:~0,8%] vlc exited with code !VLEXIT! >> "%LOG%"

:after
set /a FAILS+=1
set "DELAY=%RESTART_DELAY%"
if !FAILS! GEQ 3 set "DELAY=15"
echo [%date:~0,10% %time:~0,8%] stream broken, attempt !FAILS!, restart in !DELAY!s >> "%LOG%"
set /a PINGN=!DELAY!+1
ping -n !PINGN! 127.0.0.1 >nul 2>&1
goto loop

:already_running
echo [XCPC-Stream-Kit] port %CAM_PORT% already in use - camera stream already running, nothing to do.
exit /b 0

REM ---------------------------------------------------------------------------
REM  detect the camera; CAMERA_DEVICE other than "auto" is used as-is
REM  result: CAMDEV (empty = nothing found)
REM ---------------------------------------------------------------------------
:detect
if /i not "!CAMERA_DEVICE!"=="auto" (
    set "CAMDEV=!CAMERA_DEVICE!"
    echo [%date:~0,10% %time:~0,8%] using configured device: !CAMERA_DEVICE! >> "%LOG%"
    exit /b 0
)
for /f "usebackq delims=" %%a in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0detect_camera.ps1" -Ffmpeg "%FFMPEG%"`) do (
    if not defined CAMDEV set "CAMDEV=%%a"
)
if defined CAMDEV echo [%date:~0,10% %time:~0,8%] auto-detected camera: !CAMDEV! >> "%LOG%"
exit /b 0

REM ---------------------------------------------------------------------------
REM  port check: errorlevel 1 = free, 0 = already listening
REM ---------------------------------------------------------------------------
:port_busy
netstat -ano -p TCP 2>nul | findstr /c:":%~1 " | findstr /c:"LISTENING" >nul 2>&1
if errorlevel 1 exit /b 1
exit /b 0
