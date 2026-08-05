@echo off
chcp 65001 >nul
title 开发环境一键配置工具 - 启动器
cd /d "%~dp0"

echo.
echo   正在启动 PowerShell 脚本...
echo   如需管理员权限，请右键选择 "以管理员身份运行" 本文件
echo.

powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0setup_dev_env.ps1"

pause