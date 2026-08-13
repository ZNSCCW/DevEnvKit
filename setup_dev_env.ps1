<#
============================================================================
  🛠️  开发环境一键配置工具  v1.6
  支持: Python / Java / C/C++ / Node.js / Git / Docker / Maven / MySQL 等
  适用于 Windows 10/11 (使用 winget 包管理器)
============================================================================
#>

# 要求管理员权限运行
if (-NOT ([System.Security.Principal.WindowsPrincipal] [System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "`n  [警告] 建议以管理员身份运行此脚本，否则部分安装可能失败。" -ForegroundColor Yellow
    Write-Host "  是否继续以非管理员身份运行? (Y/N): " -NoNewline -ForegroundColor Yellow
    if ((Read-Host) -notmatch '^[Yy]$') { exit }
}

# 控制台编码设置
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$host.UI.RawUI.WindowTitle = "开发环境一键配置工具"

# 全局变量
# completedSteps 计数"已就绪"工具项（已安装或跳过），非"新安装数"
$script:completedSteps = 0

# ========================== 实时日志 ==========================
# 初始化实时日志文件（防崩溃丢失），日志统一输出到 logs/ 子目录
$script:baseDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$script:logDir = Join-Path $script:baseDir "logs"
if (-not (Test-Path $script:logDir)) { New-Item -ItemType Directory -Path $script:logDir -Force | Out-Null }
$script:logFilePath = Join-Path $script:logDir "install_log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
"========== 开发环境配置日志 [$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] ==========" | Out-File -FilePath $script:logFilePath -Encoding UTF8

function Write-AppendLog {
    param([string]$Message)
    $Message | Out-File -FilePath $script:logFilePath -Append -Encoding UTF8
}

# ========================== 颜色主题 ==========================
$ColorTitle   = "Cyan"
$ColorSuccess = "Green"
$ColorError   = "Red"
$ColorWarning = "Yellow"
$ColorInfo    = "White"
$ColorMenu    = "Magenta"
$ColorPrompt  = "Cyan"
$ColorStep    = "Cyan"

# ========================== 辅助函数 ==========================
function Write-Title {
    Clear-Host
    Write-Host @"

  ╔══════════════════════════════════════════════════════════════╗
  ║        🛠️   开 发 环 境 一 键 配 置 工 具   v1.6           ║
  ║   Python · Java · C/C++ · Node.js · Git · Docker · ...      ║
  ╚══════════════════════════════════════════════════════════════╝

"@
}

function Write-Step { param([string]$m); $t = Get-Date -Format "HH:mm:ss"; Write-Host "  [$t] ▶ $m" -ForegroundColor $ColorStep; Write-AppendLog "[$t] ▶ $m" }
function Write-OK   { param([string]$m, [switch]$NoCount); Write-Host "              ✅ $m" -ForegroundColor $ColorSuccess; Write-AppendLog "              ✅ $m"; if (-not $NoCount) { $script:completedSteps++ } }
function Write-Fail { param([string]$m); Write-Host "              ❌ $m" -ForegroundColor $ColorError;   Write-AppendLog "              ❌ $m" }
function Write-Warn { param([string]$m); Write-Host "              ⚠️  $m" -ForegroundColor $ColorWarning; Write-AppendLog "              ⚠️  $m" }
function Write-Info { param([string]$m); Write-Host "              ℹ️  $m" -ForegroundColor $ColorInfo; Write-AppendLog "              ℹ️  $m" }

function Test-CommandExists {
    param([string]$Command)
    try { $null = Get-Command $Command -ErrorAction Stop; return $true } catch { return $false }
}

# 获取已安装工具的版本号 (安全: 使用脚本块替代 Invoke-Expression)
function Get-InstalledVersion {
    param([scriptblock]$VersionCommand)
    try { $o = & $VersionCommand 2>&1 | Select-Object -First 1; $v = "$o".Trim(); if ([string]::IsNullOrWhiteSpace($v)) { return "未知" } else { return $v } } catch { return "未知" }
}

# 版本比对提示：已有工具 → 展示当前版本 → 询问是否重新安装
function Request-Confirmation {
    param([string]$ToolName, [string]$InstalledVersion, [string]$TargetVersionDesc)
    Write-Host ""
    Write-Warn "$ToolName 已安装 (当前版本: $InstalledVersion)"
    Write-Info "脚本将安装版本: $TargetVersionDesc"
    Write-Host "  ❓ 是否重新安装/升级? (Y=升级覆盖, N=跳过保留当前): " -NoNewline -ForegroundColor $ColorPrompt
    $userInput = Read-Host
    if ($userInput -match '^[Yy]$') { Write-Info "将重新安装/升级 $ToolName ..."; Write-AppendLog "  ❓ 用户选择: 重新安装/升级 $ToolName"; return $true }
    Write-Warn "已跳过 $ToolName (保留当前版本: $InstalledVersion)"; Write-AppendLog "  ❓ 用户选择: 跳过 $ToolName"; return $false
}

# 版本选择器：Versions = @(@{Label="..."; PackageId="..."})，返回选中的项（默认第 1 项）
function Select-Version {
    param([string]$ToolName, [array]$Versions)
    Write-Host "`n  ── 选择要安装的 $ToolName 版本 ──" -ForegroundColor $ColorMenu
    Write-AppendLog "`n  ── 选择 $ToolName 版本 ──"
    for ($i = 0; $i -lt $Versions.Count; $i++) {
        Write-Host "    [$($i + 1)]  $($Versions[$i].Label)" -ForegroundColor $ColorMenu
    }
    Write-Host "  ❓ 请输入版本编号 [1-$($Versions.Count)]，直接回车用第 1 项: " -NoNewline -ForegroundColor $ColorPrompt
    $sel = (Read-Host).Trim()
    $idx = 0
    if ($sel -match '^\d+$' -and [int]$sel -ge 1 -and [int]$sel -le $Versions.Count) { $idx = [int]$sel - 1 }
    else { Write-Warn "输入无效，默认选择第 1 项" }
    Write-Info "已选择: $($Versions[$idx].Label)"
    Write-AppendLog "  ❓ 版本选择: $($Versions[$idx].Label)"
    return $Versions[$idx]
}

# 大小自动换单位：B → KB → MB → GB
function Format-Size {
    param([double]$Bytes)
    if ($Bytes -lt 1KB) { return "$([math]::Round($Bytes)) B" }
    elseif ($Bytes -lt 1MB) { return "$([math]::Round($Bytes / 1KB, 1)) KB" }
    elseif ($Bytes -lt 1GB) { return "$([math]::Round($Bytes / 1MB, 1)) MB" }
    else { return "$([math]::Round($Bytes / 1GB, 2)) GB" }
}

# 流式下载 + 实时进度条 + 断点续传 + 代理感知
# - 进度条：自动换单位、显示总大小/百分比/速度（Write-Progress 原生，不刷屏）
# - 断点续传：本地有半成品时发 Range 请求；服务器返回 206 且 Content-Range 起始匹配则续写，否则删掉全量重下
# - 代理感知：读取 HTTPS_PROXY / HTTP_PROXY / ALL_PROXY 环境变量（curl 生态习惯）；未设置则用系统代理
# - 停滞检测：15s 无数据判定卡死；失败自动重试（默认 2 次），失败保留半成品供下次续传
function Download-WithProgress {
    param(
        [string]$Uri,
        [string]$OutFile,
        [string]$Activity = "下载中",
        [int]$Retries = 2,
        [int]$StallSeconds = 15
    )
    for ($attempt = 0; $attempt -le $Retries; $attempt++) {
        $client = $null; $response = $null; $stream = $null; $fs = $null
        try {
            # Windows PowerShell 5.1 默认不加载 System.Net.Http，必须显式加载（bat 启动器用的是 5.1）
            try { Add-Type -AssemblyName System.Net.Http -ErrorAction Stop } catch { }
            # 代理感知：环境变量优先（PowerShell $env: 不区分大小写，HTTPS_PROXY/https_proxy 均命中），未设置走系统代理
            $handler = [System.Net.Http.HttpClientHandler]::new()
            $proxyVar = $env:HTTPS_PROXY
            if (-not $proxyVar) { $proxyVar = $env:HTTP_PROXY }
            if (-not $proxyVar) { $proxyVar = $env:ALL_PROXY }
            if ($proxyVar) {
                try {
                    $handler.Proxy = [System.Net.WebProxy]::new($proxyVar)
                    $handler.UseProxy = $true
                    $proxyHost = $proxyVar -replace '^https?://', '' -replace '/.*$', ''
                    Write-Info "使用代理: $proxyHost"
                } catch { Write-Warn "代理配置无效，改用直连" }
            }
            $client = [System.Net.Http.HttpClient]::new($handler)
            $client.Timeout = [TimeSpan]::FromMinutes(10)

            # 断点续传：本地半成品存在则尝试 Range
            $existing = 0L
            $downloaded = 0L
            $isResume = $false
            if (Test-Path $OutFile) { $existing = (Get-Item $OutFile).Length }
            $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get, $Uri)
            if ($existing -gt 0) {
                # .NET Framework(PS 5.1) 无 RangeHeaderValue.From 静态方法，用构造器兼容写法
                $range = New-Object System.Net.Http.Headers.RangeHeaderValue
                $range.Ranges.Add((New-Object System.Net.Http.Headers.RangeItemHeaderValue([long]$existing, $null)))
                $request.Headers.Range = $range
            }
            $response = $client.SendAsync($request, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
            if ($response.StatusCode -eq [System.Net.HttpStatusCode]::PartialContent) {
                $cr = $response.Content.Headers.ContentRange
                if ($cr -and $cr.From -eq $existing) {
                    $isResume = $true; $downloaded = $existing
                    Write-Info "断点续传: 从 $(Format-Size $existing) 继续"
                } else {
                    Remove-Item $OutFile -Force -ErrorAction SilentlyContinue  # 起始不匹配，删掉全量重下
                    $downloaded = 0L
                }
            } elseif ($existing -gt 0) {
                Write-Warn "该源不支持断点续传，全量重新下载"
                Remove-Item $OutFile -Force -ErrorAction SilentlyContinue
                $downloaded = 0L
            }
            $null = $response.EnsureSuccessStatusCode()  # 防止方法返回值泄漏到输出管道

            $totalBytes = $response.Content.Headers.ContentLength
            $stream = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
            $fs = if ($isResume) {
                [System.IO.File]::Open($OutFile, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write)
            } else {
                [System.IO.File]::Create($OutFile)
            }
            $buffer = New-Object byte[] 81920
            $read = 0
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $lastProgress = [DateTime]::Now
            $lastDownloaded = $downloaded
            $name = $Uri.Split('/')[-1]
            while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                $fs.Write($buffer, 0, $read)
                $downloaded += $read
                # 停滞检测：一段时间无字节增长说明网络卡死，中断避免无限等待
                if ($downloaded -gt $lastDownloaded) { $lastDownloaded = $downloaded; $lastProgress = [DateTime]::Now }
                elseif (([DateTime]::Now - $lastProgress).TotalSeconds -gt $StallSeconds) {
                    throw "下载停滞超过 $StallSeconds 秒（无数据，疑似网络卡死）"
                }
                $pct = -1
                if ($totalBytes -gt 0) { $pct = [math]::Min(100, [math]::Round($downloaded * 100.0 / $totalBytes, 1)) }
                $status = "已下载 $(Format-Size $downloaded)"
                if ($totalBytes -gt 0) { $status += " / 共 $(Format-Size $totalBytes) ($pct%)" }
                $speed = $downloaded / [math]::Max(1, $sw.Elapsed.TotalSeconds)
                $status += "   速度 $(Format-Size $speed)/s"
                Write-Progress -Activity "$Activity ($name)" -Status $status -PercentComplete $(if ($pct -ge 0) { $pct } else { -1 })
            }
            $sw.Stop()
            Write-Progress -Activity "$Activity" -Completed
            return $true
        } catch {
            Write-Progress -Activity "$Activity" -Completed
            # 清理本次句柄；失败保留半成品文件（供下次断点续传）
            if ($fs) { try { $fs.Dispose() } catch {} }
            if ($stream) { try { $stream.Dispose() } catch {} }
            if ($response) { try { $response.Dispose() } catch {} }
            if ($client) { try { $client.Dispose() } catch {} }
            if ($attempt -lt $Retries) {
                Write-Warn "下载失败 (第 $($attempt + 1)/$($Retries + 1) 次): $($_.Exception.Message)，3 秒后重试..."
                Start-Sleep -Seconds 3
            } else {
                Write-Warn "下载失败: $($_.Exception.Message)（已保留半成品，下次运行自动断点续传）"
            }
        }
    }
    return $false
}

# winget 常见退出码说明（安装失败时给出可行动提示）
function Get-WingetExitHint {
    param([int]$Code)
    switch ($Code) {
        0x8A150014 { return "包已安装（视为成功，可跳过）" }
        0x8A150016 { return "已存在相同版本（视为成功，可跳过）" }
        0x8A150019 { return "需要同意源/包协议——脚本已带 --accept 参数，若仍失败请检查 winget 源" }
        0x8A15002F { return "需要提权——请以管理员身份重新运行本脚本" }
        0x8A15003C { return "软件源不可达——请检查网络/代理" }
        0x8A150078 { return "包被第三方托管，请检查安全提示" }
        default { return "" }
    }
}

# winget 安装 (--disable-interactivity 禁用 spinner 干扰输出)
function Invoke-WingetInstall {
    param([string]$PackageId, [string]$DisplayName)
    Write-Step "正在安装 $DisplayName ..."
    $r = winget install --id $PackageId --disable-interactivity --accept-source-agreements --accept-package-agreements 2>&1
    $code = $LASTEXITCODE
    if ($code -eq 0 -or $r -match "已安装|已找到已安装|No applicable update|already installed|Successfully installed") {
        Write-OK "$DisplayName 安装成功 (或已安装)"; return $true
    }
    elseif ($r -match "InternetOpenUrl|0x80072efd|0x80072ee7|0x80072f8f") {
        Write-Fail "$DisplayName 安装失败: 无法连接到互联网"
        Write-Info "请检查网络后重试，或到官网手动下载安装"; return $false
    }
    elseif ($r -match "No package found|找不到与输入条件匹配") {
        Write-Fail "$DisplayName 安装失败: winget 中找不到该包 (PackageId=$PackageId)"
        Write-Info "可用 'winget search $DisplayName' 查找正确包名，或到官网手动下载"; return $false
    }
    # 通用失败：解释退出码 + 给可执行建议（保证"不会装不了"的可排查性）
    Write-Fail "$DisplayName 安装失败 (退出码 0x$($code.ToString('X8')))"
    $hint = Get-WingetExitHint -Code $code
    if ($hint) { Write-Info $hint }
    Write-Info "可重试本项，或手动执行: winget install --id $PackageId"
    Write-Info "详情: $($r | Select-Object -Last 2)"
    return $false
}

# 检测 MySQL（即使不在 PATH 中也能探测）
function Test-MySqlExists {
    # 1. 先试 Get-Command（PATH 内）
    if (Test-CommandExists "mysql") { return $true }
    # 2. 探测常见安装路径
    $base = "C:\Program Files\MySQL"
    if (Test-Path $base) {
        foreach ($d in Get-ChildItem $base -Directory -Filter "MySQL Server *" -ErrorAction SilentlyContinue) {
            $bin = Join-Path $d.FullName "bin\mysql.exe"
            if (Test-Path $bin) { return $true }
        }
    }
    # 3. 探测 Program Files (x86)
    $base86 = "${env:ProgramFiles(x86)}\MySQL"
    if (Test-Path $base86) {
        foreach ($d in Get-ChildItem $base86 -Directory -Filter "MySQL Server *" -ErrorAction SilentlyContinue) {
            $bin = Join-Path $d.FullName "bin\mysql.exe"
            if (Test-Path $bin) { return $true }
        }
    }
    return $false
}

# 获取 MySQL 安装路径 bin 目录（不在 PATH 时回退）
function Get-MySqlBin {
    if (Test-CommandExists "mysql") { return "" }
    $base = "C:\Program Files\MySQL"
    if (Test-Path $base) {
        foreach ($d in Get-ChildItem $base -Directory -Filter "MySQL Server *" -ErrorAction SilentlyContinue) {
            $bin = Join-Path $d.FullName "bin"
            if (Test-Path (Join-Path $bin "mysql.exe")) { return $bin }
        }
    }
    $base86 = "${env:ProgramFiles(x86)}\MySQL"
    if (Test-Path $base86) {
        foreach ($d in Get-ChildItem $base86 -Directory -Filter "MySQL Server *" -ErrorAction SilentlyContinue) {
            $bin = Join-Path $d.FullName "bin"
            if (Test-Path (Join-Path $bin "mysql.exe")) { return $bin }
        }
    }
    return ""
}

# 检测 MSVC
function Test-MsvcExists {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vswhere) {
        $vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
        if ($vsPath) { return $true }
    }
    foreach ($d in "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC",
                   "${env:ProgramFiles}\Microsoft Visual Studio\2022\Professional\VC\Tools\MSVC",
                   "${env:ProgramFiles}\Microsoft Visual Studio\2022\Enterprise\VC\Tools\MSVC",
                   "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC",
                   "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Professional\VC\Tools\MSVC",
                   "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Enterprise\VC\Tools\MSVC") {
        if (Test-Path $d) { return $true }
    }
    return $false
}

