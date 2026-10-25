[CmdletBinding()]
param(
    [string]$JavaHome,
    [string]$FlutterSdk,
    [ValidateSet('debug', 'release')][string]$Mode = 'debug',
    [string]$WorkRoot = [System.IO.Path]::GetTempPath(),
    [switch]$Offline
)

$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
$frontend = Join-Path $repository 'frontend'

if (-not (Test-Path -LiteralPath (Join-Path $frontend 'pubspec.yaml'))) {
    throw 'Run this script from an EcoVision checkout.'
}

if (-not $JavaHome) {
    $candidates = @(
        $env:JAVA_HOME,
        (Join-Path $env:ProgramFiles 'Android/Android Studio/jbr'),
        (Join-Path $env:ProgramFiles 'Android/Android Studio1/jbr')
    )
    foreach ($candidate in $candidates) {
        if (-not $candidate) { continue }
        $release = Join-Path $candidate 'release'
        if ((Test-Path -LiteralPath $release) -and
            (Select-String -LiteralPath $release -Pattern '^JAVA_VERSION="(17|21)(?:\.|\")' -Quiet)) {
            $JavaHome = $candidate
            break
        }
    }
}

if (-not $JavaHome -or
    -not (Test-Path -LiteralPath (Join-Path $JavaHome 'bin/java.exe')) -or
    -not (Test-Path -LiteralPath (Join-Path $JavaHome 'release')) -or
    -not (Select-String -LiteralPath (Join-Path $JavaHome 'release') -Pattern '^JAVA_VERSION="(17|21)(?:\.|\")' -Quiet)) {
    throw 'JDK 17 or 21 is required. Java 25 cannot run Gradle 8.12.'
}

if (-not $FlutterSdk) {
    $flutterCommand = Get-Command flutter -ErrorAction Stop
    $FlutterSdk = Split-Path -Parent (Split-Path -Parent $flutterCommand.Source)
}
$flutter = Join-Path $FlutterSdk 'bin/flutter.bat'
if (-not (Test-Path -LiteralPath $flutter)) {
    throw 'Flutter SDK not found. Pass -FlutterSdk with the Flutter SDK directory.'
}

# Native shader tools in this Windows toolchain cannot write to Unicode paths.
# Copy sources, not credentials/caches, into an isolated ASCII build directory.
$work = Join-Path ([System.IO.Path]::GetFullPath($WorkRoot)) ('ecovision-android-' + [Guid]::NewGuid().ToString('N'))
if ($work -match '[^\x00-\x7F]') {
    throw 'Pass -WorkRoot with an ASCII-only temporary directory.'
}
New-Item -ItemType Directory -Path $work | Out-Null
Write-Host "Isolated Android build: $work"
& robocopy $frontend $work /E /XJ /R:1 /W:1 /NP /NFL /NDL `
    /XD build .dart_tool .gradle .git .idea .vscode ephemeral `
    /XF constants.dart local.properties key.properties '*.jks' '*.keystore' '*.log' '.env*' '.flutter-plugins*'
if ($LASTEXITCODE -ge 8) { throw "Source copy failed: robocopy exit $LASTEXITCODE" }
Copy-Item -LiteralPath (Join-Path $frontend 'lib/core/constants.example.dart') `
    -Destination (Join-Path $work 'lib/core/constants.dart')
$jdkRelease = Get-Content -LiteralPath (Join-Path $JavaHome 'release')
$javaMajor = [regex]::Match(($jdkRelease -join "`n"), 'JAVA_VERSION="(17|21)').Groups[1].Value
# This generated copy follows the explicitly selected compatible JDK.
[System.IO.File]::WriteAllText((Join-Path $work 'android/gradle/gradle-daemon-jvm.properties'), "toolchainVersion=$javaMajor`n")
[System.IO.File]::AppendAllText((Join-Path $work 'android/gradle.properties'), "`norg.gradle.java.installations.paths=$($JavaHome.Replace('\', '/'))`n")

$previousJavaHome = $env:JAVA_HOME
$previousDebug = $env:DEBUG
$previousOffline = $env:ECOVISION_GRADLE_OFFLINE
$previousAppOnly = $env:ECOVISION_ANDROID_APP_ONLY
$pushedLocation = $false
try {
    $env:JAVA_HOME = $JavaHome
    $env:DEBUG = ''
    $env:ECOVISION_GRADLE_OFFLINE = if ($Offline) { 'true' } else { $null }
    $env:ECOVISION_ANDROID_APP_ONLY = 'true'
    Push-Location -LiteralPath $work
    $pushedLocation = $true
    if ($Offline) {
        & $flutter pub get --enforce-lockfile --offline
    } else {
        & $flutter pub get --enforce-lockfile
    }
    if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed: $LASTEXITCODE" }
    & $flutter build apk "--$Mode" --no-pub --target-platform android-arm64
    if ($LASTEXITCODE -ne 0) { throw "Android build failed: $LASTEXITCODE" }

    $apk = Join-Path $work "build/app/outputs/flutter-apk/app-$Mode.apk"
    if (-not (Test-Path -LiteralPath $apk)) { throw 'Build returned without the expected APK.' }
    $outputDirectory = Join-Path $frontend 'build/app/outputs/flutter-apk'
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    $output = Join-Path $outputDirectory "app-$Mode.apk"
    Copy-Item -LiteralPath $apk -Destination $output -Force
    Write-Host "APK: $output"
    Write-Host ('SHA256: ' + (Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash)
    Write-Host 'Not store-signed, not installed, no live API verification. Release currently uses the project debug signing configuration.'
} finally {
    if ($pushedLocation) { Pop-Location }
    $env:JAVA_HOME = $previousJavaHome
    $env:DEBUG = $previousDebug
    $env:ECOVISION_GRADLE_OFFLINE = $previousOffline
    $env:ECOVISION_ANDROID_APP_ONLY = $previousAppOnly
}
