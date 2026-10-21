$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Assert-AdaptiveVpnAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Run this command from an explicitly elevated PowerShell window.'
    }
}

function Get-AdaptiveVpnArtifacts {
    param(
        [Parameter(Mandatory = $true)][string]$BundleDirectory,
        [Parameter(Mandatory = $true)][string]$SingBoxSha256
    )

    $routerCtl = Join-Path $BundleDirectory 'routerctl.exe'
    $singBox = Join-Path $BundleDirectory 'sing-box.exe'
    foreach ($path in @($routerCtl, $singBox)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Required bundle artifact was not found: $path"
        }
    }
    $actualCoreHash = (Get-FileHash -LiteralPath $singBox -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualCoreHash -ne $SingBoxSha256.ToLowerInvariant()) {
        throw 'sing-box.exe SHA-256 verification failed.'
    }
    return @{
        RouterCtl = (Resolve-Path -LiteralPath $routerCtl).Path
        SingBox = (Resolve-Path -LiteralPath $singBox).Path
        RouterHash = (Get-FileHash -LiteralPath $routerCtl -Algorithm SHA256).Hash.ToLowerInvariant()
        CoreHash = $actualCoreHash
    }
}

function Install-AdaptiveVpnVersion {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Artifacts,
        [Parameter(Mandatory = $true)][string]$InstallRoot
    )

    $version = '{0}-{1}' -f $Artifacts.RouterHash.Substring(0, 16), $Artifacts.CoreHash.Substring(0, 16)
    $versionDirectory = Join-Path $InstallRoot (Join-Path 'versions' $version)
    New-Item -ItemType Directory -Force -Path $versionDirectory | Out-Null
    $routerCtl = Join-Path $versionDirectory 'routerctl.exe'
    $singBox = Join-Path $versionDirectory 'sing-box.exe'

    if (-not (Test-Path -LiteralPath $routerCtl -PathType Leaf)) {
        Copy-Item -LiteralPath $Artifacts.RouterCtl -Destination $routerCtl
    }
    if (-not (Test-Path -LiteralPath $singBox -PathType Leaf)) {
        Copy-Item -LiteralPath $Artifacts.SingBox -Destination $singBox
    }
    if ((Get-FileHash -LiteralPath $routerCtl -Algorithm SHA256).Hash.ToLowerInvariant() -ne $Artifacts.RouterHash) {
        throw 'Installed routerctl.exe verification failed.'
    }
    if ((Get-FileHash -LiteralPath $singBox -Algorithm SHA256).Hash.ToLowerInvariant() -ne $Artifacts.CoreHash) {
        throw 'Installed sing-box.exe verification failed.'
    }
    return [ordered]@{
        version = $version
        routerCtl = $routerCtl
        singBox = $singBox
        singBoxSha256 = $Artifacts.CoreHash
    }
}

function Invoke-AdaptiveVpnRouterCtl {
    param(
        [Parameter(Mandatory = $true)][string]$RouterCtl,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    & $RouterCtl @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "routerctl failed with exit code $LASTEXITCODE."
    }
}

function Start-AdaptiveVpnInstalledService {
    param([Parameter(Mandatory = $true)]$Version)

    Invoke-AdaptiveVpnRouterCtl -RouterCtl $Version.routerCtl -Arguments @(
        'service', 'install',
        '-core', $Version.singBox,
        '-core-sha256', $Version.singBoxSha256
    )
}

function Stop-AdaptiveVpnInstalledService {
    param([Parameter(Mandatory = $true)]$Version)

    Invoke-AdaptiveVpnRouterCtl -RouterCtl $Version.routerCtl -Arguments @('service', 'uninstall')
}

function Get-AdaptiveVpnManifestPath {
    param([Parameter(Mandatory = $true)][string]$StateRoot)
    return Join-Path $StateRoot 'installed-version.json'
}

function Read-AdaptiveVpnManifest {
    param([Parameter(Mandatory = $true)][string]$StateRoot)

    $path = Get-AdaptiveVpnManifestPath -StateRoot $StateRoot
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "No Adaptive VPN installation manifest exists at $path."
    }
    return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
}

function Write-AdaptiveVpnManifest {
    param(
        [Parameter(Mandatory = $true)][string]$StateRoot,
        [Parameter(Mandatory = $true)]$Current,
        $Previous
    )

    New-Item -ItemType Directory -Force -Path $StateRoot | Out-Null
    $path = Get-AdaptiveVpnManifestPath -StateRoot $StateRoot
    $temporary = "$path.new"
    [ordered]@{
        schemaVersion = 1
        current = $Current
        previous = $Previous
        updatedAt = [DateTime]::UtcNow.ToString('o')
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $temporary -Encoding UTF8
    Move-Item -LiteralPath $temporary -Destination $path -Force
}
