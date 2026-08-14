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
echo   Install / Uninstall / Switch need Administrator:
echo   right-click this .bat - Run as administrator
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0devkit_gui.ps1"

if errorlevel 1 (
    echo.
    echo  [X] GUI launch failed.
    pause >nul
)