# 刷新 PATH
function Update-Path {
    Write-AppendLog "  🔄 刷新 PATH 环境变量"
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
}

# 通用安装包装器：检测 → 确认 → 安装 → 刷新PATH (消除 switch 中的重复代码)
function Invoke-Installer {
    param([string]$ToolName, [string]$ExeName, [string]$PackageId, [string]$DisplayName, [string]$TargetDesc, [scriptblock]$VersionCmd, [string]$VerReplace)
    Write-Host "`n  ── $ToolName ──────────────────────────────────────────────" -ForegroundColor $ColorMenu
    Write-AppendLog "`n  ── $($ToolName -replace '^\S+\s*', '') ──"
    if (Test-CommandExists $ExeName) {
        $ver = Get-InstalledVersion -VersionCommand $VersionCmd
        if ($VerReplace) { $ver = $ver -replace $VerReplace, '' }
        if (-not (Request-Confirmation -ToolName $DisplayName -InstalledVersion $ver -TargetVersionDesc $TargetDesc)) {
            $script:completedSteps++; return $false
        }
    }
    $result = Invoke-WingetInstall -PackageId $PackageId -DisplayName $DisplayName
    Update-Path
    return $result
}

# 自动安装 winget (如果缺失) — 必须在所有辅助函数定义之后调用
function Install-Winget {
    Write-Host "`n  ── ⚙️ 安装 winget 包管理器 ──────────────────────────────" -ForegroundColor $ColorMenu
    Write-Step "未检测到 winget，正在自动下载安装..."
    
    $wingetUrl = "https://aka.ms/getwinget"
    $tempDir = Join-Path $env:TEMP "winget_installer"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    
    # 尝试从 GitHub Release 获取最新 winget
    try {
        Write-Info "正在获取最新 winget 版本信息..."
        $releaseApi = "https://api.github.com/repos/microsoft/winget-cli/releases/latest"
        $releaseInfo = Invoke-RestMethod -Uri $releaseApi -TimeoutSec 15 -ErrorAction Stop
        $asset = $releaseInfo.assets | Where-Object { $_.name -like "*.msixbundle" } | Select-Object -First 1
        
        if ($asset) {
            Write-Info "下载: $($asset.name) ($(Format-Size $asset.size))"
            $installerPath = Join-Path $tempDir $asset.name
            if (-not (Download-WithProgress -Uri $asset.browser_download_url -OutFile $installerPath -Activity "下载 winget")) {
                throw "winget 下载失败"
            }
            # 完整性校验: 文件存在且大小 > 1MB
            if ((-not (Test-Path $installerPath)) -or ((Get-Item $installerPath).Length -lt 1MB)) {
                throw "下载文件不完整或为空"
            }
            Write-OK "下载完成" -NoCount
            
            Write-Step "正在安装 winget ..."
            Add-AppxPackage -Path $installerPath -ErrorAction Stop
            Write-OK "winget 安装成功!" -NoCount
            
            # 刷新 PATH 并验证
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + 
                        [System.Environment]::GetEnvironmentVariable("Path", "User")
            if (Get-Command winget -ErrorAction SilentlyContinue) {
                Write-OK "winget 已就绪" -NoCount
                Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
                return $true
            }
        }
    }
    catch {
        Write-Warn "GitHub 自动下载失败: $_"
    }
    
    # 回退方案: 打开 winget 下载页面
    Write-Warn "自动安装失败，将打开 winget 下载页面..."
    Write-Host "  ❓ 是否打开 winget 下载页面? (Y/N): " -NoNewline -ForegroundColor $ColorPrompt
    if ((Read-Host) -match '^[Yy]$') {
        Write-Info "正在打开下载页面..."
        Start-Process $wingetUrl
    }
    
    Write-Host "`n  ⚠️  请手动安装 winget 后重新运行本脚本。" -ForegroundColor $ColorWarning
    Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
    return $false
}

