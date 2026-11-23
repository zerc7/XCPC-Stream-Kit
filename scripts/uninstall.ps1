# uninstall.ps1 - remove the logon autostart shortcut.
$ErrorActionPreference = 'SilentlyContinue'
$startup = [Environment]::GetFolderPath('Startup')
$lnk = Join-Path $startup 'XCPC-Stream-Kit.lnk'

if (Test-Path -LiteralPath $lnk) {
    Remove-Item -LiteralPath $lnk -Force
    Write-Host "[uninstall] removed: $lnk"
} else {
    Write-Host "[uninstall] no startup shortcut found"
}
exit 0
