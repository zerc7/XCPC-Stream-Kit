@echo off
REM ===========================================================================
REM  Install: logon autostart + firewall + start now + health check.
REM  Right click -> Run as administrator is recommended (firewall part).
REM  Pass /q to skip the final pause (for unattended / mass deployment).
REM  ASCII only (see config.bat header).
REM ===========================================================================
setlocal
cd /d "%~dp0"

echo ============================================================
echo   XCPC-Stream-Kit installer
echo     1. shortcut in the Startup folder (silent streaming on logon)
echo     2. inbound firewall rules for the two stream ports (admin)
echo     3. start both streams now, then run a health check
echo ============================================================
echo.

REM loads config.bat and verifies bin\ffmpeg.exe + bin\vlc\vlc.exe (bin\ is not
REM part of the git repo, see fetch-deps.ps1)
call "%~dp0scripts\_common.bat"
if errorlevel 1 (
    if not defined XCPC_NOPAUSE if /i not "%~1"=="/q" pause
    exit /b 1
)

set "XCPC_BASE=%CD%"
set "XCPC_VBS=%~dp0start-silent.vbs"
if not exist "%XCPC_VBS%" (
    echo [ERROR] start-silent.vbs is missing from this folder.
    if not defined XCPC_NOPAUSE if /i not "%~1"=="/q" pause
    exit /b 1
)

REM admin check: fsutil needs elevation and, unlike "net session", does not
REM depend on the Server service (often disabled on Windows 10/11 clients)
set "ADMIN=0"
fsutil dirty query %SystemDrive% >nul 2>&1 && set "ADMIN=1"
if "%ADMIN%"=="0" (
    echo [WARN] not running as administrator: firewall rules will be skipped.
    echo        Close this window and use "Run as administrator" if CDS
    echo        cannot pull the streams.
    echo.
)

echo [1/3] creating startup shortcut ...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\install.ps1"
if errorlevel 1 echo [WARN] shortcut creation failed, see messages above.

if "%ADMIN%"=="0" goto :skip_fw

echo.
echo [2/3] configuring firewall ...
netsh advfirewall firewall delete rule name="XCPC-Stream-Kit Screen" >nul 2>&1
netsh advfirewall firewall delete rule name="XCPC-Stream-Kit Camera" >nul 2>&1
netsh advfirewall firewall add rule name="XCPC-Stream-Kit Screen" dir=in action=allow protocol=TCP localport=%SCREEN_PORT% profile=any >nul
netsh advfirewall firewall add rule name="XCPC-Stream-Kit Camera" dir=in action=allow protocol=TCP localport=%CAM_PORT% profile=any >nul
if errorlevel 1 (
    echo        [WARN] failed, maybe blocked by group policy.
    echo               Allow inbound TCP %SCREEN_PORT% and %CAM_PORT% manually.
) else (
    echo        inbound TCP %SCREEN_PORT% / %CAM_PORT% allowed.
)
goto :start_now

:skip_fw
echo [2/3] firewall: skipped.

:start_now
echo.
echo [3/3] starting streams silently ...
"%SystemRoot%\System32\wscript.exe" "%XCPC_VBS%"
echo        waiting 8s, then health check ...
ping -n 9 127.0.0.1 >nul

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\status.ps1" -BasePath "%~dp0." -ScreenPort %SCREEN_PORT% -CamPort %CAM_PORT%

echo.
echo ============================================================
echo  Done. Streams will start silently on every logon from now on.
echo  stop.bat      = stop now
echo  status.bat    = health check
echo  uninstall.bat = remove autostart and firewall rules
echo ============================================================
if not defined XCPC_NOPAUSE if /i not "%~1"=="/q" pause
