$srcFile = Join-Path $PSScriptRoot "setup_dev_env.ps1"
if (-not (Test-Path $srcFile)) {
    Write-Host "ERROR: setup_dev_env.ps1 not found!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
$bytes = [System.IO.File]::ReadAllBytes($srcFile)
# 剥离已存在的 UTF-8 BOM (0xEF,0xBB,0xBF)，避免 decode 时重复添加
$utf8Bom = [System.Text.Encoding]::UTF8.GetPreamble()
if ($bytes.Length -ge $utf8Bom.Length -and $bytes[0] -eq $utf8Bom[0] -and $bytes[1] -eq $utf8Bom[1] -and $bytes[2] -eq $utf8Bom[2]) {
    $bytes = $bytes[$utf8Bom.Length..($bytes.Length - 1)]
}
$b64 = [Convert]::ToBase64String($bytes)
$b64File = Join-Path $PSScriptRoot "b64.txt"
$b64 | Out-File -FilePath $b64File -Encoding ASCII
Write-Host "OK: $($b64.Length) chars written to b64.txt"