@echo off
REM ===========================================================================
REM  Debug start: same as start-silent.vbs but each stream keeps a visible
REM  console, so you can watch ffmpeg / VLC output on site.
REM  For a real contest use start-silent.vbs (no windows at all).
REM  ASCII only (see config.bat header).
REM ===========================================================================
setlocal
cd /d "%~dp0"

echo ============================================================
echo   XCPC-Stream-Kit  -  contestant screen + camera streaming
echo ------------------------------------------------------------
echo   Production: double click start-silent.vbs (no window)
echo   This window is for debugging only: it opens two consoles,
echo   one per stream. Closing a console stops that stream.
echo ============================================================
echo.

call "%~dp0scripts\prep.bat"

echo.
echo starting both streams ...
start "XCPC-Stream-Kit screen :%SCREEN_PORT%" cmd /c ""%~dp0scripts\stream_screen.bat""
start "XCPC-Stream-Kit camera :%CAM_PORT%" cmd /c ""%~dp0scripts\stream_camera.bat""
echo.
echo started. health check: status.bat     stop everything: stop.bat
echo.
pause >nul
