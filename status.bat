@echo off
REM ===========================================================================
REM  Health check: processes, ports, whether a real MPEG-TS payload comes out,
REM  and the tail of each log.
REM  ASCII only (see config.bat header).
REM ===========================================================================
setlocal
cd /d "%~dp0"

set "SCREEN_PORT=9090"
set "CAM_PORT=9092"
call "%~dp0scripts\_common.bat" >nul 2>&1

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\status.ps1" -BasePath "%~dp0." -ScreenPort %SCREEN_PORT% -CamPort %CAM_PORT%

echo.
echo Notes:
echo   [streams] both lines must say OK. OK = MPEG-TS data was pulled from the port.
echo   FAIL means look at [logs]: usually a camera held by another app, or a
echo   locked / disconnected desktop session.
echo   From another machine: open  http://this-pc-ip:%SCREEN_PORT%/  in VLC or a browser.
echo.
if not defined XCPC_NOPAUSE if /i not "%~1"=="/q" pause
