' ===========================================================================
'  XCPC-Stream-Kit silent launcher
'  Starts the screen + camera streams with NO console window at all.
'  Used by the logon shortcut created by install.bat.
'  Keep this file ASCII-only: WScript reads .vbs as ANSI unless it has a BOM.
' ===========================================================================
Option Explicit

Dim fso, sh, base, q, rc, f
Set fso = CreateObject("Scripting.FileSystemObject")
Set sh  = CreateObject("WScript.Shell")

base = fso.GetParentFolderName(WScript.ScriptFullName)
q = Chr(34)

Sub Fatal(msg)
    MsgBox "XCPC-Stream-Kit: " & msg & vbCrLf & vbCrLf & base, 16, "XCPC-Stream-Kit"
    WScript.Quit 1
End Sub

For Each f In Array("stream_screen.bat", "stream_camera.bat")
    If Not fso.FileExists(base & "\scripts\" & f) Then
        Call Fatal("cannot find scripts\" & f & " under")
    End If
Next

' The binaries are downloaded separately (see fetch-deps.ps1) and are not part
' of the repository, so a plain "git clone" is not runnable until they exist.
' Fail loudly instead of running two loops that can only fail.
If Not fso.FileExists(base & "\bin\ffmpeg.exe") Then
    Call Fatal("bin\ffmpeg.exe is missing. Run fetch-deps.ps1 first: powershell -ExecutionPolicy Bypass -File fetch-deps.ps1")
End If
If Not fso.FileExists(base & "\bin\vlc\vlc.exe") Then
    Call Fatal("bin\vlc\vlc.exe is missing. Run fetch-deps.ps1 first: powershell -ExecutionPolicy Bypass -File fetch-deps.ps1")
End If

If Not fso.FolderExists(base & "\logs") Then fso.CreateFolder(base & "\logs")
sh.CurrentDirectory = base

' 1) prepare (hidden, wait until done): logs dir, VLC plugin cache, banner
rc = sh.Run("cmd.exe /c " & q & q & base & "\scripts\prep.bat" & q & q, 0, True)
If rc <> 0 Then
    Call Fatal("preparation failed (exit code " & rc & "), see logs\prep.log")
End If

' 2) start both streams hidden; each .bat keeps its own restart loop
sh.Run "cmd.exe /c " & q & q & base & "\scripts\stream_screen.bat" & q & q, 0, False
sh.Run "cmd.exe /c " & q & q & base & "\scripts\stream_camera.bat" & q & q, 0, False

WScript.Quit 0
