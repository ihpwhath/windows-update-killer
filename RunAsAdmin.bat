@echo off
net session >nul 2>&1
if %errorlevel% == 0 goto :run
powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
exit /b
:run
cls
echo ================================================
echo   Disable Windows Update (Admin Mode)
echo ================================================
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0Disable-WindowsUpdate.ps1"
echo.
echo Done. Press any key to close.
pause >nul
