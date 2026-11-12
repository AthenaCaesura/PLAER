$ErrorActionPreference = 'Stop'
$workspaceDir = Split-Path -Parent $PSScriptRoot
$toolDir = Join-Path $workspaceDir '.tools'
$archivePath = Join-Path $toolDir 'lean-4.35.0-windows.zip'
$lakePath = Join-Path $toolDir 'lean-4.35.0-windows\bin\lake.exe'
if (-not (Test-Path -LiteralPath $lakePath)) {
    New-Item -ItemType Directory -Path $toolDir -Force | Out-Null
    $releaseUrl = 'https://github.com/leanprover/lean4/releases/download/v4.35.0/lean-4.35.0-windows.zip'
    if (-not (Test-Path -LiteralPath $archivePath)) {
        & curl.exe -L --fail --retry 2 -o $archivePath $releaseUrl
        if ($LASTEXITCODE -ne 0) { throw 'Lean download failed' }
    }
    $expectedHash = '5FC033E93E1A7BC59C5EBF311103D2C9CD18D4B3EDDDA4FFA3414E8ADB0EF79E'
    if ((Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash -ne $expectedHash) {
        throw 'The Lean archive checksum does not match the official release'
    }
    Expand-Archive -LiteralPath $archivePath -DestinationPath $toolDir -Force
}
& $lakePath --version
Write-Output 'Ready. Build the paper with: python scripts/build.py --test'
