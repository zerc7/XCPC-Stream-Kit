# detect_ip.ps1 - print the IPv4 address that a remote machine (CDS) should use.
#
# Picking "the first non-loopback IPv4" is wrong on almost every contest PC:
# VMware, Hyper-V, WSL and Bluetooth adapters all add addresses, and some of
# them carry a gateway too, so they win the first match. This walks the routing
# table instead: the adapter with the default route and the lowest interface
# metric is the one Windows itself would send traffic out of.
#
# Prints nothing when no default route exists (an isolated contest LAN without
# a gateway); the caller then falls back to ipconfig and finally to 0.0.0.0.
#
# -All lists every candidate, one per line as "alias<TAB>address<TAB>metric",
# which prep.bat writes to the log so a wrong pick is obvious.
param([switch]$All)

$ErrorActionPreference = 'SilentlyContinue'

$candidates = @()
foreach ($cfg in @(Get-NetIPConfiguration)) {
    $addr = @($cfg.IPv4Address)[0].IPAddress
    if (-not $addr) { continue }
    if ($addr -like '127.*' -or $addr -like '169.254.*') { continue }

    $metric = (Get-NetIPInterface -InterfaceIndex $cfg.InterfaceIndex -AddressFamily IPv4).InterfaceMetric
    if ($null -eq $metric) { $metric = 9999 }

    $hasRoute = [bool]$cfg.IPv4DefaultGateway.NextHop

    $candidates += [pscustomobject]@{
        Alias   = $cfg.InterfaceAlias
        Address = $addr
        Metric  = [int]$metric
        Route   = $hasRoute
    }
}

if ($All) {
    # ASCII only: this ends up in prep.log, and a localized interface alias
    # ("以太网") would be written in the console code page and look like garbage
    # on a machine with a different locale.
    foreach ($c in ($candidates | Sort-Object @{e='Route';Descending=$true}, Metric)) {
        $tag = if ($c.Route) { 'default-route' } else { 'no-route' }
        Write-Output ("{0}  metric={1}  {2}" -f $c.Address, $c.Metric, $tag)
    }
    exit 0
}

# Prefer an adapter that actually routes, then the lowest interface metric.
$best = $candidates |
    Where-Object { $_.Route } |
    Sort-Object Metric |
    Select-Object -First 1

if (-not $best) {
    # no default route at all - fall back to the lowest metric overall
    $best = $candidates | Sort-Object Metric | Select-Object -First 1
}

if ($best) { Write-Output $best.Address }
exit 0