# 主流程启动前检查 winget 是否可用
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    if (-not (Install-Winget)) {
        Write-Host "`n  按任意键退出..." -ForegroundColor Gray
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 1
    }
}

# ========================== 安装模块 ==========================

function Install-Git {
    $r = Invoke-Installer -ToolName "🔧 Git" -ExeName "git" -PackageId "Git.Git" -DisplayName "Git" `
        -TargetDesc "Git (winget 最新稳定版)" -VersionCmd { git --version } -VerReplace 'git version '
    return $r
}

function Install-Python {
    $choice = Select-Version -ToolName "Python" -Versions @(
        @{Label="Python 3.12 (推荐)"; PackageId="Python.Python.3.12"},
        @{Label="Python 3.13";        PackageId="Python.Python.3.13"},
        @{Label="Python 3.11";        PackageId="Python.Python.3.11"}
    )
    Write-Host "`n  ── 🐍 Python ($($choice.Label)) ──────────────────────────────" -ForegroundColor $ColorMenu
    Write-AppendLog "`n  ── Python ($($choice.Label)) ──"
    if (Test-CommandExists "python") {
        $ver = Get-InstalledVersion { python --version }
        if (-not (Request-Confirmation -ToolName "Python" -InstalledVersion $ver -TargetDesc $choice.Label)) {
            $script:completedSteps++; return $false
        }
    }
    $r = Invoke-WingetInstall -PackageId $choice.PackageId -DisplayName $choice.Label
    if (Test-CommandExists "pip") { Write-OK "pip 可用" -NoCount } else { Write-Warn "pip 未找到，请手动验证 Python 安装" }
    Update-Path
    return $r
}

function Install-Java {
    # 版本选择：Temurin 各版本 PackageId 均已实测存在
    $choice = Select-Version -ToolName "Java JDK" -Versions @(
        @{Label="JDK 21 (LTS, 推荐)"; PackageId="EclipseAdoptium.Temurin.21.JDK"},
        @{Label="JDK 17 (LTS)";       PackageId="EclipseAdoptium.Temurin.17.JDK"},
        @{Label="JDK 11 (LTS)";       PackageId="EclipseAdoptium.Temurin.11.JDK"},
        @{Label="JDK 8 (LTS)";        PackageId="EclipseAdoptium.Temurin.8.JDK"}
    )
    Write-Host "`n  ── ☕ Java ($($choice.Label)) ────────────────────────────────" -ForegroundColor $ColorMenu
    Write-AppendLog "`n  ── Java ($($choice.Label)) ──"
    if (Test-CommandExists "java") {
        $ver = Get-InstalledVersion { java -version 2>&1 }
        if (-not (Request-Confirmation -ToolName "Java" -InstalledVersion $ver -TargetDesc $choice.Label)) {
            $script:completedSteps++; return $false
        }
    }
    $r = Invoke-WingetInstall -PackageId $choice.PackageId -DisplayName $choice.Label
    # 设置 JAVA_HOME（搜索所有已装 Temurin JDK，取最新）
    try {
        if (-not ${env:JAVA_HOME}) {
            $latest = Get-ChildItem "C:\Program Files\Eclipse Adoptium\jdk-*" -Directory -ErrorAction SilentlyContinue |
                      Sort-Object Name -Descending | Select-Object -First 1
            if ($latest) { [System.Environment]::SetEnvironmentVariable("JAVA_HOME", $latest.FullName, "Machine"); Write-OK "JAVA_HOME 已设置为: $($latest.FullName)" -NoCount }
        }
    } catch { Write-Warn "JAVA_HOME 设置失败，请手动配置" }
    Update-Path
    return $r
}

