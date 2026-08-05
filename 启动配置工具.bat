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

:: b64.txt 是纯 ASCII 编码，不受传输损坏影响
:: 每次启动都从 b64.txt 还原，确保文件编码正确
if exist "b64.txt" (
    if exist "decode.ps1" (
        echo.
        echo  [>] 正在从 b64.txt 还原 setup_dev_env.ps1 (确保编码正确)
        %PS_EXE% -ExecutionPolicy Bypass -NoProfile -File "%~dp0decode.ps1"
        if errorlevel 1 (
            echo  [X] 解码失败，按任意键退出。
            pause >nul
            exit /b 1
        )
        echo.
    )
)

echo.
echo   正在启动 PowerShell 脚本...
echo   如需管理员权限，请右键选择 "以管理员身份运行" 本文件
echo.

%PS_EXE% -ExecutionPolicy Bypass -NoProfile -File "%~dp0setup_dev_env.ps1"

pause
