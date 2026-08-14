@echo off
chcp 65001 >nul 2>&1
title DevEnvKit 图形界面 - 启动器
cd /d "%~dp0"

if not exist "%~dp0devkit_gui.ps1" (
    echo  [X] 未找到 devkit_gui.ps1
    pause >nul
    exit /b 1
)

echo.
echo   正在启动 DevEnvKit 图形界面...
echo   如需管理员权限，请右键选择 "以管理员身份运行" 本文件
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0devkit_gui.ps1"

if errorlevel 1 (
    echo.
    echo  [X] 图形界面启动失败，可尝试控制台版: 启动配置工具.bat
    pause >nul
)
