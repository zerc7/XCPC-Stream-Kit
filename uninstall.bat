@echo off
REM ===========================================================================
REM  Uninstall: stop streams + remove logon autostart + remove firewall rules.
REM  The folder itself is not deleted; remove it by hand if you want.
REM  Pass /q to skip the final pause (for unattended / mass deployment).
REM  ASCII only (see config.bat header).
REM ===========================================================================
setlocal
cd /d "%~dp0"

echo ============================================================
echo   XCPC-Stream-Kit uninstall
echo ============================================================
echo.

echo [1/3] stopping streams ...
type nul > "%~dp0STOP.flag"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\stop.ps1" -BasePath "%~dp0."

echo.
echo [2/3] removing startup shortcut ...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\uninstall.ps1"

echo.
echo [3/3] removing firewall rules ...
set "ADMIN=0"
fsutil dirty query %SystemDrive% >nul 2>&1 && set "ADMIN=1"
if "%ADMIN%"=="0" (
    echo        not administrator, skipped. Run as administrator to remove them.
) else (
    REM both the current and the pre-rename rule names
    netsh advfirewall firewall delete rule name="XCPC-Stream-Kit Screen" >nul 2>&1
    netsh advfirewall firewall delete rule name="XCPC-Stream-Kit Camera" >nul 2>&1
    netsh advfirewall firewall delete rule name="ICPC-Stream Screen" >nul 2>&1
    netsh advfirewall firewall delete rule name="ICPC-Stream Camera" >nul 2>&1
    echo        done.
)

echo.
echo Finished. You can delete this folder now (logs are in logs\).
if not defined XCPC_NOPAUSE if /i not "%~1"=="/q" pause