function Install-CPP {
    Write-Host "`n  ── ⚙️  C/C++ 开发工具 ──────────────────────────────────" -ForegroundColor $ColorMenu
    Write-AppendLog "`n  ── C/C++ 开发工具 ──"
    $compilerDesc = [System.Collections.ArrayList]@()
    if (Test-CommandExists "gcc")   { $null = $compilerDesc.Add("GCC $(Get-InstalledVersion { gcc --version })") }
    if (Test-CommandExists "g++")   { $null = $compilerDesc.Add("G++ $(Get-InstalledVersion { g++ --version })") }
    if (Test-CommandExists "clang") { $null = $compilerDesc.Add("Clang $(Get-InstalledVersion { clang --version })") }
    if (Test-MsvcExists)            { $null = $compilerDesc.Add("MSVC (Visual Studio)") }
    
    $compilerFound = ($compilerDesc.Count -gt 0)
    $doCompilerInstall = $true
    $somethingInstalled = $false
    $cppCounted = $false     # 确保 Install-All 中 C/C++ 只计 1 次
    
    if ($compilerFound) {
        $cd = $compilerDesc -join "; "
        $doCompilerInstall = Request-Confirmation -ToolName "C/C++ 编译器" -InstalledVersion $cd -TargetVersionDesc "MinGW-w64 (GCC/G++)"
        if (-not $doCompilerInstall) { if (-not $cppCounted) { $script:completedSteps++; $cppCounted = $true } }
    }
    
    if ($doCompilerInstall) {
        Write-Step $(if ($compilerFound) { "正在安装/升级 MinGW-w64 (GCC/G++) ..." } else { "未检测到 C/C++ 编译器，正在安装 MinGW-w64 (GCC/G++) ..." })
        $mingwInstalled = $false
        # winget 无 niXman.mingw-w64 包（实测不存在），MSYS2 为唯一可靠方案
        foreach ($e in @(@{Id="MSYS2.MSYS2"; Name="MSYS2 (含 MinGW-w64)"})) {
            $mingwInstalled = Invoke-WingetInstall -PackageId $e.Id -DisplayName $e.Name
            if ($mingwInstalled) {
                if ($e.Id -eq "MSYS2.MSYS2") {
                    Write-Step "正在通过 pacman 安装 MinGW-w64 编译器 (GCC/G++) ..."
                    $pacman = "C:\msys64\usr\bin\pacman.exe"
                    if (Test-Path $pacman) {
                        try {
                            & $pacman -S --noconfirm --needed mingw-w64-ucrt64-gcc 2>&1 | Out-Null
                            if ($LASTEXITCODE -eq 0) {
                                Write-OK "MinGW-w64 GCC 安装成功 (UCRT64)" -NoCount
                                $mingwPaths = @("C:\msys64\ucrt64\bin", "C:\msys64\mingw64\bin")
                            } else {
                                Write-Warn "pacman 安装 GCC 返回非零，尝试 mingw64 环境..."
                                & $pacman -S --noconfirm --needed mingw-w64-x86_64-gcc 2>&1 | Out-Null
                                $mingwPaths = @("C:\msys64\mingw64\bin")
                            }
                        } catch {
                            Write-Warn "pacman 调用失败: $_"
                            $mingwPaths = @("C:\msys64\ucrt64\bin", "C:\msys64\mingw64\bin")
                        }
                    } else {
                        Write-Warn "pacman 未找到，请手动运行 MSYS2 并安装 mingw-w64-gcc"
                        $mingwPaths = @("C:\msys64\ucrt64\bin", "C:\msys64\mingw64\bin")
                    }
                    foreach ($mp in $mingwPaths) {
                        if (Test-Path (Join-Path $mp "gcc.exe")) {
                            $curPath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
                            if ($curPath -notmatch [regex]::Escape($mp)) {
                                [System.Environment]::SetEnvironmentVariable("Path", "$curPath;$mp", "Machine")
                                Write-OK "已追加 $mp 到系统 PATH" -NoCount
                            }
                        }
                    }
                }
                Update-Path; $somethingInstalled = $true; break
            }
        }
        if (-not $mingwInstalled) { Write-Warn "所有 MinGW 包 ID 均失败，请手动从 https://winlibs.com 或 https://www.msys2.org 下载安装。" }
    }
    
    # CMake
    if (Test-CommandExists "cmake") {
        $doCmake = Request-Confirmation -ToolName "CMake" -InstalledVersion (Get-InstalledVersion { cmake --version }) -TargetVersionDesc "CMake (winget 最新版)"
        if ($doCmake) { if (Invoke-WingetInstall -PackageId "Kitware.CMake" -DisplayName "CMake") { Update-Path; $somethingInstalled = $true } }
        else { if (-not $cppCounted) { $script:completedSteps++; $cppCounted = $true } }
    } else {
        $cmakeResult = Invoke-WingetInstall -PackageId "Kitware.CMake" -DisplayName "CMake"
        if ($cmakeResult) { Update-Path; $somethingInstalled = $true }
    }
    return $somethingInstalled
}

function Install-NodeJS {
    $choice = Select-Version -ToolName "Node.js" -Versions @(
        @{Label="Node.js 22 (LTS, 推荐)"; PackageId="OpenJS.NodeJS.LTS"},
        @{Label="Node.js 20 (LTS)";       PackageId="OpenJS.NodeJS.20"}
    )
    Write-Host "`n  ── 🟢 Node.js ($($choice.Label)) ──────────────────────────────" -ForegroundColor $ColorMenu
    Write-AppendLog "`n  ── Node.js ($($choice.Label)) ──"
    if (Test-CommandExists "node") {
        $ver = Get-InstalledVersion { node --version }
        if (-not (Request-Confirmation -ToolName "Node.js" -InstalledVersion $ver -TargetDesc $choice.Label)) {
            $script:completedSteps++; return $false
        }
    }
    $r = Invoke-WingetInstall -PackageId $choice.PackageId -DisplayName $choice.Label
    if (Test-CommandExists "npm") {
        try { Write-OK "npm 可用 (版本: $(npm --version 2>&1 | Select-Object -First 1))" -NoCount }
        catch { Write-Warn "npm 已安装但执行异常，请手动验证" }
    }
    Update-Path
    return $r
}

function Install-Docker {
    $r = Invoke-Installer -ToolName "🐳 Docker" -ExeName "docker" -PackageId "Docker.DockerDesktop" -DisplayName "Docker Desktop" `
        -TargetDesc "Docker Desktop (winget 最新)" -VersionCmd { docker --version } -VerReplace 'Docker version '
    Write-Info "注意: Docker Desktop 安装完成后需要重启系统。"
    return $r
}

function Install-VSCode {
    return Invoke-Installer -ToolName "📝 Visual Studio Code" -ExeName "code" -PackageId "Microsoft.VisualStudioCode" `
        -DisplayName "Visual Studio Code" -TargetDesc "VS Code (最新稳定版)" -VersionCmd { code --version }
}

# ===== 基础工具扩展 (v1.5) =====
function Install-7Zip {
    return Invoke-Installer -ToolName "🗜️ 7-Zip" -ExeName "7z" -PackageId "7zip.7zip" `
        -DisplayName "7-Zip" -TargetDesc "7-Zip (最新稳定版)" -VersionCmd { 7z --help 2>&1 | Select-Object -First 1 } -VerReplace '7-Zip '
}

function Install-WinTerminal {
    return Invoke-Installer -ToolName "🪟 Windows Terminal" -ExeName "wt" -PackageId "Microsoft.WindowsTerminal" `
        -DisplayName "Windows Terminal" -TargetDesc "Windows Terminal (最新稳定版)" -VersionCmd { wt --version 2>&1 } -VerReplace 'Windows Terminal Version '
}

function Install-PowerToys {
    Write-Host "`n  ── ⚡ PowerToys ─────────────────────────────────────────" -ForegroundColor $ColorMenu
    Write-AppendLog "`n  ── PowerToys ──"
    # PowerToys 无命令行工具，用 exe 路径检测（"以管理员身份运行"时 Program Files 可写）
    $ptExe = Join-Path ${env:ProgramFiles} "PowerToys\PowerToys.exe"
    if (Test-Path $ptExe) {
        $ver = (Get-Item $ptExe).VersionInfo.ProductVersion
        if (-not (Request-Confirmation -ToolName "PowerToys" -InstalledVersion $ver -TargetDesc "PowerToys (最新稳定版)")) {
            $script:completedSteps++; return $false
        }
    }
    $r = Invoke-WingetInstall -PackageId "Microsoft.PowerToys" -DisplayName "PowerToys"
    Update-Path
    return $r
}

function Install-Redis {
    return Invoke-Installer -ToolName "🔴 Redis" -ExeName "redis-cli" -PackageId "Redis.Redis" `
        -DisplayName "Redis for Windows" -TargetDesc "Redis on Windows (官方, winget 包 Redis.Redis)" -VersionCmd { redis-cli --version 2>&1 }
}

function Install-Miniconda {
    return Invoke-Installer -ToolName "🐍 Miniconda" -ExeName "conda" -PackageId "Anaconda.Miniconda3" `
        -DisplayName "Miniconda3" -TargetDesc "Miniconda3 (Python 数据科学环境)" -VersionCmd { conda --version 2>&1 }
}

function Install-Kubectl {
    return Invoke-Installer -ToolName "☸️ kubectl" -ExeName "kubectl" -PackageId "Kubernetes.kubectl" `
        -DisplayName "kubectl" -TargetDesc "Kubernetes CLI (最新稳定版)" -VersionCmd { kubectl version --client 2>&1 | Select-Object -First 1 }
}

function Install-DBeaver {
    return Invoke-Installer -ToolName "🗄️ DBeaver" -ExeName "dbeaver" -PackageId "DBeaver.DBeaver.Community" `
        -DisplayName "DBeaver Community" -TargetDesc "DBeaver (数据库图形化管理工具)" -VersionCmd { dbeaver --version 2>&1 }
}

