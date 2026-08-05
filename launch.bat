@echo off
cd /d "%~dp0"

:: Check if setup_dev_env.ps1 exists, if not, run decode first
if not exist "setup_dev_env.ps1" (
    echo.
    echo  [!] setup_dev_env.ps1 not found.
    echo  [>] Running decode.ps1 to restore from b64.txt...
    powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0decode.ps1"
    if errorlevel 1 (
        echo  [X] Decode failed. Press any key to exit.
        pause >nul
        exit /b 1
    )
    echo.
)

echo  ============================================
echo   Dev Environment Setup Tool v1.1
echo   Run as Administrator for best results!
echo  ============================================
echo.

powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0setup_dev_env.ps1"

pause