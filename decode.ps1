# 解码脚本：在目标主机上运行，将 b64.txt 还原为 setup_dev_env.ps1
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$b64File = Join-Path $scriptPath "b64.txt"
$outFile = Join-Path $scriptPath "setup_dev_env.ps1"

if (-not (Test-Path $b64File)) {
    Write-Host "ERROR: b64.txt not found! Place it in the same directory." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "[1/2] Reading base64 from b64.txt..." -ForegroundColor Cyan
$b64 = Get-Content $b64File -Raw

Write-Host "[2/2] Decoding to setup_dev_env.ps1..." -ForegroundColor Cyan
$bytes = [Convert]::FromBase64String($b64)
[System.IO.File]::WriteAllBytes($outFile, $bytes)

Write-Host "DONE! setup_dev_env.ps1 restored ($($bytes.Length) bytes)" -ForegroundColor Green
Write-Host ""
Write-Host "Now double-click launch.bat to run the tool." -ForegroundColor Yellow
Read-Host "Press Enter to exit"