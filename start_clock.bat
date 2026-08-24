@echo off
setlocal
cd /d "%~dp0"

set "PS_PATH=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS_PATH%" set "PS_PATH=powershell.exe"

start "" "%PS_PATH%" -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%~dp0desk_clock.ps1"
exit /b 0