function Install-Maven {
    Write-Host "`n  ── 🏗️  Maven ─────────────────────────────────────────────" -ForegroundColor $ColorMenu
    Write-AppendLog "`n  ── Maven ──"
    if (Test-CommandExists "mvn") {
        $ver = Get-InstalledVersion { mvn --version 2>&1 }
        if (-not (Request-Confirmation -ToolName "Maven" -InstalledVersion $ver -TargetDesc "Apache Maven 3.x (最新稳定版)")) {
            $script:completedSteps++; return $false
        }
    }
    
    Write-Step "正在安装 Apache Maven (从 Apache 官方源下载)..."
    
    # 获取最新稳定版 Maven 3.x 版本号（官方源 → 阿里云镜像回退）
    $mavenVersion = $null
    $mavenListUrls = @(
        "https://dlcdn.apache.org/maven/maven-3/",
        "https://mirrors.aliyun.com/apache/maven/maven-3/"
    )
    foreach ($listUrl in $mavenListUrls) {
        try {
            Write-Info "正在获取最新 Maven 版本信息 ($($listUrl.Split('/')[2]))..."
            $mirrorResponse = Invoke-WebRequest -Uri $listUrl -TimeoutSec 15 -ErrorAction Stop
            $versionMatches = [regex]::Matches($mirrorResponse.Content, 'href="(\d+\.\d+\.\d+)/"')
            if ($versionMatches.Count -gt 0) {
                $latestVersion = ($versionMatches | ForEach-Object { $_.Groups[1].Value } | Sort-Object { [Version]$_ } -Descending | Select-Object -First 1)
                if ($latestVersion) { $mavenVersion = $latestVersion; break }
            }
        } catch {
            Write-Warn "获取失败 ($($listUrl.Split('/')[2])): $_"
        }
    }
    
    # 回退到已知的稳定版本
    if (-not $mavenVersion) {
        $mavenVersion = "3.9.9"
        Write-Info "使用默认版本: $mavenVersion"
    }
    
    Write-Info "目标版本: Apache Maven $mavenVersion"
    
    # 下载 Maven 二进制包（官方源 → 阿里云镜像回退，各自带重试）
    $mavenZipUrls = @(
        "https://dlcdn.apache.org/maven/maven-3/$mavenVersion/binaries/apache-maven-$mavenVersion-bin.zip",
        "https://mirrors.aliyun.com/apache/maven/maven-3/$mavenVersion/binaries/apache-maven-$mavenVersion-bin.zip"
    )
    $tempZip = Join-Path $env:TEMP "apache-maven-$mavenVersion-bin.zip"
    $installBase = "C:\Program Files\Apache\Maven"
    $mavenHome = Join-Path $installBase "apache-maven-$mavenVersion"
    
    try {
        # 创建安装目录
        if (-not (Test-Path $installBase)) {
            New-Item -ItemType Directory -Path $installBase -Force | Out-Null
        }
        
        # 下载（多源回退）
        Write-Info "正在下载 Apache Maven $mavenVersion ..."
        $downloaded = $false
        foreach ($zipUrl in $mavenZipUrls) {
            Write-Info "下载源: $($zipUrl.Split('/')[2])"
            if (Download-WithProgress -Uri $zipUrl -OutFile $tempZip -Activity "下载 Apache Maven $mavenVersion") {
                $downloaded = $true; break
            }
            Write-Warn "该源下载失败，尝试下一个镜像..."
        }
        if (-not $downloaded) { throw "Maven 所有下载源均失败" }
        
        if (-not (Test-Path $tempZip) -or (Get-Item $tempZip).Length -lt 1MB) {
            throw "下载文件不完整或为空"
        }
        Write-OK "下载完成 ($(Format-Size (Get-Item $tempZip).Length))" -NoCount
        
        # 解压
        Write-Info "正在解压到 $mavenHome ..."
        if (Test-Path $mavenHome) {
            Remove-Item -Recurse -Force $mavenHome -ErrorAction SilentlyContinue
        }
        Expand-Archive -Path $tempZip -DestinationPath $installBase -Force
        
        if (-not (Test-Path (Join-Path $mavenHome "bin\mvn.cmd"))) {
            throw "解压后未找到 mvn.cmd，安装可能失败"
        }
        Write-OK "解压完成" -NoCount
        
        # 清理临时文件
        Remove-Item -Force $tempZip -ErrorAction SilentlyContinue
        
        # 设置 MAVEN_HOME 环境变量
        [System.Environment]::SetEnvironmentVariable("MAVEN_HOME", $mavenHome, "Machine")
        Write-OK "MAVEN_HOME 已设置为: $mavenHome" -NoCount
        
        # 将 Maven bin 目录添加到系统 PATH
        $mavenBin = Join-Path $mavenHome "bin"
        $curPath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
        if ($curPath -notmatch [regex]::Escape($mavenBin)) {
            [System.Environment]::SetEnvironmentVariable("Path", "$curPath;$mavenBin", "Machine")
            Write-OK "已将 Maven bin 添加到系统 PATH" -NoCount
        }
        
        Update-Path
        Write-OK "Apache Maven $mavenVersion 安装成功!"
        return $true
    }
    catch {
        Write-Fail "Apache Maven 安装失败"
        Write-Info "详情: $_"
        
        # 清理
        Remove-Item -Force $tempZip -ErrorAction SilentlyContinue
        if (Test-Path $mavenHome) {
            Remove-Item -Recurse -Force $mavenHome -ErrorAction SilentlyContinue
        }
        return $false
    }
}

function Install-MySQL {
    Write-Host "`n  ── 🗄️  MySQL ─────────────────────────────────────────────" -ForegroundColor $ColorMenu
    Write-AppendLog "`n  ── MySQL ──"
    if (Test-MySqlExists) {
        $mysqlBin = Get-MySqlBin
        $mysqlCmd = if ($mysqlBin) { Join-Path $mysqlBin "mysql.exe" } else { "mysql" }
        $ver = Get-InstalledVersion { & $mysqlCmd --version 2>&1 }
        if ($ver -match 'Ver (\S+)') { $ver = "Ver $($matches[1])" }
        if (-not (Request-Confirmation -ToolName "MySQL" -InstalledVersion $ver -TargetDesc "MySQL Community Server (winget 最新版)")) {
            $script:completedSteps++; return $false
        }
    }
    $r = Invoke-WingetInstall -PackageId "Oracle.MySQL" -DisplayName "MySQL Community Server"
    if ($r) { Update-Path }
    if ($r) {
        Write-Info "MySQL 安装完成。首次使用请执行初始化:"
        Write-Info "  1. 打开 MySQL Installer 或命令行"
        Write-Info "  2. 运行: mysqld --initialize --console  (生成随机 root 密码)"
        Write-Info "  3. 运行: mysql_secure_installation       (修改密码 + 安全加固)"
    }
    return $r
}

# ========================== Android 开发环境 ==========================
function Test-AndroidStudioExists {
    $paths = @(
        "${env:ProgramFiles}\Android\Android Studio\bin\studio64.exe",
        "${env:ProgramFiles(x86)}\Android\Android Studio\bin\studio64.exe",
        "$env:LOCALAPPDATA\Android\Android Studio\bin\studio64.exe"
    )
    foreach ($p in $paths) { if (Test-Path $p) { return $true } }
    return (Test-CommandExists "studio64")
}

function Get-AndroidSdkPath {
    # 优先使用已有的 ANDROID_HOME
    if ($env:ANDROID_HOME -and (Test-Path $env:ANDROID_HOME)) { return $env:ANDROID_HOME }
    $defaultPath = "$env:LOCALAPPDATA\Android\Sdk"
    if (Test-Path $defaultPath) { return $defaultPath }
    return $defaultPath  # 默认路径，即使不存在也返回
}

# 多 URL 回退下载：按顺序尝试，任一成功即返回
function Invoke-DownloadWithFallback {
    param([string[]]$Urls, [string]$OutFile, [int]$TimeoutSec = 120, [int]$MinSizeMB = 1)
    foreach ($url in $Urls) {
        try {
            Write-Info "尝试下载: $url"
            $ok = Download-WithProgress -Uri $url -OutFile $OutFile -Activity "下载 Android SDK 组件"
            if (-not $ok) { throw "下载失败" }
            if (-not (Test-Path $OutFile) -or (Get-Item $OutFile).Length -lt ($MinSizeMB * 1MB)) {
                throw "下载文件不完整或为空"
            }
            return $true
        } catch {
            Write-Warn "失败 ($($url.Split('/')[2])): $_"
            # 保留半成品文件：Download-WithProgress 下次会自动断点续传（同一文件内容一致）
        }
    }
    return $false
}

