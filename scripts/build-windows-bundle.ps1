param(
    [Parameter(Mandatory = $true)]
    [string]$SingBoxPath,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F]{64}$')]
    [string]$SingBoxSha256
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$CoreRoot = Join-Path $ProjectRoot 'core'
$AppRoot = Join-Path $ProjectRoot 'app'
$NativeOutput = Join-Path $ProjectRoot 'build\windows-native'
$RouterCtl = Join-Path $NativeOutput 'routerctl.exe'

if (-not (Test-Path -LiteralPath $SingBoxPath -PathType Leaf)) {
    throw "sing-box.exe was not found: $SingBoxPath"
}

$ActualHash = (Get-FileHash -LiteralPath $SingBoxPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($ActualHash -ne $SingBoxSha256.ToLowerInvariant()) {
    throw 'sing-box.exe SHA-256 verification failed.'
}

New-Item -ItemType Directory -Force -Path $NativeOutput | Out-Null
Push-Location $CoreRoot
try {
    go test ./...
    go vet ./...
    go build -trimpath -ldflags '-s -w' -o $RouterCtl ./cmd/routerctl
}
finally {
    Pop-Location
}

$PreviousRouterCtl = $env:ADAPTIVE_VPN_ROUTERCTL_BUNDLE
$PreviousSingBox = $env:ADAPTIVE_VPN_SING_BOX_BUNDLE
$env:ADAPTIVE_VPN_ROUTERCTL_BUNDLE = $RouterCtl
$env:ADAPTIVE_VPN_SING_BOX_BUNDLE = (Resolve-Path -LiteralPath $SingBoxPath).Path
Push-Location $AppRoot
try {
    flutter pub get
    flutter analyze
    flutter test
    flutter build windows --release
}
finally {
    Pop-Location
    $env:ADAPTIVE_VPN_ROUTERCTL_BUNDLE = $PreviousRouterCtl
    $env:ADAPTIVE_VPN_SING_BOX_BUNDLE = $PreviousSingBox
}

Write-Host 'Windows bundle built successfully.'
Write-Host (Join-Path $AppRoot 'build\windows\x64\runner\Release')
