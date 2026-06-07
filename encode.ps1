$srcFile = Join-Path $PSScriptRoot "setup_dev_env.ps1"
if (-not (Test-Path $srcFile)) {
    Write-Host "ERROR: setup_dev_env.ps1 not found!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
$bytes = [System.IO.File]::ReadAllBytes($srcFile)
$b64 = [Convert]::ToBase64String($bytes)
$b64File = Join-Path $PSScriptRoot "b64.txt"
$b64 | Out-File -FilePath $b64File -Encoding ASCII
Write-Host "OK: $($b64.Length) chars written to b64.txt"