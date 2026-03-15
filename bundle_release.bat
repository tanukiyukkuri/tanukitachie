@echo off
setlocal
chcp 65001 >nul

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0bundle_release_windows.ps1" %*
set EXIT_CODE=%errorlevel%

if not "%EXIT_CODE%"=="0" (
  echo.
  echo bundle_release.bat failed with exit code %EXIT_CODE%.
  echo Press any key to close.
  pause >nul
)

exit /b %EXIT_CODE%
