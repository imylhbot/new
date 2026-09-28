$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
if (-not (Test-Path -LiteralPath (Join-Path $root 'SOURCE-MANIFEST.txt'))) { throw 'Extract the complete package first.' }
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'Install Git for Windows first.' }
$destination = Join-Path $root ('.upload-work\' + [guid]::NewGuid().ToString('N'))
$backups = Join-Path $root '.upload-backups'
New-Item -ItemType Directory -Force -Path $destination,$backups | Out-Null
function Run-Git([string[]]$GitArgs) {
    & git -c http.sslBackend=openssl -C $destination @GitArgs
    if ($LASTEXITCODE -ne 0) { throw "Git failed: $($GitArgs[0]); no force push attempted." }
}
Run-Git @('clone','--branch','main','https://github.com/imylhbot/new.git','.')
$backup = Join-Path $backups ('before-upload-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.bundle')
Run-Git @('bundle','create',$backup,'--all')
# Checkout line-ending conversion can make a fresh clone appear modified.
# Force removal ONLY within this new temporary clone, after its history backup.
$temporaryRoot = [IO.Path]::GetFullPath((Join-Path $root '.upload-work')) + '\'
$resolvedDestination = (Resolve-Path -LiteralPath $destination).Path
if (-not $resolvedDestination.StartsWith($temporaryRoot, [StringComparison]::OrdinalIgnoreCase) -or
    -not (Test-Path -LiteralPath (Join-Path $resolvedDestination '.git') -PathType Container) -or
    -not (Test-Path -LiteralPath $backup -PathType Leaf)) { throw 'Temporary clone/backup validation failed.' }
Run-Git @('rm','-r','-f','--ignore-unmatch','--','.')
foreach ($relative in Get-Content -LiteralPath (Join-Path $root 'SOURCE-MANIFEST.txt') -Encoding UTF8) {
    if (-not $relative) { continue }
    if ($relative -match '(^|[\\/])\.git([\\/]|$)') { throw 'Invalid manifest entry.' }
    $source = [IO.Path]::GetFullPath((Join-Path $root $relative))
    $target = [IO.Path]::GetFullPath((Join-Path $destination $relative))
    if (-not $source.StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase) -or
        -not $target.StartsWith($destination + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Manifest path escapes package.' }
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Missing source file: $relative" }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
    Copy-Item -LiteralPath $source -Destination $target -Force
}
Run-Git @('add','--all')
Run-Git @('diff','--cached','--stat')
& git -C $destination diff --cached --quiet
if ($LASTEXITCODE -eq 0) { Write-Host 'No source changes to upload.'; exit 0 }
Write-Host "Backup: $backup"
Write-Host 'Target: https://github.com/imylhbot/new (main). Replace tracked source; preserve history/Releases/Issues.'
if ((Read-Host 'Type UPLOAD to commit and push the changes shown above') -cne 'UPLOAD') { Write-Host 'Cancelled before remote changes.'; exit 0 }
Run-Git @('config','user.name','imylhbot')
Run-Git @('config','user.email','imylhbot@users.noreply.github.com')
Run-Git @('commit','-m','Integrate Python PC, separate release assets, handle Apple 503')
Run-Git @('push','origin','HEAD:main')
Write-Host 'Uploaded. Actions > SoulSign Manual Release > Run workflow on main. Do not re-run an old job.'
