@echo off
setlocal
cd /d "%~dp0"

echo ========================================
echo   Desk Clock - Debug Launcher
echo ========================================
echo.

set "PS_PATH=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS_PATH%" set "PS_PATH=powershell.exe"

echo Launching PowerShell script...
"%PS_PATH%" -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0desk_clock.ps1"

echo.
echo ========================================
echo Script finished with exit code: %ERRORLEVEL%
echo ========================================
pause
