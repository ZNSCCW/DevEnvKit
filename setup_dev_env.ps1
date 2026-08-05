<#
============================================================================
  🛠️  开发环境一键配置工具  v1.1
  支持: Python / Java / C/C++ / Node.js / Git / Docker 等
  适用于 Windows 10/11 (使用 winget 包管理器)
============================================================================
#>

# 要求管理员权限运行
if (-NOT ([System.Security.Principal.WindowsPrincipal] [System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "`n  [警告] 建议以管理员身份运行此脚本，否则部分安装可能失败。" -ForegroundColor Yellow
    Write-Host "  是否继续以非管理员身份运行? (Y/N): " -NoNewline -ForegroundColor Yellow
    if ((Read-Host) -notmatch '^[Yy]$') { exit }
}

# 检查 winget 是否可用 (必须)
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "`n  ❌ 错误: 未检测到 winget 包管理器!" -ForegroundColor Red
    Write-Host "  winget 是 Windows 10 1809+ 自带的包管理工具。" -ForegroundColor Yellow
    Write-Host "  请确保您的 Windows 版本满足要求，或在 Microsoft Store 中安装 '应用安装程序'。" -ForegroundColor Yellow
    Write-Host "`n  按任意键退出..." -ForegroundColor Gray
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# 控制台编码设置
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$host.UI.RawUI.WindowTitle = "开发环境一键配置工具"

# 全局变量
$script:installLog = @()
$script:totalSteps = 0
$script:completedSteps = 0

# ========================== 颜色主题 ==========================
$ColorTitle   = "Cyan"
$ColorSuccess = "Green"
$ColorError   = "Red"
$ColorWarning = "Yellow"
$ColorInfo    = "White"
$ColorMenu    = "Magenta"
$ColorPrompt  = "Cyan"
$ColorStep    = "Blue"

# ========================== 辅助函数 ==========================
function Write-Title {
    Clear-Host
    Write-Host @"

  ╔══════════════════════════════════════════════════════════════╗
  ║        🛠️   开 发 环 境 一 键 配 置 工 具   v1.1           ║
  ║     Python · Java · C/C++ · Node.js · Git · Docker · ...    ║
  ╚══════════════════════════════════════════════════════════════╝

"@
}

function Write-Step { param([string]$m); $t = Get-Date -Format "HH:mm:ss"; Write-Host "  [$t] ▶ $m" -ForegroundColor $ColorStep; $script:installLog += "[$t] ▶ $m" }
function Write-OK   { param([string]$m, [switch]$NoCount); Write-Host "              ✅ $m" -ForegroundColor $ColorSuccess; $script:installLog += "              ✅ $m"; if (-not $NoCount) { $script:completedSteps++ } }
function Write-Fail { param([string]$m); Write-Host "              ❌ $m" -ForegroundColor $ColorError;   $script:installLog += "              ❌ $m" }
function Write-Warn { param([string]$m); Write-Host "              ⚠️  $m" -ForegroundColor $ColorWarning; $script:installLog += "              ⚠️  $m" }
function Write-Info { param([string]$m); Write-Host "              ℹ️  $m" -ForegroundColor $ColorInfo }

function Test-CommandExists {
    param([string]$Command)
    try { $null = Get-Command $Command -ErrorAction Stop; return $true } catch { return $false }
}

# 获取已安装工具的版本号 (安全: 使用脚本块替代 Invoke-Expression)
function Get-InstalledVersion {
    param([scriptblock]$VersionCommand)
    try { $o = & $VersionCommand 2>&1 | Select-Object -First 1; return "$o".Trim() } catch { return "未知" }
}

# 版本比对提示：已有工具 → 展示当前版本 → 询问是否重新安装
function Request-Confirmation {
    param([string]$ToolName, [string]$InstalledVersion, [string]$TargetVersionDesc)
    Write-Host ""
    Write-Warn "$ToolName 已安装 (当前版本: $InstalledVersion)"
    Write-Info "脚本将安装版本: $TargetVersionDesc"
    Write-Host "  ❓ 是否重新安装/升级? (Y=升级覆盖, N=跳过保留当前): " -NoNewline -ForegroundColor $ColorPrompt
    if ((Read-Host) -match '^[Yy]$') { Write-Info "将重新安装/升级 $ToolName ..."; return $true }
    Write-Warn "已跳过 $ToolName (保留当前版本: $InstalledVersion)"; return $false
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
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
}

# 通用安装包装器：检测 → 确认 → 安装 → 刷新PATH (消除 switch 中的重复代码)
function Invoke-Installer {
    param([string]$ToolName, [string]$ExeName, [string]$PackageId, [string]$DisplayName, [string]$TargetDesc, [scriptblock]$VersionCmd, [string]$VerReplace)
    Write-Host "`n  ── $ToolName ──────────────────────────────────────────────" -ForegroundColor $ColorMenu
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
            foreach ($p in "C:\Program Files\Eclipse Adoptium\jdk-21.0.0.35-hotspot\", "C:\Program Files\Eclipse Adoptium\jdk-21*\") {
                $f = Get-Item $p -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($f) { [System.Environment]::SetEnvironmentVariable("JAVA_HOME", $f.FullName, "Machine"); Write-OK "JAVA_HOME 已设置为: $($f.FullName)" -NoCount; break }
            }
        }
    } catch { Write-Warn "JAVA_HOME 设置失败，请手动配置" }
    return $r
}

