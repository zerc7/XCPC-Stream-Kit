# install.ps1 - create the logon autostart shortcut for the silent launcher.
# Paths come from environment variables so non-ASCII folder names survive.
$ErrorActionPreference = 'Stop'

$base = $env:XCPC_BASE
$vbs  = $env:XCPC_VBS

if (-not (Test-Path -LiteralPath $vbs)) {
    Write-Host "[install] launcher not found: $vbs"
    exit 2
}

$startup = [Environment]::GetFolderPath('Startup')
$lnk = Join-Path $startup 'XCPC-Stream-Kit.lnk'

$wsh = New-Object -ComObject WScript.Shell
$s = $wsh.CreateShortcut($lnk)
$s.TargetPath       = Join-Path $env:SystemRoot 'System32\wscript.exe'
$s.Arguments        = '"' + $vbs + '"'
$s.WorkingDirectory = $base
$s.WindowStyle      = 7
$s.Description      = 'XCPC-Stream-Kit: contestant screen + camera streaming (silent)'
$s.Save()

Write-Host "[install] startup shortcut created:"
Write-Host "          $lnk"
exit 0
