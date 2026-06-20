[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Backend base URL (http/https), e.g. https://api.example.com")]
    [ValidateNotNullOrEmpty()]
    [string]$ApiBaseUrl,

    [Parameter(HelpMessage = "Google OAuth client ID for the Flutter app build")]
    [ValidateNotNullOrEmpty()]
    [string]$GoogleOauthClientId = "422876120349-gme1b8ce1vhrkagiaakpu8nj8qkqoufp.apps.googleusercontent.com",

    [switch]$SkipApk,
    [switch]$SkipAab,
    [switch]$Clean,
    [switch]$SkipPubGet,
    [switch]$RunAnalyze,
    [switch]$RunTests
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-CommandExists {
    param([Parameter(Mandatory = $true)][string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found in PATH."
    }
}

function Invoke-FlutterStep {
    param(
        [Parameter(Mandatory = $true)][string]$StepName,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    Write-Host ""
    Write-Host "==> $StepName" -ForegroundColor Cyan
    & flutter @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Step failed with exit code ${LASTEXITCODE}: flutter $($Arguments -join ' ')"
    }
}

$ApiBaseUrl = $ApiBaseUrl.Trim().TrimEnd("/")
if ([string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
    throw "ApiBaseUrl cannot be empty."
}
$GoogleOauthClientId = $GoogleOauthClientId.Trim()
if ([string]::IsNullOrWhiteSpace($GoogleOauthClientId)) {
    throw "GoogleOauthClientId cannot be empty."
}

[Uri]$parsedUrl = $null
if (-not [Uri]::TryCreate($ApiBaseUrl, [UriKind]::Absolute, [ref]$parsedUrl)) {
    throw "ApiBaseUrl must be an absolute URL. Received: '$ApiBaseUrl'"
}
if ($parsedUrl.Scheme -notin @("http", "https")) {
    throw "ApiBaseUrl must start with http:// or https://. Received: '$ApiBaseUrl'"
}

if ($SkipApk -and $SkipAab) {
    throw "Both -SkipApk and -SkipAab are set. Nothing to build."
}

$projectRoot = $PSScriptRoot
$appDir = Join-Path $projectRoot "stock_screener_app"
$androidDir = Join-Path $appDir "android"
$apkPath = Join-Path $appDir "build\app\outputs\flutter-apk\app-release.apk"
$aabPath = Join-Path $appDir "build\app\outputs\bundle\release\app-release.aab"

if (-not (Test-Path -LiteralPath $appDir -PathType Container)) {
    throw "Flutter app directory not found: $appDir"
}
if (-not (Test-Path -LiteralPath $androidDir -PathType Container)) {
    throw "Android project directory not found: $androidDir"
}

Assert-CommandExists -Name "flutter"

$startTime = Get-Date
Write-Host "Building Android release with API_BASE_URL=$ApiBaseUrl" -ForegroundColor Cyan
Write-Host "Google OAuth client ID configured for the build." -ForegroundColor Cyan
Write-Host "Project: $appDir" -ForegroundColor DarkGray

$buildArgs = @(
    "--release",
    "--dart-define=API_BASE_URL=$ApiBaseUrl",
    "--dart-define=GOOGLE_OAUTH_CLIENT_ID=$GoogleOauthClientId"
)

Push-Location $appDir
try {
    if ($Clean) {
        Invoke-FlutterStep -StepName "flutter clean" -Arguments @("clean")
    }

    if (-not $SkipPubGet) {
        Invoke-FlutterStep -StepName "flutter pub get" -Arguments @("pub", "get")
    }

    if ($RunAnalyze) {
        Invoke-FlutterStep -StepName "flutter analyze" -Arguments @("analyze")
    }

    if ($RunTests) {
        Invoke-FlutterStep -StepName "flutter test" -Arguments @("test")
    }

    if (-not $SkipApk) {
        Invoke-FlutterStep -StepName "Build APK (release)" -Arguments (@("build", "apk") + $buildArgs)
    }

    if (-not $SkipAab) {
        Invoke-FlutterStep -StepName "Build App Bundle (release)" -Arguments (@("build", "appbundle") + $buildArgs)
    }
}
finally {
    Pop-Location
}

$missingArtifacts = @()
if (-not $SkipApk -and -not (Test-Path -LiteralPath $apkPath -PathType Leaf)) {
    $missingArtifacts += $apkPath
}
if (-not $SkipAab -and -not (Test-Path -LiteralPath $aabPath -PathType Leaf)) {
    $missingArtifacts += $aabPath
}

if ($missingArtifacts.Count -gt 0) {
    throw ("Build finished but expected artifact(s) were not found:`n - " + ($missingArtifacts -join "`n - "))
}

$duration = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 2)
Write-Host ""
Write-Host "Build completed in $duration seconds." -ForegroundColor Green
if (-not $SkipApk) { Write-Host "APK: $apkPath" }
if (-not $SkipAab) { Write-Host "AAB: $aabPath" }
