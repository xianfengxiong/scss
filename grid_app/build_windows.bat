@echo off
rem One-click Windows build + package for SCSS Survey.
rem Double-click this file. Logic lives in build_windows.ps1 (UTF-8, Chinese messages).
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_windows.ps1" %*
set RC=%ERRORLEVEL%
echo.
if not "%RC%"=="0" echo Build failed (exit code %RC%). See messages above.
pause
exit /b %RC%
