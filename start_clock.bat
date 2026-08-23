@echo off
REM Desk Clock - YClock風デスクトップ時計
REM PowerShell + WPF版をインストール不要で起動します

cd /d "%~dp0"
start "" powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0desk_clock.ps1"