function Install-Android {
    Write-Host "`n  ── 🤖 Android 开发环境 ────────────────────────────────────" -ForegroundColor $ColorMenu
    Write-AppendLog "`n  ── Android 开发环境 ──"
    $androidCounted = $false
    $sdkPath = Get-AndroidSdkPath
    
    # ---- 1. Android Studio ----
    $studioInstalled = Test-AndroidStudioExists
    if ($studioInstalled) {
        if (-not (Request-Confirmation -ToolName "Android Studio" -InstalledVersion "已安装" -TargetVersionDesc "Android Studio (winget 最新版)")) {
            if (-not $androidCounted) { $script:completedSteps++; $androidCounted = $true }
        } else {
            $studioInstalled = $false
        }
    }
    if (-not $studioInstalled) {
        $r = Invoke-WingetInstall -PackageId "Google.AndroidStudio" -DisplayName "Android Studio"
        if ($r) { Update-Path; $studioInstalled = $true }
    }
    # winget 失败时尝试从国内可访问的镜像下载
    if (-not $studioInstalled) {
        Write-Step "winget 安装失败，尝试从国内镜像下载 Android Studio ..."
        $studioTempDir = Join-Path $env:TEMP "android_studio_installer"
        New-Item -ItemType Directory -Path $studioTempDir -Force | Out-Null
        $studioExe = Join-Path $studioTempDir "android-studio-installer.exe"
        try {
            # 从 Google 中国开发者站点获取最新版本号
            $studioVerPage = Invoke-RestMethod -Uri "https://developer.android.google.cn/studio" -TimeoutSec 15 -ErrorAction Stop
            $verMatch = [regex]::Match($studioVerPage, 'android-studio-(\d+\.\d+(?:\.\d+)?)-windows\.exe')
            if ($verMatch.Success) {
                $studioVersion = $verMatch.Groups[1].Value
                $studioUrls = @(
                    "https://redirector.gvt1.com/edgedl/android/studio/install/$studioVersion/android-studio-$studioVersion-windows.exe",
                    "https://dl.google.com/dl/android/studio/install/$studioVersion/android-studio-$studioVersion-windows.exe"
                )
                if (Invoke-DownloadWithFallback -Urls $studioUrls -OutFile $studioExe -TimeoutSec 300 -MinSizeMB 100) {
                    Write-Info "正在安装 Android Studio (请等待安装程序完成)..."
                    Start-Process -FilePath $studioExe -Wait -ErrorAction Stop
                    Write-OK "Android Studio 安装完成" -NoCount
                    # 刷新 PATH 更新
                    Update-Path
                    $studioInstalled = $true
                }
            }
        } catch {
            Write-Warn "镜像下载失败: $_"
        }
        Remove-Item -Recurse -Force $studioTempDir -ErrorAction SilentlyContinue
    }
    # 如果仍然失败，提供手动下载指引
    if (-not $studioInstalled) {
        Write-Warn "Android Studio 自动安装失败（网络环境无法到达 Google 服务器）。"
        Write-Info "Android SDK 组件已通过国内镜像安装成功，只差 Android Studio 本身。"
        Write-Info "请手动下载 Android Studio 安装程序:"
        Write-Info "  方案1: 访问 https://developer.android.google.cn/studio 下载（Google 中国站）"
        Write-Info "  方案2: 使用手机热点共享网络后重新运行本脚本"
        Write-Info "  方案3: 从其他电脑下载安装包复制到本机"
        Write-Info "  安装后首次启动 → More Actions → SDK Manager 确认 SDK 已就绪即可"
    }
    
    # ---- 2. SDK 组件（直接从腾讯云镜像下载，无需 cmdline-tools） ----
    $sdkComplete = $false
    $hasPlatform34 = Test-Path (Join-Path $sdkPath "platforms\android-34")
    $hasBuildTools = Test-Path (Join-Path $sdkPath "build-tools\34.0.0\aapt.exe")
    $hasPlatformTools = Test-Path (Join-Path $sdkPath "platform-tools\adb.exe")
    $mirrorBase = "https://mirrors.cloud.tencent.com/AndroidSDK"
    
    if ($hasPlatform34 -and $hasBuildTools -and $hasPlatformTools) {
        Write-OK "Android SDK (platform 34+) 已就绪" -NoCount
        if (-not $androidCounted) { $script:completedSteps++; $androidCounted = $true }
        $sdkComplete = $true
    }
    
    if (-not $sdkComplete) {
        # 从 repository2-1.xml 实时解析各组件的最新文件名
        try {
            Write-Step "正在从腾讯云镜像获取 SDK 组件版本信息..."
            $repoXml = Invoke-RestMethod -Uri "$mirrorBase/repository2-1.xml" -TimeoutSec 30 -ErrorAction Stop
            $xml = [xml]$repoXml
            
            # 解析 platform-tools Windows 版
            $ptUrl = $xml.SelectSingleNode('//remotePackage[@path="platform-tools"]/.//archive[./host-os="windows"]/complete/url')
            if (-not $ptUrl) { $ptUrl = $xml.SelectSingleNode('//remotePackage[@path="platform-tools"]/.//archive[not(./host-os)]/complete/url') }
            
            # 解析 build-tools;34.0.0 Windows 版
            $btUrl = $xml.SelectSingleNode('//remotePackage[@path="build-tools;34.0.0"]/.//archive[./host-os="windows"]/complete/url')
            if (-not $btUrl) { $btUrl = $xml.SelectSingleNode('//remotePackage[@path="build-tools;34.0.0"]/.//archive[not(./host-os)]/complete/url') }
            
            # 解析 platforms;android-34（无 OS 限制）
            $p34Url = $xml.SelectSingleNode('//remotePackage[@path="platforms;android-34"]/.//archive[not(./host-os)]/complete/url')
            if (-not $p34Url) { $p34Url = $xml.SelectSingleNode('//remotePackage[@path="platforms;android-34"]/.//archive/complete/url') }
            
            # 下载并解压各个组件
            $sdkTempDir = Join-Path $env:TEMP "android_sdk_components"
            New-Item -ItemType Directory -Path $sdkTempDir -Force | Out-Null
            
            # platform-tools
            if ($ptUrl -and -not $hasPlatformTools) {
                $ptFile = $ptUrl.'#text'.Trim()
                Write-Step "正在下载 platform-tools ($ptFile)..."
                if (Invoke-DownloadWithFallback -Urls @("$mirrorBase/$ptFile") -OutFile (Join-Path $sdkTempDir "pt.zip") -TimeoutSec 120 -MinSizeMB 1) {
                    Expand-Archive -Path (Join-Path $sdkTempDir "pt.zip") -DestinationPath $sdkPath -Force
                    Write-OK "platform-tools 安装成功" -NoCount
                    $hasPlatformTools = $true
                }
            }
            
            # build-tools 34.0.0
            if ($btUrl -and -not $hasBuildTools) {
                $btFile = $btUrl.'#text'.Trim()
                Write-Step "正在下载 Build Tools 34.0.0 ($btFile)..."
                if (Invoke-DownloadWithFallback -Urls @("$mirrorBase/$btFile") -OutFile (Join-Path $sdkTempDir "bt.zip") -TimeoutSec 120 -MinSizeMB 1) {
                    $btExtract = Join-Path $sdkTempDir "bt_extracted"
                    Expand-Archive -Path (Join-Path $sdkTempDir "bt.zip") -DestinationPath $btExtract -Force
                    # build-tools 解压后目录结构是 build-tools/34.0.0/
                    New-Item -ItemType Directory -Path (Join-Path $sdkPath "build-tools\34.0.0") -Force | Out-Null
                    Copy-Item -Path "$btExtract\*" -Destination (Join-Path $sdkPath "build-tools\34.0.0") -Recurse -Force
                    Write-OK "Build Tools 34.0.0 安装成功" -NoCount
                    $hasBuildTools = $true
                }
            }
            
            # platform android-34
            if ($p34Url -and -not $hasPlatform34) {
                $p34File = $p34Url.'#text'.Trim()
                Write-Step "正在下载 Android SDK Platform 34 ($p34File)..."
                if (Invoke-DownloadWithFallback -Urls @("$mirrorBase/$p34File") -OutFile (Join-Path $sdkTempDir "p34.zip") -TimeoutSec 120 -MinSizeMB 1) {
                    $p34Extract = Join-Path $sdkTempDir "p34_extracted"
                    Expand-Archive -Path (Join-Path $sdkTempDir "p34.zip") -DestinationPath $p34Extract -Force
                    New-Item -ItemType Directory -Path (Join-Path $sdkPath "platforms\android-34") -Force | Out-Null
                    Copy-Item -Path "$p34Extract\*" -Destination (Join-Path $sdkPath "platforms\android-34") -Recurse -Force
                    Write-OK "Android SDK Platform 34 安装成功" -NoCount
                    $hasPlatform34 = $true
                }
            }
            
            # 清理
            Remove-Item -Recurse -Force $sdkTempDir -ErrorAction SilentlyContinue
            
        } catch {
            Write-Warn "腾讯云镜像组件下载失败: $_"
            Remove-Item -Recurse -Force $sdkTempDir -ErrorAction SilentlyContinue
        }
        
        # ---- 3. 环境变量设置 ----
        try {
            # 如果还没有 ANDROID_HOME，设置它
            if (-not $env:ANDROID_HOME) {
                [System.Environment]::SetEnvironmentVariable("ANDROID_HOME", $sdkPath, "Machine")
                Write-OK "ANDROID_HOME 已设置为: $sdkPath" -NoCount
            }
            # 同样设置 ANDROID_SDK_ROOT
            if (-not $env:ANDROID_SDK_ROOT) {
                [System.Environment]::SetEnvironmentVariable("ANDROID_SDK_ROOT", $sdkPath, "Machine")
                Write-OK "ANDROID_SDK_ROOT 已设置为: $sdkPath" -NoCount
            }
            # 将 platform-tools 添加到 PATH
            $ptPath = Join-Path $sdkPath "platform-tools"
            if (Test-Path $ptPath) {
                $curPath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
                if ($curPath -notmatch [regex]::Escape($ptPath)) {
                    [System.Environment]::SetEnvironmentVariable("Path", "$curPath;$ptPath", "Machine")
                    Write-OK "已将 platform-tools 添加到系统 PATH" -NoCount
                }
            }
        } catch {
            Write-Warn "环境变量设置失败，请手动配置: $_"
        }
        
        Update-Path
        
        # ---- 5. 最终检查 ----
        if ($hasPlatform34) {
            if (-not $androidCounted) { $script:completedSteps++; $androidCounted = $true }
            $sdkComplete = $true
        }
    }
    
    # ---- Fallback: 如果一键安装不完整，提供指引 ----
    if (-not $sdkComplete) {
        Write-Warn "Android SDK 部分组件未自动安装完成。"
        Write-Info "请手动完成以下步骤:"
        Write-Info "  1️⃣  打开 Android Studio → 欢迎页 → More Actions → SDK Manager"
        Write-Info "  2️⃣  在 SDK Platforms 选项卡勾选 Android 14.0 (API 34) 或更高版本"
        Write-Info "  3️⃣  在 SDK Tools 选项卡勾选 Android SDK Platform-Tools"
        Write-Info "  4️⃣  点击 Apply/OK 下载安装"
        if (-not $env:ANDROID_HOME) {
            Write-Info "  5️⃣  设置系统环境变量:"
            Write-Info "      ANDROID_HOME = $sdkPath"
            Write-Info "      ANDROID_SDK_ROOT = $sdkPath"
            Write-Info "      PATH 追加: $sdkPath\platform-tools"
        }
        # 未完全自动安装但至少装了 Android Studio，也算完成一项
        if ($studioInstalled -and (-not $androidCounted)) { $script:completedSteps++; $androidCounted = $true }
    }
    
    return ($studioInstalled -or $sdkComplete)
}

