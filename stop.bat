@echo off
REM ===========================================================================
REM  Stop both streams. Only kills the ffmpeg / vlc processes that live in this
REM  folder, so your own VLC player windows are not touched.
REM  ASCII only (see config.bat header).
REM ===========================================================================
setlocal
cd /d "%~dp0"

set "SCREEN_PORT=9090"
set "CAM_PORT=9092"
call "%~dp0scripts\_common.bat" >nul 2>&1

echo stopping XCPC-Stream-Kit streams and their restart loops ...
echo (only processes started from this folder are killed)
echo.

REM drop the stop flag first: the restart loops check it and will not respawn
type nul > "%~dp0STOP.flag"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\stop.ps1" -BasePath "%~dp0."

echo.
echo port state:
netstat -ano -p TCP | findstr /c:":%SCREEN_PORT% " /c:":%CAM_PORT% " | findstr /c:"LISTENING"
echo (no output above = both ports released)
echo.
echo STOP.flag stays here on purpose; prep.bat deletes it on the next start.
echo.
if not defined XCPC_NOPAUSE if /i not "%~1"=="/q" pause
