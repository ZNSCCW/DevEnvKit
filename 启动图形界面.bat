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

echo.
echo   Starting DevEnvKit GUI...
echo   Run as Administrator if install needs elevated permission.
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0devkit_gui.ps1"

if errorlevel 1 (
    echo.
    echo  [X] GUI launch failed. Try console version: 启动配置工具.bat
    pause >nul
)