function Install-All {
    Write-Host "`n  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor "Red"
    Write-Host "  ║         🚀  开 始 一 键 安 装 所 有 工 具                  ║" -ForegroundColor "Red"
    Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor "Red"
    Write-AppendLog "`n  ╔══════════════════════════════════════════════╗"
    Write-AppendLog "  ║           一键安装所有工具开始               ║"
    Write-AppendLog "  ╚══════════════════════════════════════════════╝"
    $script:completedSteps = 0
    $startTime = Get-Date
    $funcs = @(
        @{Name="Git";     F={ Install-Git }},
        @{Name="7-Zip";   F={ Install-7Zip }},
        @{Name="Python";  F={ Install-Python }},
        @{Name="Java";    F={ Install-Java }},
        @{Name="C/C++";   F={ Install-CPP }},
        @{Name="Node.js"; F={ Install-NodeJS }},
        @{Name="Maven";   F={ Install-Maven }},
        @{Name="MySQL";   F={ Install-MySQL }},
        @{Name="Redis";   F={ Install-Redis }},
        @{Name="DBeaver"; F={ Install-DBeaver }},
        @{Name="Docker";  F={ Install-Docker }},
        @{Name="kubectl"; F={ Install-Kubectl }},
        @{Name="Miniconda"; F={ Install-Miniconda }},
        @{Name="VS Code"; F={ Install-VSCode }},
        @{Name="WinTerminal"; F={ Install-WinTerminal }},
        @{Name="PowerToys"; F={ Install-PowerToys }},
        @{Name="Android"; F={ Install-Android }}
    )
    foreach ($fn in $funcs) {
        try {
            & $fn.F
        } catch {
            Write-Fail "安装 $($fn.Name) 时发生意外错误: $_"
        }
    }
    $dur = ((Get-Date) - $startTime).TotalMinutes.ToString("F1")
    Write-Host "`n  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor $ColorSuccess
    Write-Host "  ║                        🎉  安装流程完成!                                ║" -ForegroundColor $ColorSuccess
    Write-Host "  ║              已处理 $script:completedSteps/$($funcs.Count) 项 / 耗时: ${dur}分钟                   ║" -ForegroundColor $ColorSuccess
    Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor $ColorSuccess
    Write-AppendLog "  ╔══════════════════════════════════════════════╗"
    Write-AppendLog "  ║        安装流程完成! 已处理 $script:completedSteps/$($funcs.Count) 项 / 耗时: ${dur}分钟        ║"
    Write-AppendLog "  ╚══════════════════════════════════════════════╝"
    Show-Summary
    Invoke-Reboot
}

# ========================== 按开发方向安装 ==========================
# 复用现有 Install-* 函数，按方向批量安装（try/catch 独立容错，与 Install-All 一致）
function Install-JavaStack {
    Write-Host "`n  ☕ 开始安装 Java 后端全家桶 (JDK + Maven + MySQL + Redis + DBeaver) ..." -ForegroundColor $ColorStep
    Write-AppendLog "`n  ☕ Java 后端全家桶开始"
    foreach ($t in @(
        @{Name="Java JDK"; F={ Install-Java }}, @{Name="Maven"; F={ Install-Maven }},
        @{Name="MySQL"; F={ Install-MySQL }}, @{Name="Redis"; F={ Install-Redis }},
        @{Name="DBeaver"; F={ Install-DBeaver }})) {
        try { & $t.F } catch { Write-Fail "安装 $($t.Name) 失败: $_" }
    }
    Write-OK "Java 后端全家桶处理完成" -NoCount
}

function Install-WebStack {
    Write-Host "`n  🖥️ 开始安装前端全家桶 (Node.js + VS Code) ..." -ForegroundColor $ColorStep
    Write-AppendLog "`n  🖥️ 前端全家桶开始"
    foreach ($t in @(
        @{Name="Node.js"; F={ Install-NodeJS }}, @{Name="VS Code"; F={ Install-VSCode }})) {
        try { & $t.F } catch { Write-Fail "安装 $($t.Name) 失败: $_" }
    }
    Write-OK "前端全家桶处理完成" -NoCount
}

function Install-PythonStack {
    Write-Host "`n  🐍 开始安装 Python 全家桶 (Python + Miniconda) ..." -ForegroundColor $ColorStep
    Write-AppendLog "`n  🐍 Python 全家桶开始"
    foreach ($t in @(
        @{Name="Python"; F={ Install-Python }}, @{Name="Miniconda"; F={ Install-Miniconda }})) {
        try { & $t.F } catch { Write-Fail "安装 $($t.Name) 失败: $_" }
    }
    Write-OK "Python 全家桶处理完成" -NoCount
}

function Install-DevOpsStack {
    Write-Host "`n  🐳 开始安装容器/运维全家桶 (Docker + kubectl) ..." -ForegroundColor $ColorStep
    Write-AppendLog "`n  🐳 容器/运维全家桶开始"
    foreach ($t in @(
        @{Name="Docker"; F={ Install-Docker }}, @{Name="kubectl"; F={ Install-Kubectl }})) {
        try { & $t.F } catch { Write-Fail "安装 $($t.Name) 失败: $_" }
    }
    Write-OK "容器/运维全家桶处理完成" -NoCount
}

