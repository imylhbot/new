param(
    [string]$Version = "1.3.0",
    [string]$OutputDir = ""
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path $PSScriptRoot -Parent
if (-not $OutputDir) {
    $OutputDir = Join-Path $RepoRoot "build\windows"
}
New-Item -ItemType Directory -Force $OutputDir | Out-Null

$UpstreamRepo = "https://github.com/pwnapplehat/iPASide.git"
$UpstreamCommit = "7f13ecdb8f8e2737c0a5483ea551e970b9d4d5b7"
$WorkDir = Join-Path $env:RUNNER_TEMP "soulsign-pc-$UpstreamCommit"

Write-Host "== SoulSign PC $Version =="
Write-Host "Upstream: $UpstreamRepo"
Write-Host "Pinned commit: $UpstreamCommit"

if (Test-Path $WorkDir) {
    Remove-Item $WorkDir -Recurse -Force
}

git clone --filter=blob:none --no-tags $UpstreamRepo $WorkDir
if ($LASTEXITCODE -ne 0) { throw "git clone failed" }

git -C $WorkDir checkout --detach $UpstreamCommit
if ($LASTEXITCODE -ne 0) { throw "git checkout failed" }

$ActualCommit = (git -C $WorkDir rev-parse HEAD).Trim()
if ($ActualCommit -ne $UpstreamCommit) {
    throw "Unexpected iPASide commit: $ActualCommit"
}

function Replace-Literal {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Old,
        [Parameter(Mandatory=$true)][string]$New
    )

    $text = [System.IO.File]::ReadAllText($Path)
    if (-not $text.Contains($Old)) {
        throw "Expected text was not found in $Path : $Old"
    }
    $text = $text.Replace($Old, $New)
    [System.IO.File]::WriteAllText($Path, $text, (New-Object System.Text.UTF8Encoding($false)))
}

function Replace-Regex {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Pattern,
        [Parameter(Mandatory=$true)][string]$Replacement
    )

    $text = [System.IO.File]::ReadAllText($Path)
    $updated = [regex]::Replace($text, $Pattern, $Replacement)
    if ($updated -eq $text) {
        throw "Expected regex did not match $Path : $Pattern"
    }
    [System.IO.File]::WriteAllText($Path, $updated, (New-Object System.Text.UTF8Encoding($false)))
}

Write-Host "== Applying SoulSign branding =="

Get-ChildItem (Join-Path $WorkDir "src\iPASide.Flutter\lib") -Recurse -File -Filter *.dart |
    ForEach-Object {
        $text = [System.IO.File]::ReadAllText($_.FullName)
        $updated = $text.Replace("iPASide", "SoulSign")
        $updated = $updated.Replace("src\SoulSign.Engine", "src\iPASide.Engine")
        $updated = $updated.Replace("'SoulSign.Engine'", "'iPASide.Engine'")
        [System.IO.File]::WriteAllText($_.FullName, $updated, (New-Object System.Text.UTF8Encoding($false)))
    }

Replace-Literal -Path (Join-Path $WorkDir "src\iPASide.Engine\ipaside_engine\paths.py") -Old 'APP_NAME = "iPASide"' -New 'APP_NAME = "SoulSign"'
Replace-Literal -Path (Join-Path $WorkDir "src\iPASide.Engine\ipaside_engine\provision.py") -Old 'CERTIFICATE_MACHINE_NAME = "iPASide"' -New 'CERTIFICATE_MACHINE_NAME = "SoulSign"'
Replace-Literal -Path (Join-Path $WorkDir "src\iPASide.Engine\ipaside_engine\signing.py") -Old 'def generate_key_and_csr(common_name: str = "iPASide")' -New 'def generate_key_and_csr(common_name: str = "SoulSign")'

Replace-Literal -Path (Join-Path $WorkDir "src\iPASide.Flutter\windows\CMakeLists.txt") -Old 'set(BINARY_NAME "iPASide")' -New 'set(BINARY_NAME "SoulSign")'

$UpdateService = Join-Path $WorkDir "src\iPASide.Flutter\lib\services\update_service.dart"
Replace-Regex -Path $UpdateService -Pattern "this\.owner = 'pwnapplehat'" -Replacement "this.owner = 'imylhbot'"
Replace-Regex -Path $UpdateService -Pattern "this\.repo = 'SoulSign'" -Replacement "this.repo = 'new'"

