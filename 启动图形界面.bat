@echo off
chcp 65001 >nul 2>&1
title DevEnvKit GUI v2.0
cd /d "%~dp0"

if not exist "%~dp0devkit_gui.ps1" (
    echo.
    echo  [X] devkit_gui.ps1 not found.
    pause >nul
    exit /b 1
)

rem Check admin: uninstall/install and env-var writes need elevation
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator privileges (UAC)...
    powershell -NoProfile -Command "Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','%~dp0devkit_gui.ps1' -Verb RunAs"
    exit /b
)

echo.
echo   Starting DevEnvKit GUI (Administrator)...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0devkit_gui.ps1"

if errorlevel 1 (
    echo.
    echo  [X] GUI launch failed. Try console version: 启动配置工具.bat
    pause >nul
)
