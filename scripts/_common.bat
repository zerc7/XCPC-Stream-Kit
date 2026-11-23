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

REM ---- ffmpeg: prefer the copy shipped in this folder, then PATH ----
if exist "%BASE%\bin\ffmpeg.exe" set "FFMPEG=%BASE%\bin\ffmpeg.exe"
if not defined FFMPEG for %%P in (ffmpeg.exe) do if not "%%~$PATH:P"=="" set "FFMPEG=%%~$PATH:P"

REM ---- VLC: prefer the portable copy (with its own plugins), then a normal install ----
if exist "%BASE%\bin\vlc\vlc.exe" set "VLCEXE=%BASE%\bin\vlc\vlc.exe"
if not defined VLCEXE if exist "%ProgramFiles%\VideoLAN\VLC\vlc.exe" set "VLCEXE=%ProgramFiles%\VideoLAN\VLC\vlc.exe"
if not defined VLCEXE if exist "%ProgramFiles(x86)%\VideoLAN\VLC\vlc.exe" set "VLCEXE=%ProgramFiles(x86)%\VideoLAN\VLC\vlc.exe"

if not defined FFMPEG (
    echo [XCPC-Stream-Kit] ERROR: ffmpeg.exe not found, expected at %BASE%\bin\ffmpeg.exe
    exit /b 2
)
if not defined VLCEXE (
    echo [XCPC-Stream-Kit] ERROR: vlc.exe not found, expected at %BASE%\bin\vlc\vlc.exe
    exit /b 3
)
exit /b 0
