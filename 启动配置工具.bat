@echo off
chcp 65001 >nul 2>&1
title 开发环境一键配置工具 - 启动器
cd /d "%~dp0"

:: Locate PowerShell executable (try multiple paths)
set "PS_EXE="
for %%p in (
    "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
    "%SystemRoot%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe"
    "powershell.exe"
) do (
    if exist %%p (
        if not defined PS_EXE set "PS_EXE=%%~p"
    )
)

if not defined PS_EXE (
    echo.
    echo  [X] PowerShell executable not found.
    echo  [X] Please install PowerShell and try again.
    pause >nul
    exit /b 1
)

:: b64.txt 编码传输机制已移除（v1.4+），脚本直接以 UTF-8 保存
:: 无需解码，直接运行 setup_dev_env.ps1

echo.
echo   正在启动 PowerShell 脚本...
echo   如需管理员权限，请右键选择 "以管理员身份运行" 本文件
echo.

%PS_EXE% -ExecutionPolicy Bypass -NoProfile -File "%~dp0setup_dev_env.ps1"

pause
