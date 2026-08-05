$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$scriptPath = Join-Path $repo "scripts/compile-jrxml.ps1"
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("jasper-skill-test-" + [guid]::NewGuid().ToString("N"))

try {
    New-Item -ItemType Directory -Force -Path $testRoot | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $testRoot "lib") | Out-Null
    Set-Content -LiteralPath (Join-Path $testRoot "invalid.jrxml") -Value '<jasperReport><broken></jasperReport>' -Encoding UTF8

    $output = & $scriptPath `
        -Jrxml "invalid.jrxml" `
        -ProjectRoot $testRoot `
        -LibDirectory "lib" 2>&1 | Out-String
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        throw "Expected malformed XML to return a non-zero exit."
    }
    if ($output -notmatch "Malformed XML") {
        throw "Expected a clear malformed XML error, received: $output"
    }

    Write-Host "compile-jrxml contract tests passed"
} finally {
    Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}
