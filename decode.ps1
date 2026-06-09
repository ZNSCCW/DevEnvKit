# 解码脚本：在目标主机上运行，将 b64.txt 还原为 setup_dev_env.ps1
$scriptPath = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
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

# 完整性校验: 验证文件已正确写入
if (-not (Test-Path $outFile)) {
    Write-Host "FAILED: Unable to write setup_dev_env.ps1 (check disk space/permissions)." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
$writtenBytes = (Get-Item $outFile).Length
if ($writtenBytes -ne $bytes.Length) {
    Write-Host "FAILED: File size mismatch (expected $($bytes.Length) bytes, got $writtenBytes bytes)." -ForegroundColor Red
    Write-Host "The output file may be corrupted. Please retry." -ForegroundColor Red
    Remove-Item $outFile -Force -ErrorAction SilentlyContinue
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "DONE! setup_dev_env.ps1 restored ($($bytes.Length) bytes)" -ForegroundColor Green
Write-Host ""
Write-Host "Now double-click launch.bat or 启动配置工具.bat to run the tool." -ForegroundColor Yellow
Read-Host "Press Enter to exit"
