# uninstall.ps1 - remove the logon autostart shortcut.
$ErrorActionPreference = 'SilentlyContinue'
$startup = [Environment]::GetFolderPath('Startup')

$removed = 0
# XCPC-Stream-Kit.lnk is the current name, ICPC-Stream.lnk the one written by
# older versions of this package.
foreach ($n in @('XCPC-Stream-Kit.lnk', 'ICPC-Stream.lnk')) {
    $lnk = Join-Path $startup $n
    if (Test-Path -LiteralPath $lnk) {
        Remove-Item -LiteralPath $lnk -Force
        Write-Host "[uninstall] removed: $lnk"
        $removed++
    }
}

if ($removed -eq 0) { Write-Host "[uninstall] no startup shortcut found" }
exit 0
