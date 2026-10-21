param([string]$StateRoot = (Join-Path $env:ProgramData 'AdaptiveVPN\installer'))

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'service-common.ps1')

Assert-AdaptiveVpnAdministrator
$manifest = Read-AdaptiveVpnManifest -StateRoot $StateRoot
Stop-AdaptiveVpnInstalledService -Version $manifest.current

Write-Host 'Adaptive VPN Windows service removed. Runtime state and rollback binaries were preserved.'
