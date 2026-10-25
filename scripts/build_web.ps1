[CmdletBinding()]
param(
    [string]$ApiBaseUrl = 'https://ecovision-backend-wdr0.onrender.com',
    [string]$WorkRoot = [System.IO.Path]::GetTempPath()
)

$ErrorActionPreference = 'Stop'
$frontend = Join-Path (Split-Path -Parent $PSScriptRoot) 'frontend'
$uri = [Uri]$ApiBaseUrl
if (-not $uri.IsAbsoluteUri -or $uri.Scheme -notin @('http', 'https') -or $uri.UserInfo) {
    throw 'Pass an HTTP(S) API base URL without credentials.'
}
$output = Join-Path ([System.IO.Path]::GetFullPath($WorkRoot)) ('ecovision-web-' + [Guid]::NewGuid().ToString('N'))
if ($output -match '[^\x00-\x7F]') {
    throw 'Native shader tools require an ASCII-only output path. Pass -WorkRoot.'
}
$flutter = (Get-Command flutter -ErrorAction Stop).Source
Push-Location -LiteralPath $frontend
try {
    # Windows PowerShell can promote native stderr warnings to terminating
    # errors when output is redirected. Keep the output and check the exit code.
    try {
        $ErrorActionPreference = 'Continue'
        & $flutter build web --release --no-pub "--output=$output" "--dart-define=API_BASE_URL=$ApiBaseUrl"
        $buildExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = 'Stop'
    }
    if ($buildExitCode -ne 0) { throw "Web build failed: $buildExitCode" }
    $destination = Join-Path $frontend 'build/web'
    & robocopy $output $destination /E /XJ /R:1 /W:1 /NP /NFL /NDL
    if ($LASTEXITCODE -ge 8) { throw "Build copy failed: $LASTEXITCODE" }
    Write-Host "Verified release web bundle: $destination"
} finally {
    Pop-Location
}
