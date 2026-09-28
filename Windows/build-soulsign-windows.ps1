param([string]$Version = '1.3.0', [string]$OutputDir = '.\build\windows', [string]$Python = 'python', [switch]$SkipDependencyInstall)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$out = [IO.Path]::GetFullPath((Join-Path $repo $OutputDir))
$pc = Join-Path $PSScriptRoot 'PC'
$expected = (Get-Content -LiteralPath (Join-Path $pc 'zsign.sha256') -Raw).Split(' ')[0]
$actual = (Get-FileHash -LiteralPath (Join-Path $pc 'src\ipaside_engine\vendor\zsign.exe') -Algorithm SHA256).Hash
if ($actual -ne $expected) { throw 'Bundled zsign checksum mismatch.' }
New-Item -ItemType Directory -Force -Path $out | Out-Null
Push-Location -LiteralPath $pc
try {
    & $Python -c 'import sys,struct,tkinter; assert sys.version_info[:2] in [(3,11),(3,12)] and struct.calcsize(chr(80))==8'
    if ($LASTEXITCODE -ne 0) { throw 'Python 3.11/3.12 x64 with Tk is required to build.' }
    if (-not $SkipDependencyInstall) {
        & $Python -m pip install --disable-pip-version-check -r requirements.txt -r requirements-build.txt
        if ($LASTEXITCODE -ne 0) { throw 'Dependency installation failed.' }
    }
    & $Python -m unittest discover -s tests
    if ($LASTEXITCODE -ne 0) { throw 'Desktop tests failed.' }
    & $Python -m PyInstaller --noconfirm --distpath (Join-Path $repo 'build\pc-dist') --workpath (Join-Path $repo 'build\pc-work') SoulSign-PC.spec
    if ($LASTEXITCODE -ne 0) { throw 'PyInstaller failed.' }
    $bundle = Join-Path $repo 'build\pc-dist\SoulSign-PC'
    $test = Start-Process -FilePath (Join-Path $bundle 'SoulSign-PC.exe') -ArgumentList '--self-test' -WindowStyle Hidden -Wait -PassThru
    if ($test.ExitCode -ne 0) { throw 'Portable runtime self-test failed.' }
    Copy-Item -LiteralPath 'LICENSE','README-中文.txt','config.json','zsign.sha256' -Destination $bundle -Force
    Copy-Item -LiteralPath 'licenses' -Destination $bundle -Recurse -Force
    Set-Content -LiteralPath (Join-Path $bundle 'START-PC.bat') -Value "@echo off`r`nstart `"`" `"%~dp0SoulSign-PC.exe`"" -Encoding ascii
    Set-Content -LiteralPath (Join-Path $bundle 'BUILD-VERSION.txt') -Value $Version -Encoding utf8
    & $Python (Join-Path $repo 'Scripts/package-windows.py') (Join-Path $out 'SoulSign-Windows-x64') $bundle
    if ($LASTEXITCODE -ne 0) { throw 'ZIP creation failed.' }
    $zip = Join-Path $out 'SoulSign-Windows-x64.zip'
    $hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
    Set-Content -LiteralPath (Join-Path $out 'SHA256SUMS.txt') -Value "$hash  SoulSign-Windows-x64.zip" -Encoding ascii
} finally { Pop-Location }
