param([switch]$Preview)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
if (-not (Test-Path -LiteralPath (Join-Path $root 'project.yml')) -or -not (Test-Path -LiteralPath (Join-Path $root 'Windows\PC\src\soulsign.py'))) { throw 'Not a complete SoulSign source folder.' }
$names = @('build','dist','release-ios','release-source','release-assets','Windows\PC\.venv','Windows\PC\build','Windows\PC\dist','Windows\PC\tests\scratch','Vendor\Minimuxer\RustBridge\target')
foreach ($name in $names) {
    $target = [IO.Path]::GetFullPath((Join-Path $root $name))
    if (-not $target.StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe cleanup target.' }
    $ancestor = $target
    while ($ancestor -ne $root) {
        if (Test-Path -LiteralPath $ancestor) {
            if ((Get-Item -LiteralPath $ancestor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Refusing junction/symlink: $ancestor" }
        }
        $ancestor = Split-Path -Parent $ancestor
    }
    if (Test-Path -LiteralPath $target) {
        if (Get-ChildItem -LiteralPath $target -Force -Recurse | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }) { throw "Reparse point inside $target" }
        Write-Host "Clean: $target"
        if (-not $Preview) { Remove-Item -LiteralPath $target -Recurse -Force }
    }
}
Write-Host 'Done. Accounts, pairing keys, portable, Git history and upload backups preserved.'