function Install-CPP {
    Write-Host "`n  ── ⚙️  C/C++ 开发工具 ──────────────────────────────────" -ForegroundColor $ColorMenu
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
        if ($doCmake) { Invoke-WingetInstall -PackageId "Kitware.CMake" -DisplayName "CMake"; Update-Path; $somethingInstalled = $true }
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

function Install-All {
    Write-Host "`n  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor "Red"
    Write-Host "  ║         🚀  开 始 一 键 安 装 所 有 工 具                  ║" -ForegroundColor "Red"
    Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor "Red"
    $script:totalSteps = 7; $script:completedSteps = 0
    $startTime = Get-Date
    Install-Git; Install-Python; Install-Java; Install-CPP; Install-NodeJS; Install-Docker; Install-VSCode
    $dur = ((Get-Date) - $startTime).TotalMinutes.ToString("F1")
    Write-Host "`n  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor $ColorSuccess
    Write-Host "  ║        $(if ($script:completedSteps -ge $script:totalSteps) { '✅  所有工具已就绪，无需额外安装!' } else { '🎉  安装流程完成!' })                              ║" -ForegroundColor $ColorSuccess
    Write-Host "  ║              就绪: $script:completedSteps / 耗时: ${dur}分钟                          ║" -ForegroundColor $ColorSuccess
    Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor $ColorSuccess
    Show-Summary
    Invoke-Reboot
}

# ========================== 显示摘要 ==========================
function Show-Summary {
    Write-Host "`n  ── 📋 当前环境检测结果 ──────────────────────────────────" -ForegroundColor $ColorMenu
    Update-Path
    $tools = @(
        @{L="Git";      C={ git --version }},
        @{L="Python";   C={ python --version }},
        @{L="pip";      C={ pip --version }},
        @{L="Java";     C={ java -version 2>&1 }},
        @{L="javac";    C={ javac --version }},
        @{L="GCC";      C={ gcc --version }},
        @{L="G++";      C={ g++ --version }},
        @{L="Node.js";  C={ node --version }},
        @{L="npm";      C={ npm --version }},
        @{L="Docker";   C={ docker --version }},
        @{L="CMake";    C={ cmake --version }},
        @{L="VS Code";  C={ code --version }}
    )
    foreach ($t in $tools) {
        try { $v = & $t.C 2>&1 | Select-Object -First 1; Write-Host "  ✅ $($t.L.PadRight(10)) : $v" -ForegroundColor $ColorSuccess }
        catch { Write-Host "  ❌ $($t.L.PadRight(10)) : 未安装" -ForegroundColor $ColorError }
    }
}

function Invoke-Reboot {
    Write-Host "`n  ⚠️  部分工具 (如 Docker) 安装后需要重启系统才能完全生效。" -ForegroundColor $ColorWarning
    Write-Host "  是否立即重启? (Y/N): " -NoNewline -ForegroundColor $ColorPrompt
    if ((Read-Host) -match '^[Yy]$') {
        Write-Host "  ⚠️  即将重启系统，请先保存所有未保存的工作!" -ForegroundColor $ColorWarning
        Write-Host "  按任意键确认重启 (或 Ctrl+C 取消)..." -ForegroundColor $ColorWarning
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Restart-Computer
    }
}

function Save-Log {
    $dir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    $path = Join-Path $dir "install_log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    $script:installLog | Out-File -FilePath $path -Encoding UTF8
    Write-Host "`n  📄 安装日志已保存到: $path" -ForegroundColor $ColorInfo
}

# 等待按键
function Pause-Key { Write-Host "`n  按任意键返回主菜单..." -ForegroundColor $ColorInfo; $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") }

# ========================== 主菜单 ==========================
$menu = [ordered]@{
    '1' = @{Label="🚀 一键安装全部 (推荐)"; Action={ Install-All; Save-Log }}
    '2' = @{Label="🔧 仅安装 Git"; Action={ $null = Install-Git }}
    '3' = @{Label="🐍 仅安装 Python"; Action={ $null = Install-Python }}
    '4' = @{Label="☕ 仅安装 Java (JDK)"; Action={ $null = Install-Java }}
    '5' = @{Label="⚙️  仅安装 C/C++ 开发工具 (MinGW + CMake)"; Action={ $null = Install-CPP }}
    '6' = @{Label="🟢 仅安装 Node.js"; Action={ $null = Install-NodeJS }}
    '7' = @{Label="🐳 仅安装 Docker"; Action={ $null = Install-Docker }}
    '8' = @{Label="📝 仅安装 VS Code"; Action={ $null = Install-VSCode }}
    '9' = @{Label="📋 查看当前环境摘要"; Action={ Show-Summary }}
}

function Show-Menu {
    Write-Title
    Write-Host "  请选择要执行的操作:" -ForegroundColor $ColorInfo
    Write-Host ""
    foreach ($k in $menu.Keys) { Write-Host "    [$k]  $($menu[$k].Label)" -ForegroundColor $(if ($k -eq '1') { "Green" } else { $ColorMenu }) }
    Write-Host "    [0]  ❌ 退出" -ForegroundColor $ColorMenu
    Write-Host "`n  ───────────────────────────────────────────────────────────" -ForegroundColor $ColorTitle
    Write-Host "  请输入选项 [0-9]: " -NoNewline -ForegroundColor $ColorPrompt
}

# ========================== 主循环 ==========================
do {
    Show-Menu
    $choice = Read-Host
    Clear-Host
    Write-Title
    
    if ($choice -eq '0') { Write-Host "`n  👋 再见! 祝你编码愉快~" -ForegroundColor $ColorTitle; exit }
    elseif ($menu.ContainsKey($choice)) {
        & $menu[$choice].Action
        Pause-Key
    }
    else {
        Write-Host "`n  ❌ 无效选项，请重新选择。" -ForegroundColor $ColorError
        Start-Sleep -Seconds 1
    }
} while ($true)