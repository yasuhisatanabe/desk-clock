@echo off
REM Desk Clock - YClock風デスクトップ時計
REM PowerShell + WPF版を起動します

setlocal
cd /d "%~dp0"

REM PowerShellでSTAモードかつBypassで起動
start "" powershell -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%~dp0desk_clock.ps1"
exit /b 0
