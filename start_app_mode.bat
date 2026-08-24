@echo off
setlocal
cd /d "%~dp0"

set "FILE_PATH=%~dp0desk_clock.html"
start msedge.exe --app="file:///%FILE_PATH:\=/%" --window-size=350,350
exit /b 0
