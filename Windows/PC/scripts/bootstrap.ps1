param([switch]$InstallOnly, [switch]$Build, [string]$Ipa = '')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $root
if (-not [Environment]::Is64BitOperatingSystem) { throw 'Windows x64 is required.' }
$python = Join-Path $root '.venv\Scripts\python.exe'
function Test-PythonRuntime([string]$Executable, [string]$Prefix = '') {
    # PowerShell 5.1 turns native stderr into a terminating error under Stop.
    # Capture both streams outside PowerShell and decide using the exit code.
    $start = New-Object System.Diagnostics.ProcessStartInfo
    $start.FileName = $Executable
    $start.Arguments = $Prefix + ' -c "import sys,struct,tkinter; sys.exit(0 if (3,11) <= sys.version_info[:2] <= (3,12) and struct.calcsize(''P'')==8 else 1)"'
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardError = $true
    $start.RedirectStandardOutput = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $start
    try {
        [void]$process.Start()
        $out = $process.StandardOutput.ReadToEndAsync()
        $err = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(15000)) { $process.Kill(); return $false }
        [void]$out.Result; [void]$err.Result
        return $process.ExitCode -eq 0
    } catch { return $false } finally { $process.Dispose() }
}
if (-not (Test-Path -LiteralPath $python)) {
    $candidates = @(@('py','-3.12'), @('py','-3.11'), @('python'))
    $found = $false
    foreach ($candidate in $candidates) {
        if (-not (Get-Command $candidate[0] -ErrorAction SilentlyContinue)) { continue }
        $prefix = @(); if ($candidate.Length -gt 1) { $prefix = @($candidate[1]) }
        if (Test-PythonRuntime -Executable (Get-Command $candidate[0]).Source -Prefix ($prefix -join ' ')) {
            & $candidate[0] @prefix -m venv .venv
            if ($LASTEXITCODE -ne 0) { throw 'venv creation failed. Repair Python including pip and Tcl/Tk.' }
            $found = $true; break
        }
    }
    if (-not $found) {
        $portable = Join-Path $root 'portable\SoulSign-PC.exe'
        if ((Test-Path -LiteralPath $portable) -and -not $Build) {
            Write-Host '未检测到 Python 3.11/3.12。便携版已自带运行环境，无需安装依赖。'
            if (-not $InstallOnly) {
                if ($Ipa) { & $portable $Ipa } else { & $portable }
            }
            exit 0
        }
        throw '源码构建需要 Python 3.11/3.12 x64（含 pip 和 Tcl/Tk）；日常使用请直接启动便携 EXE。'
    }
}
if (-not (Test-PythonRuntime -Executable $python)) { throw 'The .venv Python is incompatible. Rename .venv and retry.' }
$requirements = Join-Path $root 'requirements.txt'
$hash = (Get-FileHash -LiteralPath $requirements -Algorithm SHA256).Hash
$marker = Join-Path $root '.venv\soulsign-deps.txt'
if ($InstallOnly -or -not (Test-Path -LiteralPath $marker) -or (Get-Content -LiteralPath $marker -Raw).Trim() -ne $hash) {
    & $python -m pip install --disable-pip-version-check --prefer-binary -r $requirements
    if ($LASTEXITCODE -ne 0) { throw 'Dependency installation failed. Check internet/proxy; run this script again.' }
    & $python (Join-Path $root 'scripts\verify_runtime.py')
    if ($LASTEXITCODE -ne 0) { throw 'Runtime verification failed.' }
    Set-Content -LiteralPath $marker -Value $hash -Encoding ascii
}
if ($Build) {
    & $python -m pip install -r requirements-build.txt
    if ($LASTEXITCODE -ne 0) { throw 'Build dependencies failed.' }
    & $python -m PyInstaller --noconfirm SoulSign-PC.spec
    if ($LASTEXITCODE -ne 0) { throw 'PyInstaller failed.' }
    Write-Host 'Output: dist\SoulSign-PC\SoulSign-PC.exe'
    exit 0
}
if ($InstallOnly) { Write-Host 'SoulSign dependencies are ready.'; exit 0 }
$arguments = @((Join-Path $root 'src\soulsign.py'))
if ($Ipa) { $arguments += $Ipa }
& $python @arguments
exit $LASTEXITCODE
