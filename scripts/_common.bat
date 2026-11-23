@echo off
REM ===========================================================================
REM  Shared init: resolve paths, load config.bat, locate ffmpeg / VLC.
REM  Usage: call "%~dp0_common.bat"   -> errorlevel 0 ok, 2 no ffmpeg, 3 no VLC
REM  Produces: BASE (package root, no trailing backslash) LOGDIR FFMPEG VLCEXE
REM  ASCII only (see config.bat header).
REM ===========================================================================

set "FFMPEG="
set "VLCEXE="

for %%i in ("%~dp0..") do set "BASE=%%~fi"
call "%BASE%\config.bat"

set "LOGDIR=%BASE%\logs"
if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1

REM The two binaries are always the portable copies fetched by fetch-deps.ps1.
REM A system-wide ffmpeg / VLC on PATH is deliberately NOT used: those builds
REM may lack ddagrab or ship different plugins, which turns into a bug report
REM that cannot be reproduced here.
if exist "%BASE%\bin\ffmpeg.exe" set "FFMPEG=%BASE%\bin\ffmpeg.exe"
if exist "%BASE%\bin\vlc\vlc.exe" set "VLCEXE=%BASE%\bin\vlc\vlc.exe"

if not defined FFMPEG (
    echo [XCPC-Stream-Kit] ERROR: %BASE%\bin\ffmpeg.exe is missing.
    echo                    Run: powershell -ExecutionPolicy Bypass -File "%BASE%\fetch-deps.ps1"
    exit /b 2
)
if not defined VLCEXE (
    echo [XCPC-Stream-Kit] ERROR: %BASE%\bin\vlc\vlc.exe is missing.
    echo                    Run: powershell -ExecutionPolicy Bypass -File "%BASE%\fetch-deps.ps1"
    exit /b 3
)
exit /b 0
