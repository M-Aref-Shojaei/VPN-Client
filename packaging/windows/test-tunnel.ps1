param(
    [Parameter(Mandatory = $true)]
    [string]$ProfilePath,

    [string]$PolicyPath,

    [string]$BlockedDomain,

    [string]$StateRoot = (Join-Path $env:ProgramData 'AdaptiveVPN\installer')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'service-common.ps1')

$manifest = Read-AdaptiveVpnManifest -StateRoot $StateRoot
$routerCtl = $manifest.current.routerCtl
if (-not (Test-Path -LiteralPath $ProfilePath -PathType Leaf)) {
    throw "Profile JSON was not found: $ProfilePath"
}
$profileDocument = Get-Content -LiteralPath $ProfilePath -Raw | ConvertFrom-Json
$profile = $profileDocument
if ($null -ne $profileDocument.PSObject.Properties['outbound']) {
    $profile = $profileDocument.outbound
}
$policy = @{
    manual_direct = @()
    manual_proxy = @()
    known_blocked = @()
}
if ($PolicyPath) {
    if (-not (Test-Path -LiteralPath $PolicyPath -PathType Leaf)) {
        throw "Policy JSON was not found: $PolicyPath"
    }
    $policy = Get-Content -LiteralPath $PolicyPath -Raw | ConvertFrom-Json
}
$request = @{
    profile = $profile
    policy = $policy
    network = 'unknown'
    tun = $true
} | ConvertTo-Json -Depth 100 -Compress

$started = $false
try {
    Invoke-AdaptiveVpnRouterCtl -RouterCtl $routerCtl -Arguments @('capability') | Out-Host
    $OutputEncoding = [Text.UTF8Encoding]::new($false)
    $request | & $routerCtl start
    if ($LASTEXITCODE -ne 0) {
        throw "Tunnel start failed with exit code $LASTEXITCODE."
    }
    $started = $true
    Start-Sleep -Seconds 2
    $statusText = & $routerCtl status
    if ($LASTEXITCODE -ne 0) {
        throw "Tunnel status failed with exit code $LASTEXITCODE."
    }
    $status = $statusText | ConvertFrom-Json
    if (-not $status.running) {
        throw 'The service did not report a running tunnel.'
    }

    if ($BlockedDomain) {
        $firstProbe = & $routerCtl probe -domain $BlockedDomain -port 443 -tls=true
        if ($LASTEXITCODE -ne 0) {
            throw "First smart-routing probe failed with exit code $LASTEXITCODE."
        }
        $secondProbe = & $routerCtl probe -domain $BlockedDomain -port 443 -tls=true
        if ($LASTEXITCODE -ne 0) {
            throw "Second smart-routing probe failed with exit code $LASTEXITCODE."
        }
        $learning = $secondProbe | ConvertFrom-Json
        if (-not $learning.learned) {
            throw "The blocked-domain probe was not learned: $($learning.message)"
        }
    }

    Write-Host 'Windows TUN lifecycle smoke test passed.'
}
finally {
    if ($started) {
        & $routerCtl stop
        if ($LASTEXITCODE -ne 0) {
            Write-Error 'Tunnel cleanup failed. Run routerctl.exe stop before continuing.'
        }
    }
}
