@echo off
REM ===========================================================================
REM  List DirectShow capture devices with ffmpeg.
REM  (video) = camera, (audio) = microphone.
REM  Normally CAMERA_DEVICE=auto in config.bat is enough; only set an explicit
REM  name when the machine has more than one camera.
REM  Pass /q to skip the final pause.
REM  ASCII only (see config.bat header).
REM ===========================================================================
setlocal
cd /d "%~dp0"

if not exist "%~dp0bin\ffmpeg.exe" (
    echo [ERROR] bin\ffmpeg.exe not found.
    echo         Run: powershell -ExecutionPolicy Bypass -File "%~dp0fetch-deps.ps1"
    if not defined XCPC_NOPAUSE if /i not "%~1"=="/q" pause
    exit /b 1
)

echo enumerating DirectShow devices (ffmpeg, ~2s) ...
echo.
echo   (video)  = camera      (audio) = microphone
echo ------------------------------------------------------------
"%~dp0bin\ffmpeg.exe" -hide_banner -list_devices true -f dshow -i dummy 2>&1
echo ------------------------------------------------------------
echo.
echo The friendly names may contain localized text. The scripts prefer the
echo ASCII "@device_pnp_..." alternative name shown under each device. If a
echo device has no alternative name, its friendly name is used as-is and then
echo depends on the code page of the console - in that case set CAMERA_DEVICE
echo in config.bat by hand to the exact name listed above.
echo.
if not defined XCPC_NOPAUSE if /i not "%~1"=="/q" pause
