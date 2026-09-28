@echo off
chcp 65001 >nul
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Scripts\clean-build.ps1"
set "RESULT=%ERRORLEVEL%"
pause
exit /b %RESULT%
