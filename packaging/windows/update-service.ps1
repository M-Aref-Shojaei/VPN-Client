param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F]{64}$')]
    [string]$SingBoxSha256,

    [string]$BundleDirectory = $PSScriptRoot,

    [string]$InstallRoot = (Join-Path $env:ProgramFiles 'Adaptive VPN'),

    [string]$StateRoot = (Join-Path $env:ProgramData 'AdaptiveVPN\installer')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'service-common.ps1')

Assert-AdaptiveVpnAdministrator
$manifest = Read-AdaptiveVpnManifest -StateRoot $StateRoot
$artifacts = Get-AdaptiveVpnArtifacts -BundleDirectory $BundleDirectory -SingBoxSha256 $SingBoxSha256
$next = Install-AdaptiveVpnVersion -Artifacts $artifacts -InstallRoot $InstallRoot
if ($next.version -eq $manifest.current.version) {
    Write-Host "Adaptive VPN service is already on version $($next.version)."
    exit 0
}

Stop-AdaptiveVpnInstalledService -Version $manifest.current
try {
    Start-AdaptiveVpnInstalledService -Version $next
    Write-AdaptiveVpnManifest -StateRoot $StateRoot -Current $next -Previous $manifest.current
}
catch {
    $updateError = $_
    try { Stop-AdaptiveVpnInstalledService -Version $next } catch { }
    Start-AdaptiveVpnInstalledService -Version $manifest.current
    throw "Update failed and the previous service was restored: $($updateError.Exception.Message)"
}
Write-Host "Adaptive VPN service updated to version $($next.version)."
