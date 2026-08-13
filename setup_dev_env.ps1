<#
============================================================================
  🛠️  开发环境一键配置工具  v1.4
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
  ║        🛠️   开 发 环 境 一 键 配 置 工 具   v1.4           ║
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

# winget 安装 (--disable-interactivity 禁用 spinner 干扰输出)
function Invoke-WingetInstall {
    param([string]$PackageId, [string]$DisplayName)
    Write-Step "正在安装 $DisplayName ..."
    $r = winget install --id $PackageId --disable-interactivity --accept-source-agreements --accept-package-agreements 2>&1
    if ($LASTEXITCODE -eq 0 -or $r -match "已安装|已找到已安装|No applicable update|already installed|Successfully installed") {
        Write-OK "$DisplayName 安装成功 (或已安装)"; return $true
    }
    elseif ($r -match "InternetOpenUrl|0x80072efd|0x80072ee7|0x80072f8f") {
        Write-Fail "$DisplayName 安装失败: 无法连接到互联网"; return $false
    }
    Write-Fail "$DisplayName 安装失败"; Write-Info "详情: $r"; return $false
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
            Write-Info "下载: $($asset.name) ($([math]::Round($asset.size/1MB, 1)) MB)"
            $installerPath = Join-Path $tempDir $asset.name
            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $installerPath -TimeoutSec 120 -ErrorAction Stop
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
    $r = Invoke-Installer -ToolName "🐍 Python" -ExeName "python" -PackageId "Python.Python.3.12" -DisplayName "Python 3.12" `
        -TargetDesc "Python 3.12.x (最新小版本)" -VersionCmd { python --version }
    if (Test-CommandExists "pip") { Write-OK "pip 可用" -NoCount } else { Write-Warn "pip 未找到，请手动验证 Python 安装" }
    return $r
}

function Install-Java {
    $r = Invoke-Installer -ToolName "☕ Java (JDK)" -ExeName "java" -PackageId "EclipseAdoptium.Temurin.21.JDK" `
        -DisplayName "Eclipse Temurin JDK 21 (LTS)" -TargetDesc "Eclipse Temurin JDK 21 (LTS)" -VersionCmd { java -version 2>&1 }
    # 设置 JAVA_HOME
    try {
        if (-not ${env:JAVA_HOME}) {
            foreach ($p in "C:\Program Files\Eclipse Adoptium\jdk-21*\") {
                $f = Get-Item $p -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
                if ($f) { [System.Environment]::SetEnvironmentVariable("JAVA_HOME", $f.FullName, "Machine"); Write-OK "JAVA_HOME 已设置为: $($f.FullName)" -NoCount; break }
            }
        }
    } catch { Write-Warn "JAVA_HOME 设置失败，请手动配置" }
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
        foreach ($e in @(@{Id="niXman.mingw-w64"; Name="MinGW-w64 (独立版)"}, @{Id="MSYS2.MSYS2"; Name="MSYS2 (含 MinGW-w64)"})) {
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
    $r = Invoke-Installer -ToolName "🟢 Node.js" -ExeName "node" -PackageId "OpenJS.NodeJS.LTS" -DisplayName "Node.js (LTS)" `
        -TargetDesc "Node.js LTS (当前为 22.x)" -VersionCmd { node --version }
    if (Test-CommandExists "npm") {
        try { Write-OK "npm 可用 (版本: $(npm --version 2>&1 | Select-Object -First 1))" -NoCount }
        catch { Write-Warn "npm 已安装但执行异常，请手动验证" }
    }
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
    
    # 获取最新稳定版 Maven 3.x 版本号
    $mavenVersion = $null
    try {
        Write-Info "正在获取最新 Maven 版本信息..."
        $mirrorResponse = Invoke-WebRequest -Uri "https://dlcdn.apache.org/maven/maven-3/" -TimeoutSec 15 -ErrorAction Stop
        $versionMatches = [regex]::Matches($mirrorResponse.Content, 'href="(\d+\.\d+\.\d+)/"')
        if ($versionMatches.Count -gt 0) {
            $latestVersion = ($versionMatches | ForEach-Object { $_.Groups[1].Value } | Sort-Object { [Version]$_ } -Descending | Select-Object -First 1)
            if ($latestVersion) { $mavenVersion = $latestVersion }
        }
    } catch {
        Write-Warn "无法获取最新版本信息: $_"
    }
    
    # 回退到已知的稳定版本
    if (-not $mavenVersion) {
        $mavenVersion = "3.9.9"
        Write-Info "使用默认版本: $mavenVersion"
    }
    
    Write-Info "目标版本: Apache Maven $mavenVersion"
    
    # 下载 Maven 二进制包
    $mavenZipUrl = "https://dlcdn.apache.org/maven/maven-3/$mavenVersion/binaries/apache-maven-$mavenVersion-bin.zip"
    $tempZip = Join-Path $env:TEMP "apache-maven-$mavenVersion-bin.zip"
    $installBase = "C:\Program Files\Apache\Maven"
    $mavenHome = Join-Path $installBase "apache-maven-$mavenVersion"
    
    try {
        # 创建安装目录
        if (-not (Test-Path $installBase)) {
            New-Item -ItemType Directory -Path $installBase -Force | Out-Null
        }
        
        # 下载
        Write-Info "正在下载 Apache Maven $mavenVersion ..."
        Invoke-WebRequest -Uri $mavenZipUrl -OutFile $tempZip -TimeoutSec 120 -ErrorAction Stop
        
        if (-not (Test-Path $tempZip) -or (Get-Item $tempZip).Length -lt 1MB) {
            throw "下载文件不完整或为空"
        }
        Write-OK "下载完成 ($([math]::Round((Get-Item $tempZip).Length / 1MB, 1)) MB)" -NoCount
        
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
            Invoke-WebRequest -Uri $url -OutFile $OutFile -TimeoutSec $TimeoutSec -ErrorAction Stop
            if (-not (Test-Path $OutFile) -or (Get-Item $OutFile).Length -lt ($MinSizeMB * 1MB)) {
                throw "下载文件不完整或为空"
            }
            return $true
        } catch {
            Write-Warn "失败 ($($url.Split('/')[2])): $_"
            Remove-Item $OutFile -Force -ErrorAction SilentlyContinue
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
        @{Name="Python";  F={ Install-Python }},
        @{Name="Java";    F={ Install-Java }},
        @{Name="C/C++";   F={ Install-CPP }},
        @{Name="Node.js"; F={ Install-NodeJS }},
        @{Name="Docker";  F={ Install-Docker }},
        @{Name="VS Code"; F={ Install-VSCode }},
        @{Name="Maven";   F={ Install-Maven }},
        @{Name="MySQL";   F={ Install-MySQL }},
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
            }}
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

# ========================== 主菜单 ==========================
$menu = [ordered]@{
    '1'  = @{Label="🚀 一键安装全部 (推荐)"; Action={ Install-All }}
    '2'  = @{Label="🔧 仅安装 Git"; Action={ $null = Install-Git }}
    '3'  = @{Label="🐍 仅安装 Python"; Action={ $null = Install-Python }}
    '4'  = @{Label="☕ 仅安装 Java (JDK)"; Action={ $null = Install-Java }}
    '5'  = @{Label="⚙️ 仅安装 C/C++ 开发工具 (MinGW + CMake)"; Action={ $null = Install-CPP }}
    '6'  = @{Label="🟢 仅安装 Node.js"; Action={ $null = Install-NodeJS }}
    '7'  = @{Label="🐳 仅安装 Docker"; Action={ $null = Install-Docker }}
    '8'  = @{Label="📝 仅安装 VS Code"; Action={ $null = Install-VSCode }}
    '9'  = @{Label="🏗️ 仅安装 Maven"; Action={ $null = Install-Maven }}
    '10' = @{Label="🗄️ 仅安装 MySQL"; Action={ $null = Install-MySQL }}
    '11' = @{Label="🤖 仅安装 Android Studio + SDK 34+"; Action={ $null = Install-Android }}
    '12' = @{Label="📋 查看当前环境摘要"; Action={ Show-Summary }}
}

function Show-Menu {
    Write-Title
    Write-Host "  请选择要执行的操作:" -ForegroundColor $ColorInfo
    Write-Host ""
    foreach ($k in $menu.Keys) { Write-Host "    [$k]  $($menu[$k].Label)" -ForegroundColor $(if ($k -eq '1') { "Green" } else { $ColorMenu }) }
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
        # 选项 12 (Show-Summary) 不产生安装日志，跳过保存
        if ($choice -ne '12') { Save-Log }
        Wait-Key
    }
    else {
        Write-Host "`n  ❌ 无效选项，请重新选择。" -ForegroundColor $ColorError
        Write-AppendLog "  ❌ 无效选项: $choice"
        Start-Sleep -Seconds 1
    }
} while ($true)