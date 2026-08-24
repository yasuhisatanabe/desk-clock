@echo off
REM Desk Clock - デバッグ起動用バッチ
REM エラーがある場合に画面に表示して一時停止します

cd /d "%~dp0"
echo [Desk Clock 起動テスト]
powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0desk_clock.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo 起動時にエラーが発生しました。上記のエラーメッセージをご確認ください。
)
pause
