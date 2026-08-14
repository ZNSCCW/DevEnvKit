# ============================================================
#  DevEnvKit 打包脚本：ps2exe → DevEnvKit.exe + 自签名证书签名
#  用法:
#    .\build.ps1                 # 打包（需要已装 ps2exe 模块）
#    .\build.ps1 -InstallPs2Exe  # 自动安装 ps2exe 后打包（需联网）
# ============================================================
[CmdletBinding()]
param([switch]$InstallPs2Exe)
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

Write-Host "`n  ═══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "    DevEnvKit 打包 (ps2exe + 自签名)" -ForegroundColor Cyan
Write-Host "  ═══════════════════════════════════════════`n" -ForegroundColor Cyan

# ---- 1. 检查 ps2exe 模块 ----
$ps2exeCmd = Get-Command ps2exe -ErrorAction SilentlyContinue
if (-not $ps2exeCmd) {
    if ($InstallPs2Exe) {
        Write-Host "安装 ps2exe 模块 (CurrentUser)..." -ForegroundColor Yellow
        Install-Module -Name ps2exe -Scope CurrentUser -Force
        Import-Module ps2exe -Force
        $ps2exeCmd = Get-Command ps2exe -ErrorAction SilentlyContinue
    }
    if (-not $ps2exeCmd) {
        Write-Host "  ❌ 未找到 ps2exe 模块" -ForegroundColor Red
        Write-Host "     安装: Install-Module -Name ps2exe -Scope CurrentUser -Force"
        Write-Host "     或加参数: .\build.ps1 -InstallPs2Exe"
        exit 1
    }
}
Write-Host "  ✅ ps2exe 可用: $($ps2exeCmd.Source)" -ForegroundColor Green

# ---- 2. 打包 ----
$out = Join-Path $root "DevEnvKit.exe"
$src = Join-Path $root "devkit_gui.ps1"
if (-not (Test-Path $src)) { Write-Host "  ❌ 未找到 devkit_gui.ps1"; exit 1 }
if (Test-Path $out) { Remove-Item $out -Force }

Write-Host "打包: devkit_gui.ps1 → DevEnvKit.exe (-noConsole)..." -ForegroundColor White
# 注意：故意不用 -encrypt/-zip（明文打包更干净，加壳/加密反而增加杀软启发式误报）
ps2exe -inputFile $src -outputFile $out -noConsole -title "DevEnvKit" -description "DevEnvKit 开发环境管理器"
if (-not (Test-Path $out)) { Write-Host "  ❌ 打包失败"; exit 1 }
Write-Host "  ✅ exe 已生成 ($([Math]::Round((Get-Item $out).Length / 1MB, 2)) MB)" -ForegroundColor Green

# ---- 3. 自签名证书（复用已有的 DevEnvKit 证书，否则新建） ----
$cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert -ErrorAction SilentlyContinue |
    Where-Object { $_.Subject -match "DevEnvKit" } | Select-Object -First 1
if (-not $cert) {
    Write-Host "生成自签名代码签名证书 (CN=DevEnvKit)..." -ForegroundColor Yellow
    $cert = New-SelfSignedCertificate -Type CodeSigningCert -Subject "CN=DevEnvKit" `
        -CertStoreLocation Cert:\CurrentUser\My -KeyExportPolicy Exportable
}
Write-Host "签名..." -ForegroundColor White
$ts = "http://timestamp.digicert.com"
try {
    $null = Set-AuthenticodeSignature -Certificate $cert -FilePath $out -TimestampServer $ts
    Write-Host "  ✅ 签名完成（含时间戳）" -ForegroundColor Green
} catch {
    Write-Host "  ⚡ 时间戳失败（可能无外网），跳过时间戳" -ForegroundColor Yellow
    $null = Set-AuthenticodeSignature -Certificate $cert -FilePath $out
}

# ---- 4. 校验 ----
$sig = Get-AuthenticodeSignature -FilePath $out
$hash = Get-FileHash $out -Algorithm SHA256
Write-Host "`n  ═══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  打包结果" -ForegroundColor Cyan
Write-Host "  ═══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  签名状态 : $($sig.Status)" -ForegroundColor $(if ($sig.Status -eq 'Valid') { "Green" } else { "Yellow" })
Write-Host "  文件路径 : $out"
Write-Host "  大小     : $([Math]::Round((Get-Item $out).Length / 1MB, 2)) MB"
Write-Host "  SHA256   : $($hash.Hash)"
Write-Host "`n  ⚠️  防拦截说明（详见 README）：" -ForegroundColor Yellow
Write-Host "    · Defender SmartScreen 弹窗: 更多信息 → 仍要运行"
Write-Host "    · 提交微软申诉: https://www.microsoft.com/en-us/wdsi/filesubmission"
Write-Host "    · 国内杀软误报: 加白/提交 360、火绒申诉"
Write-Host "    · 零拦截方案: 直接跑 devkit_gui.ps1（源码分发）"
Write-Host ""
