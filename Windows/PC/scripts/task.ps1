param([string]$Executable, [string]$Entry = '', [switch]$Remove)
$ErrorActionPreference = 'Stop'
$taskName = 'SoulSign-PC-' + [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
if ($Remove) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    exit 0
}
if (-not (Test-Path -LiteralPath $Executable)) { throw 'Python/executable is missing' }
$arguments = '--background'
if ($Entry) { $arguments = '"' + $Entry + '" --background' }
$action = New-ScheduledTaskAction -Execute $Executable -Argument $arguments
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(2) -RepetitionInterval (New-TimeSpan -Hours 1)
$principal = New-ScheduledTaskPrincipal -UserId ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 1) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
