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
$manifestPath = Get-AdaptiveVpnManifestPath -StateRoot $StateRoot
if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
    throw 'Adaptive VPN is already installed. Use update-service.ps1 for an existing installation.'
}

$artifacts = Get-AdaptiveVpnArtifacts -BundleDirectory $BundleDirectory -SingBoxSha256 $SingBoxSha256
$version = Install-AdaptiveVpnVersion -Artifacts $artifacts -InstallRoot $InstallRoot
try {
    Start-AdaptiveVpnInstalledService -Version $version
    Write-AdaptiveVpnManifest -StateRoot $StateRoot -Current $version -Previous $null
}
catch {
    $installError = $_
    try { Stop-AdaptiveVpnInstalledService -Version $version } catch { }
    throw $installError
}

Write-Host "Adaptive VPN Windows service installed and started from version $($version.version)."