$AppVersion = Join-Path $WorkDir "src\iPASide.Flutter\lib\app_version.dart"
Replace-Regex -Path $AppVersion -Pattern "const String kAppVersion = '[^']+';" -Replacement "const String kAppVersion = '$Version';"

$Pubspec = Join-Path $WorkDir "src\iPASide.Flutter\pubspec.yaml"
Replace-Regex -Path $Pubspec -Pattern "(?m)^version:\s*[^\r\n]+" -Replacement "version: $Version+1"

$BuildInstaller = Join-Path $WorkDir "packaging\build-installer.ps1"
Replace-Literal -Path $BuildInstaller -Old 'iPASide.exe' -New 'SoulSign.exe'
Replace-Literal -Path $BuildInstaller -Old 'iPASide-Setup-' -New 'SoulSign-Setup-'

$Iss = Join-Path $WorkDir "packaging\iPASide.iss"
Replace-Regex -Path $Iss -Pattern '#define AppName "iPASide"' -Replacement '#define AppName "SoulSign"'
Replace-Regex -Path $Iss -Pattern '#define AppPublisher "iPASide Contributors"' -Replacement '#define AppPublisher "SoulSign"'
Replace-Regex -Path $Iss -Pattern '#define AppExe "iPASide\.exe"' -Replacement '#define AppExe "SoulSign.exe"'
Replace-Regex -Path $Iss -Pattern '#define AppUrl "https://github\.com/iPASide/iPASide"' -Replacement '#define AppUrl "https://github.com/imylhbot/new"'
Replace-Regex -Path $Iss -Pattern 'OutputBaseFilename=iPASide-Setup-\{#AppVersion\}-x64' -Replacement 'OutputBaseFilename=SoulSign-Setup-{#AppVersion}-x64'
Replace-Regex -Path $Iss -Pattern 'AppMutex=iPASide\.Running\.Mutex' -Replacement 'AppMutex=SoulSign.Running.Mutex'
Replace-Regex -Path $Iss -Pattern '#define AppId "\{9F1C2D3E-4B5A-46C7-8E9F-A0B1C2D3E4F5\}"' -Replacement '#define AppId "{D6B6CE90-7C8A-4D2D-A7E0-5C5DA1B9F130}"'

Write-Host "== Applying SoulSign icon =="
$IconSource = Join-Path $RepoRoot "Seal\Resources\Assets.xcassets\AppIcon.appiconset\SoulSignIcon-1024.png"
if (-not (Test-Path $IconSource)) {
    throw "SoulSign icon not found: $IconSource"
}

$BrandDir = Join-Path $WorkDir "src\iPASide.Flutter\assets\brand"
Copy-Item $IconSource (Join-Path $BrandDir "mark.png") -Force
Copy-Item $IconSource (Join-Path $BrandDir "mark-hero.png") -Force

foreach ($scale in @("1.5x", "2.0x", "3.0x")) {
    $scaleDir = Join-Path $BrandDir $scale
    if (Test-Path $scaleDir) {
        Copy-Item $IconSource (Join-Path $scaleDir "mark.png") -Force
        Copy-Item $IconSource (Join-Path $scaleDir "mark-hero.png") -Force
    }
}

Copy-Item $IconSource (Join-Path $WorkDir "packaging\brand\logo.png") -Force

$IconTarget = Join-Path $WorkDir "src\iPASide.Flutter\windows\runner\resources\app_icon.ico"
$env:SOULSIGN_ICON_SOURCE = $IconSource
$env:SOULSIGN_ICON_TARGET = $IconTarget
python -c "import os; from PIL import Image; src=os.environ['SOULSIGN_ICON_SOURCE']; dst=os.environ['SOULSIGN_ICON_TARGET']; im=Image.open(src).convert('RGBA'); im.save(dst, format='ICO', sizes=[(16,16),(24,24),(32,32),(48,48),(64,64),(128,128),(256,256)])"
if ($LASTEXITCODE -ne 0) { throw "ICO generation failed" }

Write-Host "== Building SoulSign PC =="

