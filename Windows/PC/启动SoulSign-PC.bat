@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"
if exist "%~dp0portable\SoulSign-PC.exe" (
  start "" "%~dp0portable\SoulSign-PC.exe" %*
  exit /b 0
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\bootstrap.ps1" -Ipa "%~1"
if errorlevel 1 pause
