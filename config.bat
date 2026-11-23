@echo off
REM ===========================================================================
REM  XCPC-Stream-Kit configuration
REM  After editing: run stop.bat, then start-silent.vbs (or start-debug.bat).
REM
REM  NOTE: no setlocal here - the variables must survive into the caller script.
REM  NOTE: keep this file ASCII-only. A .bat with UTF-8 Chinese breaks cmd's
REM        parser on non-UTF8 code pages, so all comments/messages are English.
REM ===========================================================================

REM ---------------------------------------------------------------------------
REM  1) Ports. CDS pulls the two streams from these ports.
REM     screen -> http://<this-pc-ip>:9090/     camera -> http://<ip>:9092/
REM ---------------------------------------------------------------------------
set "SCREEN_PORT=9090"
set "CAM_PORT=9092"

REM bind address: 0.0.0.0 = CDS can pull from another machine.
REM use 127.0.0.1 if you only want to watch locally.
set "BIND_ADDR=0.0.0.0"

REM The address printed by prep.bat / status.bat as "<this-pc-ip>", i.e. the one
REM you put into cdsConfig.xml. Only used for display - the streams listen on
REM BIND_ADDR.
REM   auto        = adapter with the default route, lowest interface metric
REM   <an IPv4>   = force it, e.g. 192.168.10.21
REM Set this when the machine has several real NICs (wired + WLAN + docking)
REM and Windows picks the wrong one.
set "ADVERTISE_IP=auto"

REM ---------------------------------------------------------------------------
REM  2) Screen stream
REM     SCREEN_W / SCREEN_H:
REM       1920 / 1080 = force that exact size (all teams look identical)
REM          0 /    0 = native desktop size (odd sizes are fixed automatically)
REM          0 / 1080 = keep aspect ratio, fit the height to 1080
REM       1920 /    0 = keep aspect ratio, fit the width to 1920
REM ---------------------------------------------------------------------------
set "SCREEN_W=1920"
set "SCREEN_H=1080"
set "SCREEN_FPS=25"
set "SCREEN_BITRATE=5000"

REM draw the mouse pointer into the stream: 1 = yes, 0 = no
set "DRAW_MOUSE=1"

REM ---- colour correction ----
REM Windows "Automatic Colour Management" (ACM / Advanced Colour) is ON by
REM default on many Win11 machines. It makes Desktop Duplication hand out
REM LINEAR pixels labelled as sRGB, so the captured picture looks very dark
REM with crushed shadows - while the physical screen looks perfectly normal.
REM "auto" grabs one frame each way at startup and only compensates when the
REM dda capture really is too dark, so machines without ACM stay untouched.
REM   auto = detect and fix only if needed (recommended)
REM   on   = always apply the inverse gamma (machine definitely has ACM on)
REM   off  = never touch the colours
set "SCREEN_COLOR_FIX=auto"
set "SCREEN_GAMMA=2.2"

REM capture backend:
REM   auto = Desktop Duplication (ddagrab) if the PC supports it, else GDI
REM   dda  = force Desktop Duplication. Recommended: faster, and the LOCAL
REM          mouse pointer does not blink. GDI capture repaints the cursor
REM          layer ~25 times a second, which looks like a flickering pointer.
REM   gdi  = force the old GDI grab. Only for very old Windows / odd drivers.
set "SCREEN_CAPTURE=auto"

REM monitor index for dda (0 = first / primary monitor). Ignored by gdi,
REM which grabs the whole virtual desktop (all monitors side by side).
set "SCREEN_OUTPUT=0"

REM ---------------------------------------------------------------------------
REM  3) Camera stream
REM     CAMERA_DEVICE=auto      -> auto-detect the first webcam (recommended)
REM     CAMERA_DEVICE=<name>    -> fixed device name, e.g. Integrated Camera
REM                                run list-cameras.bat to see the names
REM ---------------------------------------------------------------------------
set "CAMERA_DEVICE=auto"
set "CAM_W=1280"
set "CAM_H=720"
set "CAM_FPS=25"
set "CAM_BITRATE=2500"

REM microphone: none = no audio (default; a contestant mic picks up the whole room)
REM set a device name to stream audio, e.g. Microphone Array (Realtek(R) Audio)
set "AUDIO_DEVICE=none"
set "AUDIO_BITRATE=128"

REM ---------------------------------------------------------------------------
REM  4) Encoder
REM     ENCODER: libx264 = pure CPU, safest; h264_qsv = Intel iGPU;
REM              h264_nvenc = NVIDIA GPU
REM     Two streams (1080p + 720p) on libx264 veryfast cost roughly 2 cores.
REM     X264_TUNE=zerolatency drops B-frames/lookahead -> lowest glass-to-glass
REM     latency, best for live mixing.
REM ---------------------------------------------------------------------------
set "ENCODER=libx264"
set "PRESET=veryfast"
set "X264_TUNE=zerolatency"

REM keyframe interval in frames. CDS cuts reaction clips on keyframes,
REM so 1-2 seconds worth of frames is a good choice (50 frames @ 25fps).
set "KEYINT=50"

REM ---------------------------------------------------------------------------
REM  5) Runtime
REM     RESTART_DELAY = seconds before reconnecting after a broken stream
REM                     (same idea as systemd RestartSec=5 in the Linux image)
REM     LOGLEVEL      = error / warning / info  (info is very chatty)
REM ---------------------------------------------------------------------------
set "RESTART_DELAY=5"
set "LOGLEVEL=warning"