$Zsign = Join-Path $WorkDir "src\iPASide.Engine\ipaside_engine\vendor\zsign.exe"
if (-not (Test-Path $Zsign)) {
    Write-Host "== Building zsign for SoulSign PC =="
    $Bash = "C:\msys64\usr\bin\bash.exe"
    if (-not (Test-Path $Bash)) {
        throw "MSYS2 bash was not found at $Bash"
    }
    $env:MSYSTEM = "MINGW64"
    # Inherit the working directory directly. Never parse a login shell's stdout
    # as a path: first-run MSYS2 profile messages can precede cygpath's output.
    Push-Location -LiteralPath $WorkDir
    try {
        & $Bash --noprofile --norc ./tools/zsign/build-zsign.sh
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path $Zsign)) {
            throw "zsign build failed ($LASTEXITCODE)"
        }
    }
    finally {
        Pop-Location
    }
}

Push-Location $WorkDir
try {
    & ".\packaging\build-installer.ps1" -Version $Version -Python python
    if ($LASTEXITCODE -ne 0) {
        throw "Windows installer build failed ($LASTEXITCODE)"
    }
}
finally {
    Pop-Location
}

$Installer = Join-Path $WorkDir "dist\installer\SoulSign-Setup-$Version-x64.exe"
if (-not (Test-Path $Installer)) {
    throw "SoulSign Windows installer was not produced: $Installer"
}

Write-Host "== Packaging release assets =="

$ReleaseRoot = Join-Path $OutputDir "SoulSign-Windows-x64"
if (Test-Path $ReleaseRoot) {
    Remove-Item $ReleaseRoot -Recurse -Force
}
New-Item -ItemType Directory -Force $ReleaseRoot | Out-Null

$InstallerName = "SoulSign-Setup-$Version-x64.exe"
Copy-Item $Installer (Join-Path $ReleaseRoot $InstallerName) -Force
Copy-Item (Join-Path $WorkDir "LICENSE") (Join-Path $ReleaseRoot "THIRD_PARTY_iPASide_LICENSE.txt") -Force

$Readme = @"
SoulSign PC $Version
====================

Windows 10/11 x64

Purpose:
- Sign and install IPA files to your own iPhone/iPad using your own Apple ID.
- USB / Wi-Fi device discovery.
- Apple ID + 2FA sign-in.
- Multiple Apple IDs.
- Automatic provisioning, IPA signing and installation.
- One-click refresh and background refresh for expiring free-account signatures.
- Pairing-file tools for the SoulSign iOS workflow.

Before first use:
1. Install Apple's Apple Devices app from Microsoft Store, or iTunes.
2. Connect the iPhone with USB, unlock it, and tap Trust.
3. Run $InstallerName.
4. Add an Apple ID, choose an IPA, then choose Sign / Install.

Security:
- Apple ID authentication is performed locally against Apple services.
- Do not share your Apple ID password, session data, certificates or pairing records.
- Use only IPA files you are authorized to install.

SoulSign PC's Windows sideloading core is built from the MIT-licensed iPASide
project pinned at commit $UpstreamCommit. The original MIT license is included.

Project:
https://github.com/imylhbot/new
"@
Set-Content -Path (Join-Path $ReleaseRoot "README-Windows.txt") -Value $Readme -Encoding UTF8

$ZipPath = Join-Path $OutputDir "SoulSign-Windows-x64.zip"
if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
Compress-Archive -Path (Join-Path $ReleaseRoot "*") -DestinationPath $ZipPath -CompressionLevel Optimal

$DirectInstaller = Join-Path $OutputDir $InstallerName
Copy-Item $Installer $DirectInstaller -Force

$InstallerHash = (Get-FileHash $DirectInstaller -Algorithm SHA256).Hash.ToLowerInvariant()
$ZipHash = (Get-FileHash $ZipPath -Algorithm SHA256).Hash.ToLowerInvariant()

$Sums = @(
    "$InstallerHash  $InstallerName",
    "$ZipHash  SoulSign-Windows-x64.zip"
)
Set-Content -Path (Join-Path $OutputDir "SHA256SUMS.txt") -Value $Sums -Encoding ascii

Write-Host "Windows installer -> $DirectInstaller"
Write-Host "Windows package   -> $ZipPath"
Write-Host "Checksums         -> $(Join-Path $OutputDir 'SHA256SUMS.txt')"
