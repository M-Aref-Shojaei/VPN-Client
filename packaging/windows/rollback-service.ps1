param([string]$StateRoot = (Join-Path $env:ProgramData 'AdaptiveVPN\installer'))

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'service-common.ps1')

Assert-AdaptiveVpnAdministrator
$manifest = Read-AdaptiveVpnManifest -StateRoot $StateRoot
if ($null -eq $manifest.previous) {
    throw 'No previous Adaptive VPN service version is available for rollback.'
}

Stop-AdaptiveVpnInstalledService -Version $manifest.current
try {
    Start-AdaptiveVpnInstalledService -Version $manifest.previous
    Write-AdaptiveVpnManifest -StateRoot $StateRoot -Current $manifest.previous -Previous $manifest.current
}
catch {
    $rollbackError = $_
    try { Stop-AdaptiveVpnInstalledService -Version $manifest.previous } catch { }
    Start-AdaptiveVpnInstalledService -Version $manifest.current
    throw "Rollback failed and the current service was restored: $($rollbackError.Exception.Message)"
}
Write-Host "Adaptive VPN service rolled back to version $($manifest.previous.version)."