# ========================== 显示摘要 ==========================
function Show-Summary {
    Write-Host "`n  ── 📋 当前环境检测结果 ──────────────────────────────────" -ForegroundColor $ColorMenu
    Write-AppendLog "`n  ── 📋 当前环境检测结果 ──"
    Update-Path
    $tools = @(
        @{L="Git";      C={ git --version }},
        @{L="Python";   C={ python --version }},
        @{L="pip";      C={ pip --version }},
        @{L="Java";     C={ java -version 2>&1 }},
        @{L="javac";    C={ javac --version }},
        @{L="Maven";    C={ mvn --version 2>&1 }},
        @{L="GCC";      C={ gcc --version }},
        @{L="G++";      C={ g++ --version }},
        @{L="Node.js";  C={ node --version }},
        @{L="npm";      C={ npm --version }},
        @{L="Docker";   C={ docker --version }},
        @{L="MySQL";    C={
                $mb = Get-MySqlBin
                $raw = if ($mb) { & (Join-Path $mb "mysql.exe") --version 2>&1 } else { mysql --version 2>&1 }
                if ($raw -match 'Ver (\S+)') { "Ver $($matches[1])" } else { $raw }
            }},
        @{L="CMake";    C={ cmake --version }},
        @{L="VS Code";  C={ code --version }},
        @{L="Android Studio"; C={
                $p = "${env:ProgramFiles}\Android\Android Studio\bin\studio64.exe"
                if (Test-Path $p) { "已安装" }
                elseif (Test-CommandExists "studio64") { (Get-Command studio64).Source }
                else { throw [System.Management.Automation.CommandNotFoundException]::new("studio64") }
            }},
        @{L="Android SDK";    C={
                $sdk = Get-AndroidSdkPath
                if (Test-Path (Join-Path $sdk "platforms\android-34")) {
                    $apiLevels = @(Get-ChildItem (Join-Path $sdk "platforms") -Directory -Filter "android-*" -ErrorAction SilentlyContinue |
                                    ForEach-Object { $_.Name -replace 'android-', '' } |
                                    Sort-Object { [int]$_ } -Descending)
                    if ($apiLevels) { "API $($apiLevels[0])+ ($sdk)" } else { "已安装" }
                } else { throw [System.Management.Automation.CommandNotFoundException]::new("android-34") }
            }},
        @{L="7-Zip";    C={ 7z --help 2>&1 | Select-Object -First 1 }},
        @{L="WinTerm";  C={ wt --version 2>&1 }},
        @{L="PowerToys"; C={
                $p = Join-Path ${env:ProgramFiles} "PowerToys\PowerToys.exe"
                if (Test-Path $p) { (Get-Item $p).VersionInfo.ProductVersion } else { throw [System.Management.Automation.CommandNotFoundException]::new("PowerToys") }
            }},
        @{L="Redis";    C={ redis-cli --version 2>&1 }},
        @{L="Miniconda"; C={ conda --version 2>&1 }},
        @{L="kubectl";  C={ kubectl version --client 2>&1 | Select-Object -First 1 }},
        @{L="DBeaver";  C={ dbeaver --version 2>&1 }}
    )
    foreach ($t in $tools) {
        try { $v = & $t.C 2>&1 | Select-Object -First 1; Write-Host "  ✅ $($t.L.PadRight(10)) : $v" -ForegroundColor $ColorSuccess; Write-AppendLog "  ✅ $($t.L.PadRight(10)) : $v" }
        catch [System.Management.Automation.CommandNotFoundException] { Write-Host "  ❌ $($t.L.PadRight(10)) : 未安装" -ForegroundColor $ColorError; Write-AppendLog "  ❌ $($t.L.PadRight(10)) : 未安装" }
        catch { Write-Host "  ⚠️  $($t.L.PadRight(10)) : 检测异常 ($($_.Exception.Message))" -ForegroundColor $ColorWarning; Write-AppendLog "  ⚠️  $($t.L.PadRight(10)) : 检测异常 ($($_.Exception.Message))" }
    }
}

function Invoke-Reboot {
    Write-Host "`n  ⚠️  部分工具 (如 Docker) 安装后需要重启系统才能完全生效。" -ForegroundColor $ColorWarning
    Write-Host "  是否立即重启? (Y/N): " -NoNewline -ForegroundColor $ColorPrompt
    $rebootInput = Read-Host
    if ($rebootInput -match '^[Yy]$') {
        Write-AppendLog "  🔄 用户选择立即重启系统"
        Write-Host "  ⚠️  即将重启系统，请先保存所有未保存的工作!" -ForegroundColor $ColorWarning
        Write-Host "  按任意键确认重启 (或 Ctrl+C 取消)..." -ForegroundColor $ColorWarning
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Restart-Computer
    }
    Write-AppendLog "  🔄 用户跳过重启"
}

# 清理旧日志，仅保留最近 10 个
function Clear-OldLogs {
    param([string]$LogDir)
    $pattern = "install_log_*.txt"
    $oldLogs = @(Get-ChildItem -Path $LogDir -Filter $pattern -File -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending |
                Select-Object -Skip 10)
    if ($oldLogs) {
        $oldLogs | Remove-Item -Force -ErrorAction SilentlyContinue
        Write-Info "已清理 $(@($oldLogs).Count) 个旧日志文件"
    }
}

function Save-Log {
    Clear-OldLogs -LogDir $script:logDir
    Write-Host "`n  📄 实时日志已保存到: $script:logFilePath" -ForegroundColor $ColorInfo
}

# 等待按键
function Wait-Key {
    Write-Host "`n  按任意键返回主菜单..." -ForegroundColor $ColorInfo
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# ========================== 主菜单（按开发方向分组） ==========================
$menu = [ordered]@{
    '1'  = @{Label="🚀 一键安装全部 (推荐)"; Action={ Install-All }}
    '2'  = @{Label="🔧 仅安装 Git"; Action={ $null = Install-Git }}
    '3'  = @{Label="🗜️ 仅安装 7-Zip"; Action={ $null = Install-7Zip }}
    '4'  = @{Label="🪟 仅安装 Windows Terminal"; Action={ $null = Install-WinTerminal }}
    '5'  = @{Label="⚡ 仅安装 PowerToys"; Action={ $null = Install-PowerToys }}
    '6'  = @{Label="📝 仅安装 VS Code"; Action={ $null = Install-VSCode }}
    '7'  = @{Label="☕ 仅安装 Java (JDK)"; Action={ $null = Install-Java }}
    '8'  = @{Label="🏗️ 仅安装 Maven"; Action={ $null = Install-Maven }}
    '9'  = @{Label="🗄️ 仅安装 MySQL"; Action={ $null = Install-MySQL }}
    '10' = @{Label="🔴 仅安装 Redis"; Action={ $null = Install-Redis }}
    '11' = @{Label="🗄️ 仅安装 DBeaver"; Action={ $null = Install-DBeaver }}
    '12' = @{Label="☕ Java 后端全家桶 (7-11)"; Action={ Install-JavaStack }}
    '13' = @{Label="🟢 仅安装 Node.js"; Action={ $null = Install-NodeJS }}
    '14' = @{Label="🖥️ 前端全家桶 (Node.js + VS Code)"; Action={ Install-WebStack }}
    '15' = @{Label="🐍 仅安装 Python"; Action={ $null = Install-Python }}
    '16' = @{Label="🐍 仅安装 Miniconda"; Action={ $null = Install-Miniconda }}
    '17' = @{Label="🐍 Python 全家桶 (15-16)"; Action={ Install-PythonStack }}
    '18' = @{Label="⚙️ 仅安装 C/C++ (MinGW + CMake)"; Action={ $null = Install-CPP }}
    '19' = @{Label="🤖 仅安装 Android Studio + SDK 34+"; Action={ $null = Install-Android }}
    '20' = @{Label="🐳 仅安装 Docker"; Action={ $null = Install-Docker }}
    '21' = @{Label="☸️ 仅安装 kubectl"; Action={ $null = Install-Kubectl }}
    '22' = @{Label="🐳 容器/运维全家桶 (20-21)"; Action={ Install-DevOpsStack }}
    '23' = @{Label="📋 查看当前环境摘要"; Action={ Show-Summary }}
}

# 菜单分组定义（组标题 → 菜单编号）
$menuGroups = [ordered]@{
    "🧩 基础必备"    = @('1','2','3','4','5','6')
    "☕ Java 后端"   = @('7','8','9','10','11','12')
    "🖥️ 前端 / Web" = @('13','14')
    "🐍 Python"      = @('15','16','17')
    "⚙️ C/C++"      = @('18')
    "🤖 移动开发"    = @('19')
    "🐳 容器 / 运维" = @('20','21','22')
    "📋 系统"        = @('23')
}

function Show-Menu {
    Write-Title
    Write-Host "  请选择要执行的操作 (按开发方向分组):" -ForegroundColor $ColorInfo
    Write-Host ""
    foreach ($g in $menuGroups.GetEnumerator()) {
        Write-Host "  ── $($g.Key) ──────────────────────────────" -ForegroundColor $ColorTitle
        foreach ($k in $g.Value) {
            Write-Host "    [$k]  $($menu[$k].Label)" -ForegroundColor $(if ($k -eq '1') { "Green" } else { $ColorMenu })
        }
        Write-Host ""
    }
    Write-Host "    [0]  👋 退出" -ForegroundColor $ColorMenu
    Write-Host "`n  ───────────────────────────────────────────────────────────" -ForegroundColor $ColorTitle
Write-Host "  请输入选项 [0-$($menu.Count)]: " -NoNewline -ForegroundColor $ColorPrompt
}

# ========================== 主循环 ==========================
do {
    Show-Menu
    $choice = Read-Host
    # 调试: trim 输入 + 输出实际读取值
    $choice = $choice.Trim()
    Clear-Host
    Write-Title
    
    if ($choice -eq '0') {
        Write-Host "`n  👋 再见! 祝你编码愉快~" -ForegroundColor $ColorTitle
        Write-AppendLog "  👋 用户退出脚本"
        exit
    }
    elseif ($menu.Contains($choice)) {
        Write-AppendLog "  📌 用户选择: [$choice]"
        & $menu[$choice].Action
        # 选项 23 (Show-Summary) 不产生安装日志，跳过保存
        if ($choice -ne '23') { Save-Log }
        Wait-Key
    }
    else {
        Write-Host "`n  ❌ 无效选项，请重新选择。" -ForegroundColor $ColorError
        Write-AppendLog "  ❌ 无效选项: $choice"
        Start-Sleep -Seconds 1
    }
} while ($true)