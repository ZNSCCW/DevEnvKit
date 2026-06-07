<#
============================================================================
  🛠️  开发环境一键配置工具  v1.2
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
$script:installLog = @()
$script:totalSteps = 0
# completedSteps 计数"已就绪"工具项（已安装或跳过），非"新安装数"
$script:completedSteps = 0

# ========================== 实时日志 ==========================
# 初始化实时日志文件（防崩溃丢失）
$script:logDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$script:logFilePath = Join-Path $script:logDir "install_log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
"========== 开发环境配置日志 [$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] ==========" | Out-File -FilePath $script:logFilePath -Encoding UTF8

function Write-AppendLog {
    param([string]$Message)
    $script:installLog += $Message
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
  ║        🛠️   开 发 环 境 一 键 配 置 工 具   v1.2           ║
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
        $releaseInfo = Invoke-RestMethod -Uri $releaseApi -ErrorAction Stop
        $asset = $releaseInfo.assets | Where-Object { $_.name -like "*.msixbundle" } | Select-Object -First 1
        
        if ($asset) {
            Write-Info "下载: $($asset.name) ($([math]::Round($asset.size/1MB, 1)) MB)"
            $installerPath = Join-Path $tempDir $asset.name
            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $installerPath -ErrorAction Stop
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
    Write-Host "  按任意键退出..." -ForegroundColor Gray
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
    exit 1
}

# 主流程启动前检查 winget 是否可用
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Install-Winget
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
    
    if ($compilerFound) {
        $doCompilerInstall = Request-Confirmation -ToolName "C/C++ 编译器" -InstalledVersion ($compilerDesc -join "; ") `
            -TargetVersionDesc "MinGW-w64 (GCC/G++)"
        if (-not $doCompilerInstall) { $script:completedSteps++ }
    }
    
    if ($doCompilerInstall) {
        Write-Step $(if ($compilerFound) { "正在安装/升级 MinGW-w64 (GCC/G++) ..." } else { "未检测到 C/C++ 编译器，正在安装 MinGW-w64 (GCC/G++) ..." })
        $mingwInstalled = $false
        foreach ($e in @(@{Id="WinLibs.GCC"; Name="WinLibs GCC"}, @{Id="MSYS2.MSYS2"; Name="MSYS2 (含 MinGW-w64)"})) {
            $mingwInstalled = Invoke-WingetInstall -PackageId $e.Id -DisplayName $e.Name
            if ($mingwInstalled) {
                if ($e.Id -eq "MSYS2.MSYS2" -and (Test-Path "C:\msys64\mingw64\bin")) {
                    $curPath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
                    if ($curPath -notmatch [regex]::Escape("C:\msys64\mingw64\bin")) {
                        [System.Environment]::SetEnvironmentVariable("Path", "$curPath;C:\msys64\mingw64\bin", "Machine")
                        Write-OK "已追加 MSYS2 MinGW 路径到系统 PATH" -NoCount
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
        else { $script:completedSteps++ }
    } else {
        Invoke-WingetInstall -PackageId "Kitware.CMake" -DisplayName "CMake"; Update-Path; $somethingInstalled = $true
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
        if (-not (Request-Confirmation -ToolName "Maven" -InstalledVersion $ver -TargetDesc "Apache Maven 3.x (winget 最新版)")) {
            $script:completedSteps++; return $false
        }
    }
    $r = Invoke-WingetInstall -PackageId "Apache.Maven.3" -DisplayName "Apache Maven 3"
    if ($r) { Update-Path }
    # 设置 MAVEN_HOME
    try {
        $mavenHomeFound = $false
        $mavenPaths = @("C:\Program Files\Apache\Maven\", "C:\Program Files (x86)\Apache\Maven\")
        foreach ($base in $mavenPaths) {
            $found = Get-ChildItem $base -Directory -Filter "apache-maven-*" -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
            if ($found) {
                [System.Environment]::SetEnvironmentVariable("MAVEN_HOME", $found.FullName, "Machine")
                Write-OK "MAVEN_HOME 已设置为: $($found.FullName)" -NoCount
                $mavenHomeFound = $true; break
            }
        }
        # 回退: 从 mvn 命令路径推导 MAVEN_HOME
        if (-not $mavenHomeFound) {
            $mvnCmdPath = (Get-Command mvn -ErrorAction SilentlyContinue).Source
            if ($mvnCmdPath) {
                $mvnBinDir = Split-Path -Parent $mvnCmdPath
                $mvnHome = Split-Path -Parent $mvnBinDir
                if ($mvnHome -and (Test-Path $mvnHome)) {
                    [System.Environment]::SetEnvironmentVariable("MAVEN_HOME", $mvnHome, "Machine")
                    Write-OK "MAVEN_HOME 已从 mvn 路径推导: $mvnHome" -NoCount
                }
            }
        }
    } catch { Write-Warn "MAVEN_HOME 设置失败，请手动配置" }
    return $r
}

function Install-MySQL {
    Write-Host "`n  ── 🗄️  MySQL ─────────────────────────────────────────────" -ForegroundColor $ColorMenu
    Write-AppendLog "`n  ── MySQL ──"
    if (Test-CommandExists "mysql") {
        $ver = Get-InstalledVersion { mysql --version }
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

function Install-All {
    Write-Host "`n  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor "Red"
    Write-Host "  ║         🚀  开 始 一 键 安 装 所 有 工 具                  ║" -ForegroundColor "Red"
    Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor "Red"
    Write-AppendLog "`n  ╔══════════════════════════════════════════════╗"
    Write-AppendLog "  ║           一键安装所有工具开始               ║"
    Write-AppendLog "  ╚══════════════════════════════════════════════╝"
    # totalSteps=10: 9 个菜单项中 C/C++ 包含编译器+CMake 两个子项各贡献 1 次计数
    $script:totalSteps = 10; $script:completedSteps = 0
    $startTime = Get-Date
    Install-Git; Install-Python; Install-Java; Install-CPP; Install-NodeJS; Install-Docker; Install-VSCode; Install-Maven; Install-MySQL
    $dur = ((Get-Date) - $startTime).TotalMinutes.ToString("F1")
    Write-Host "`n  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor $ColorSuccess
    Write-Host "  ║        $(if ($script:completedSteps -ge $script:totalSteps) { '✅  所有工具已就绪，无需额外安装!' } else { '🎉  安装流程完成!' })                              ║" -ForegroundColor $ColorSuccess
    Write-Host "  ║              就绪: $script:completedSteps / 耗时: ${dur}分钟                          ║" -ForegroundColor $ColorSuccess
    Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor $ColorSuccess
    Write-AppendLog "  ╔══════════════════════════════════════════════╗"
    Write-AppendLog "  ║        安装流程完成! 就绪: $script:completedSteps / 耗时: ${dur}分钟         ║"
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
        @{L="MySQL";    C={ mysql --version }},
        @{L="CMake";    C={ cmake --version }},
        @{L="VS Code";  C={ code --version }}
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
    $oldLogs = Get-ChildItem -Path $LogDir -Filter $pattern -File -ErrorAction SilentlyContinue |
               Sort-Object LastWriteTime -Descending |
               Select-Object -Skip 10
    if ($oldLogs) {
        $oldLogs | Remove-Item -Force -ErrorAction SilentlyContinue
        Write-Info "已清理 $(@($oldLogs).Count) 个旧日志文件"
    }
}

function Save-Log {
    $dir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    Clear-OldLogs -LogDir $dir
    Write-Host "`n  📄 实时日志已保存到: $script:logFilePath" -ForegroundColor $ColorInfo
}

# 等待按键
function Wait-Key {
    Write-Host "`n  按 Enter 返回主菜单..." -ForegroundColor $ColorInfo
    $null = Read-Host
}

# ========================== 主菜单 ==========================
$menu = [ordered]@{
    '1'  = @{Label="🚀 一键安装全部 (推荐)"; Action={ Install-All }}
    '2'  = @{Label="🔧 仅安装 Git"; Action={ $null = Install-Git }}
    '3'  = @{Label="🐍 仅安装 Python"; Action={ $null = Install-Python }}
    '4'  = @{Label="☕ 仅安装 Java (JDK)"; Action={ $null = Install-Java }}
    '5'  = @{Label="⚙️  仅安装 C/C++ 开发工具 (MinGW + CMake)"; Action={ $null = Install-CPP }}
    '6'  = @{Label="🟢 仅安装 Node.js"; Action={ $null = Install-NodeJS }}
    '7'  = @{Label="🐳 仅安装 Docker"; Action={ $null = Install-Docker }}
    '8'  = @{Label="📝 仅安装 VS Code"; Action={ $null = Install-VSCode }}
    '9'  = @{Label="🏗️  仅安装 Maven"; Action={ $null = Install-Maven }}
    '10' = @{Label="🗄️  仅安装 MySQL"; Action={ $null = Install-MySQL }}
    '11' = @{Label="📋 查看当前环境摘要"; Action={ Show-Summary }}
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
    Clear-Host
    Write-Title
    
    if ($choice -eq '0') {
        Write-Host "`n  👋 再见! 祝你编码愉快~" -ForegroundColor $ColorTitle
        Write-AppendLog "  👋 用户退出脚本"
        exit
    }
    elseif ($menu.ContainsKey($choice)) {
        Write-AppendLog "  📌 用户选择: [$choice]"
        & $menu[$choice].Action
        # 选项 11 (Show-Summary) 不产生安装日志，跳过保存
        if ($choice -ne '11') { Save-Log }
        Wait-Key
    }
    else {
        Write-Host "`n  ❌ 无效选项，请重新选择。" -ForegroundColor $ColorError
        Write-AppendLog "  ❌ 无效选项: $choice"
        Start-Sleep -Seconds 1
    }
} while ($true)