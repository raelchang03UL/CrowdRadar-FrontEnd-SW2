[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{40}$')][string]$ExpectedSha,
    [Parameter(Mandatory)][string]$ApiOrigin,
    [Parameter(Mandatory)][string]$FirebaseDefinesPath,
    [Parameter(Mandatory)][string]$FlutterSdkPath
)
$ErrorActionPreference = 'Stop'
$sourceRoot = Split-Path -Parent $PSScriptRoot
$helper = Join-Path $PSScriptRoot 'demo_web_output.mjs'
$FlutterSdkPath = (Resolve-Path -LiteralPath $FlutterSdkPath).Path
$flutterCommand = Join-Path $FlutterSdkPath 'bin/flutter.bat'
$publicFile = (Resolve-Path -LiteralPath $FirebaseDefinesPath).Path
$previousAnalyticsSetting = $env:FLUTTER_SUPPRESS_ANALYTICS
if (-not (Test-Path -LiteralPath $flutterCommand -PathType Leaf)) { throw 'DEMO_FLUTTER_NOT_FOUND' }
Push-Location -LiteralPath $sourceRoot
try {
    & node $helper prepare $ExpectedSha $ApiOrigin $publicFile $FlutterSdkPath
    if ($LASTEXITCODE -ne 0) { throw 'DEMO_PREFLIGHT_FAILED' }
    $env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
    $steps = @(
        @{ Name='pub-get'; Arguments=@('--no-version-check','pub','get','--offline','--enforce-lockfile') },
        @{ Name='analyze'; Arguments=@('--no-version-check','analyze','--no-pub') },
        @{ Name='test'; Arguments=@('--no-version-check','test','--no-pub','--reporter','expanded') },
        @{ Name='build'; Arguments=@('--no-version-check','build','web','--no-pub','--release','--pwa-strategy=none','--no-source-maps','--no-web-resources-cdn','--dart-define-from-file=.vercel/demo-public-defines.json') }
    )
    foreach ($step in $steps) {
        $stepArguments = $step.Arguments
        $logFile = Join-Path $sourceRoot ('.vercel/demo-' + $step.Name + '.log')
        & $flutterCommand @stepArguments 2>&1 | Tee-Object -FilePath $logFile
        if ($LASTEXITCODE -ne 0) { throw ('DEMO_FLUTTER_' + $step.Name.ToUpperInvariant() + '_FAILED') }
    }
    & node $helper package $ExpectedSha
    if ($LASTEXITCODE -ne 0) { throw 'DEMO_PACKAGE_FAILED' }
    Write-Output 'Paquete local: .vercel/output; evidencia privada de trabajo: .vercel/demo-manifest.json. No publicado.'
} finally {
    $env:FLUTTER_SUPPRESS_ANALYTICS = $previousAnalyticsSetting
    Pop-Location
}
