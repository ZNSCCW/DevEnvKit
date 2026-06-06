<#
============================================================================
  🛠️  开发环境一键配置工具  v1.0
  支持: Python / Java / C/C++ / Node.js / Git / Docker 等
  适用于 Windows 10/11 (使用 winget 包管理器)
============================================================================
#>

# 要求管理员权限运行
if (-NOT ([System.Security.Principal.WindowsPrincipal] [System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "`n  [警告] 建议以管理员身份运行此脚本，否则部分安装可能失败。" -ForegroundColor Yellow
    Write-Host "  是否继续以非管理员身份运行? (Y/N): " -NoNewline -ForegroundColor Yellow
    $adminChoice = Read-Host
    if ($adminChoice -notmatch '^[Yy]$') {
        exit
    }
}

# 检查 winget 是否可用 (必须)
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "`n  ❌ 错误: 未检测到 winget 包管理器!" -ForegroundColor Red
    Write-Host "  winget 是 Windows 10 1809+ 自带的包管理工具。" -ForegroundColor Yellow
    Write-Host "  请确保您的 Windows 版本满足要求，或在 Microsoft Store 中安装 '应用安装程序'。" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  按任意键退出..." -ForegroundColor Gray
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
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor $ColorTitle
    Write-Host "  ║        🛠️   开 发 环 境 一 键 配 置 工 具   v1.0           ║" -ForegroundColor $ColorTitle
    Write-Host "  ║     Python · Java · C/C++ · Node.js · Git · Docker · ...    ║" -ForegroundColor $ColorTitle
    Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor $ColorTitle
    Write-Host ""
}

function Write-Step {
    param([string]$Message)
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "  [$timestamp] ▶ $Message" -ForegroundColor $ColorStep
    $script:installLog += "[$timestamp] ▶ $Message"
}

function Write-OK {
    param([string]$Message, [switch]$NoCount)
    Write-Host "              ✅ $Message" -ForegroundColor $ColorSuccess
    $script:installLog += "              ✅ $Message"
    if (-not $NoCount) {
        $script:completedSteps++
    }
}

function Write-Fail {
    param([string]$Message)
    Write-Host "              ❌ $Message" -ForegroundColor $ColorError
    $script:installLog += "              ❌ $Message"
}

function Write-Warn {
    param([string]$Message)
    Write-Host "              ⚠️  $Message" -ForegroundColor $ColorWarning
    $script:installLog += "              ⚠️  $Message"
}

function Write-Info {
    param([string]$Message)
    Write-Host "              ℹ️  $Message" -ForegroundColor $ColorInfo
}

# 检查某个命令是否已安装
function Test-CommandExists {
    param([string]$Command)
    try {
        $null = Get-Command $Command -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

# 获取已安装工具的版本号
# 安全: 使用脚本块 (& call operator) 替代 Invoke-Expression，防止命令注入
function Get-InstalledVersion {
    param([scriptblock]$VersionCommand)
    try {
        $output = & $VersionCommand 2>&1 | Select-Object -First 1
        $str = if ($output -is [string]) { $output } else { $output.ToString() }
        return $str.Trim()
    }
    catch {
        return "未知"
    }
}

# 版本比对提示：已有工具 → 展示当前版本 → 询问是否重新安装
function Request-Confirmation {
    param(
        [string]$ToolName,
        [string]$InstalledVersion,
        [string]$TargetVersionDesc
    )
    Write-Host ""
    Write-Warn "$ToolName 已安装 (当前版本: $InstalledVersion)"
    Write-Host "  ℹ️  脚本将安装版本: $TargetVersionDesc" -ForegroundColor $ColorInfo
    Write-Host "  ❓ 是否重新安装/升级? (Y=升级覆盖, N=跳过保留当前): " -NoNewline -ForegroundColor $ColorPrompt
    $answer = Read-Host
    if ($answer -match '^[Yy]$') {
        Write-Info "将重新安装/升级 $ToolName ..."
        return $true  # 继续安装
    }
    else {
        Write-Warn "已跳过 $ToolName (保留当前版本: $InstalledVersion)"
        return $false # 跳过
    }
}

# 等待 winget 安装完成 (仅使用 --id 安装，不接受额外自定义参数)
function Invoke-WingetInstall {
    param(
        [string]$PackageId,
        [string]$DisplayName
    )
    
    Write-Step "正在安装 $DisplayName ..."
    $result = winget install --id $PackageId --accept-source-agreements --accept-package-agreements 2>&1
    
    # 检查结果
    if ($LASTEXITCODE -eq 0 -or $result -match "已安装|已找到已安装|No applicable update found|already installed") {
        Write-OK "$DisplayName 安装成功 (或已安装)"
        return $true
    }
    else {
        Write-Fail "$DisplayName 安装失败"
        Write-Info "尝试详情: $result"
        return $false
    }
}

# 检测 MSVC 编译器 (cl.exe 默认不在 PATH 中，需用 vswhere 或检测安装目录)
function Test-MsvcExists {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vswhere) {
        $vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
        if ($vsPath) { return $true }
    }
    $msvcDirs = @(
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Professional\VC\Tools\MSVC",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Enterprise\VC\Tools\MSVC",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Professional\VC\Tools\MSVC",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Enterprise\VC\Tools\MSVC"
    )
    foreach ($d in $msvcDirs) {
        if (Test-Path $d) { return $true }
    }
    return $false
}

# 刷新 PATH 环境变量
function Update-SessionPath {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
}

# ========================== 安装模块 ==========================

function Install-Git {
    Write-Host "`n  ── 🔧 Git ──────────────────────────────────────────────" -ForegroundColor $ColorMenu
    if (Test-CommandExists "git") {
        $ver = Get-InstalledVersion -VersionCommand { git --version }
        $ver = $ver -replace 'git version ', ''
        $doInstall = Request-Confirmation -ToolName "Git" -InstalledVersion $ver -TargetVersionDesc "Git (winget 最新稳定版)"
        if (-not $doInstall) { $script:completedSteps++; return $false }
    }
    $result = Invoke-WingetInstall -PackageId "Git.Git" -DisplayName "Git"
    Update-SessionPath
    return $result
}

function Install-Python {
    Write-Host "`n  ── 🐍 Python ───────────────────────────────────────────" -ForegroundColor $ColorMenu
    if (Test-CommandExists "python") {
        $ver = Get-InstalledVersion -VersionCommand { python --version }
        $doInstall = Request-Confirmation -ToolName "Python" -InstalledVersion $ver -TargetVersionDesc "Python 3.12.x (最新小版本)"
        if (-not $doInstall) { $script:completedSteps++; return $false }
    }
    $result = Invoke-WingetInstall -PackageId "Python.Python.3.12" -DisplayName "Python 3.12"
    Update-SessionPath
    
    # 验证 pip (不计入总步骤)
    if (Test-CommandExists "pip") {
        Write-OK "pip 可用" -NoCount
    }
    else {
        Write-Warn "pip 未找到，请手动验证 Python 安装"
    }
    return $result
}

function Install-Java {
    Write-Host "`n  ── ☕ Java (JDK) ───────────────────────────────────────" -ForegroundColor $ColorMenu
    if (Test-CommandExists "java") {
        $ver = Get-InstalledVersion -VersionCommand { java -version 2>&1 }
        $doInstall = Request-Confirmation -ToolName "Java (JDK)" -InstalledVersion $ver -TargetVersionDesc "Eclipse Temurin JDK 21 (LTS)"
        if (-not $doInstall) { $script:completedSteps++; return $false }
    }
    
    # 使用 Eclipse Temurin JDK 21 (LTS)
    $result = Invoke-WingetInstall -PackageId "EclipseAdoptium.Temurin.21.JDK" -DisplayName "Eclipse Temurin JDK 21 (LTS)"
    Update-SessionPath
    
    # 设置 JAVA_HOME (不计入总步骤)
    try {
        $javaPath = ${env:JAVA_HOME}
        if (-not $javaPath) {
            $possiblePaths = @(
                "C:\Program Files\Eclipse Adoptium\jdk-21.0.0.35-hotspot\",
                "C:\Program Files\Eclipse Adoptium\jdk-21*\"
            )
            foreach ($p in $possiblePaths) {
                $found = Get-Item $p -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($found) {
                    [System.Environment]::SetEnvironmentVariable("JAVA_HOME", $found.FullName, "Machine")
                    Write-OK "JAVA_HOME 已设置为: $($found.FullName)" -NoCount
                    break
                }
            }
        }
    }
    catch {
        Write-Warn "JAVA_HOME 设置失败，请手动配置"
    }
    return $result
}

function Install-CPP {
    Write-Host "`n  ── ⚙️  C/C++ 开发工具 ──────────────────────────────────" -ForegroundColor $ColorMenu
    
    # 检测已有编译器
    $hasGCC = Test-CommandExists "gcc"
    $hasGPP = Test-CommandExists "g++"
    $hasClang = Test-CommandExists "clang"
    $hasMSVC = Test-MsvcExists
    $compilerFound = $false
    $somethingInstalled = $false
    
    if ($hasGCC -and $hasGPP) {
        $ver = Get-InstalledVersion -VersionCommand { gcc --version }
        $doInstall = Request-Confirmation -ToolName "MinGW/GCC" -InstalledVersion $ver -TargetVersionDesc "MinGW-w64 (BrechtSanders.WinLibs)"
        if (-not $doInstall) { $compilerFound = $true; $script:completedSteps++ }
    }
    elseif ($hasClang) {
        $ver = Get-InstalledVersion -VersionCommand { clang --version }
        $doInstall = Request-Confirmation -ToolName "Clang" -InstalledVersion $ver -TargetVersionDesc "MinGW-w64 (GCC/G++)"
        if (-not $doInstall) { $compilerFound = $true; $script:completedSteps++ }
    }
    elseif ($hasMSVC) {
        $ver = "MSVC (Visual Studio)"
        $doInstall = Request-Confirmation -ToolName "MSVC" -InstalledVersion $ver -TargetVersionDesc "MinGW-w64 (GCC/G++)"
        if (-not $doInstall) { $compilerFound = $true; $script:completedSteps++ }
    }
    
    if (-not $compilerFound) {
        Write-Step "正在安装 MinGW-w64 (GCC/G++) ..."
        Invoke-WingetInstall -PackageId "BrechtSanders.WinLibs" -DisplayName "MinGW-w64 (GCC/G++)"
        Update-SessionPath
        $somethingInstalled = $true
    }
    
    # 可选: 安装 CMake
    if (Test-CommandExists "cmake") {
        $cmakeVer = Get-InstalledVersion -VersionCommand { cmake --version }
        $doCmake = Request-Confirmation -ToolName "CMake" -InstalledVersion $cmakeVer -TargetVersionDesc "CMake (winget 最新版)"
        if ($doCmake) {
            Invoke-WingetInstall -PackageId "Kitware.CMake" -DisplayName "CMake"
            Update-SessionPath
            $somethingInstalled = $true
        }
    }
    else {
        Write-Step "正在安装 CMake ..."
        Invoke-WingetInstall -PackageId "Kitware.CMake" -DisplayName "CMake"
        Update-SessionPath
        $somethingInstalled = $true
    }
    
    return $somethingInstalled
}

function Install-NodeJS {
    Write-Host "`n  ── 🟢 Node.js ──────────────────────────────────────────" -ForegroundColor $ColorMenu
    if (Test-CommandExists "node") {
        $ver = Get-InstalledVersion -VersionCommand { node --version }
        $doInstall = Request-Confirmation -ToolName "Node.js" -InstalledVersion $ver -TargetVersionDesc "Node.js LTS (当前为 22.x)"
        if (-not $doInstall) { $script:completedSteps++; return $false }
    }
    $result = Invoke-WingetInstall -PackageId "OpenJS.NodeJS.LTS" -DisplayName "Node.js (LTS)"
    Update-SessionPath
    
    # 检查 npm (不计入总步骤)
    if (Test-CommandExists "npm") {
        try {
            $npmVer = (npm --version 2>&1 | Select-Object -First 1)
            Write-OK "npm 可用 (版本: $npmVer)" -NoCount
        }
        catch {
            Write-Warn "npm 已安装但执行异常，请手动验证"
        }
    }
    return $result
}

function Install-Docker {
    Write-Host "`n  ── 🐳 Docker ───────────────────────────────────────────" -ForegroundColor $ColorMenu
    if (Test-CommandExists "docker") {
        $ver = Get-InstalledVersion -VersionCommand { docker --version }
        $ver = $ver -replace 'Docker version ', ''
        $doInstall = Request-Confirmation -ToolName "Docker" -InstalledVersion $ver -TargetVersionDesc "Docker Desktop (winget 最新)"
        if (-not $doInstall) { $script:completedSteps++; return $false }
    }
    Write-Step "正在安装 Docker Desktop ..."
    Write-Info "注意: Docker Desktop 安装完成后需要重启系统。"
    $result = Invoke-WingetInstall -PackageId "Docker.DockerDesktop" -DisplayName "Docker Desktop"
    Update-SessionPath
    return $result
}

function Install-VSCode {
    Write-Host "`n  ── 📝 Visual Studio Code ───────────────────────────────" -ForegroundColor $ColorMenu
    if (Test-CommandExists "code") {
        $ver = Get-InstalledVersion -VersionCommand { code --version }
        $doInstall = Request-Confirmation -ToolName "VS Code" -InstalledVersion $ver -TargetVersionDesc "VS Code (最新稳定版)"
        if (-not $doInstall) { $script:completedSteps++; return $false }
    }
    $result = Invoke-WingetInstall -PackageId "Microsoft.VisualStudioCode" -DisplayName "Visual Studio Code"
    Update-SessionPath
    return $result
}

function Install-All {
    Write-Host "`n" -NoNewline
    Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor "Red"
    Write-Host "  ║         🚀  开 始 一 键 安 装 所 有 工 具                  ║" -ForegroundColor "Red"
    Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor "Red"
    
    $script:totalSteps = 7
    $script:completedSteps = 0
    
    $startTime = Get-Date
    
    Install-Git
    Install-Python
    Install-Java
    Install-CPP
    Install-NodeJS
    Install-Docker
    Install-VSCode
    
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalMinutes.ToString("F1")
    
    Write-Host "`n  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor $ColorSuccess
    if ($script:completedSteps -ge $script:totalSteps) {
        Write-Host "  ║        ✅  所有工具已就绪，无需额外安装!                    ║" -ForegroundColor $ColorSuccess
    }
    else {
        Write-Host "  ║              🎉  安装流程完成!                              ║" -ForegroundColor $ColorSuccess
    }
    Write-Host "  ║              就绪: $script:completedSteps / 耗时: ${duration}分钟                          ║" -ForegroundColor $ColorSuccess
    Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor $ColorSuccess
    
    Show-Summary
    Invoke-Reboot
}

# ========================== 显示摘要 ==========================
function Show-Summary {
    Write-Host "`n  ── 📋 当前环境检测结果 ──────────────────────────────────" -ForegroundColor $ColorMenu
    Update-SessionPath
    
    # 注意: Cmd 必须是 ScriptBlock，不能是字符串
    # 若用 "git --version" 字符串配合 & 操作符，PowerShell 会将整个字符串当命令名查找，导致失败
    $tools = @(
        @{Name="Git";      Cmd={ git --version }},
        @{Name="Python";   Cmd={ python --version }},
        @{Name="pip";      Cmd={ pip --version }},
        @{Name="Java";     Cmd={ java -version 2>&1 }},
        @{Name="javac";    Cmd={ javac --version }},
        @{Name="GCC";      Cmd={ gcc --version }},
        @{Name="G++";      Cmd={ g++ --version }},
        @{Name="Node.js";  Cmd={ node --version }},
        @{Name="npm";      Cmd={ npm --version }},
        @{Name="Docker";   Cmd={ docker --version }},
        @{Name="CMake";    Cmd={ cmake --version }},
        @{Name="VS Code";  Cmd={ code --version }}
    )
    
    foreach ($tool in $tools) {
        try {
            $output = & $tool.Cmd 2>&1 | Select-Object -First 1
            $str = if ($output -is [string]) { $output } else { $output.ToString() }
            Write-Host "  ✅ $($tool.Name.PadRight(10)) : $str" -ForegroundColor $ColorSuccess
        }
        catch {
            Write-Host "  ❌ $($tool.Name.PadRight(10)) : 未安装" -ForegroundColor $ColorError
        }
    }
}

function Invoke-Reboot {
    Write-Host "`n  ⚠️  部分工具 (如 Docker) 安装后需要重启系统才能完全生效。" -ForegroundColor $ColorWarning
    Write-Host "  是否立即重启? (Y/N): " -NoNewline -ForegroundColor $ColorPrompt
    $rebootChoice = Read-Host
    if ($rebootChoice -match '^[Yy]$') {
        Write-Host "  ⚠️  即将重启系统，请先保存所有未保存的工作!" -ForegroundColor $ColorWarning
        Write-Host "  按任意键确认重启 (或 Ctrl+C 取消)..." -ForegroundColor $ColorWarning
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Restart-Computer
    }
}

function Save-Log {
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    $logPath = Join-Path $scriptDir "install_log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    $script:installLog | Out-File -FilePath $logPath -Encoding UTF8
    Write-Host "`n  📄 安装日志已保存到: $logPath" -ForegroundColor $ColorInfo
}

# ========================== 主菜单 ==========================
function Show-Menu {
    Write-Title
    
    Write-Host "  请选择要执行的操作:" -ForegroundColor $ColorInfo
    Write-Host ""
    Write-Host "    [1]  🚀 一键安装全部 (推荐)" -ForegroundColor "Green"
    Write-Host "    [2]  🔧 仅安装 Git" -ForegroundColor $ColorMenu
    Write-Host "    [3]  🐍 仅安装 Python" -ForegroundColor $ColorMenu
    Write-Host "    [4]  ☕ 仅安装 Java (JDK)" -ForegroundColor $ColorMenu
    Write-Host "    [5]  ⚙️  仅安装 C/C++ 开发工具 (MinGW + CMake)" -ForegroundColor $ColorMenu
    Write-Host "    [6]  🟢 仅安装 Node.js" -ForegroundColor $ColorMenu
    Write-Host "    [7]  🐳 仅安装 Docker" -ForegroundColor $ColorMenu
    Write-Host "    [8]  📝 仅安装 VS Code" -ForegroundColor $ColorMenu
    Write-Host "    [9]  📋 查看当前环境摘要" -ForegroundColor $ColorMenu
    Write-Host "    [0]  ❌ 退出" -ForegroundColor $ColorMenu
    Write-Host ""
    Write-Host "  ───────────────────────────────────────────────────────────" -ForegroundColor $ColorTitle
    Write-Host "  请输入选项 [0-9]: " -NoNewline -ForegroundColor $ColorPrompt
}

# ========================== 主循环 ==========================
do {
    Show-Menu
    $choice = Read-Host
    
    Clear-Host
    Write-Title
    
    switch ($choice) {
        '1' { 
            Install-All 
            Save-Log
            Write-Host "`n  按任意键返回主菜单..." -ForegroundColor $ColorInfo
            $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        '2' { 
            $actionTaken = Install-Git
            if ($actionTaken) { Update-SessionPath }
            Write-Host "`n  ✅ Git — 操作完成。" -ForegroundColor $ColorSuccess
            Write-Host "  按任意键返回主菜单..." -ForegroundColor $ColorInfo
            $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        '3' { 
            $actionTaken = Install-Python
            if ($actionTaken) { Update-SessionPath }
            Write-Host "`n  ✅ Python — 操作完成。" -ForegroundColor $ColorSuccess
            Write-Host "  按任意键返回主菜单..." -ForegroundColor $ColorInfo
            $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        '4' { 
            $actionTaken = Install-Java
            if ($actionTaken) { Update-SessionPath }
            Write-Host "`n  ✅ Java — 操作完成。" -ForegroundColor $ColorSuccess
            Write-Host "  按任意键返回主菜单..." -ForegroundColor $ColorInfo
            $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        '5' { 
            $actionTaken = Install-CPP
            if ($actionTaken) { Update-SessionPath }
            Write-Host "`n  ✅ C/C++ 开发工具 — 操作完成。" -ForegroundColor $ColorSuccess
            Write-Host "  按任意键返回主菜单..." -ForegroundColor $ColorInfo
            $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        '6' { 
            $actionTaken = Install-NodeJS
            if ($actionTaken) { Update-SessionPath }
            Write-Host "`n  ✅ Node.js — 操作完成。" -ForegroundColor $ColorSuccess
            Write-Host "  按任意键返回主菜单..." -ForegroundColor $ColorInfo
            $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        '7' { 
            $actionTaken = Install-Docker
            if ($actionTaken) { Update-SessionPath }
            Write-Host "`n  ✅ Docker — 操作完成。" -ForegroundColor $ColorSuccess
            Write-Host "  按任意键返回主菜单..." -ForegroundColor $ColorInfo
            $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        '8' { 
            $actionTaken = Install-VSCode
            if ($actionTaken) { Update-SessionPath }
            Write-Host "`n  ✅ VS Code — 操作完成。" -ForegroundColor $ColorSuccess
            Write-Host "  按任意键返回主菜单..." -ForegroundColor $ColorInfo
            $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        '9' { 
            Show-Summary
            Write-Host "`n  按任意键返回主菜单..." -ForegroundColor $ColorInfo
            $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        '0' { 
            Write-Host "`n  👋 再见! 祝你编码愉快~" -ForegroundColor $ColorTitle
            exit
        }
        default {
            Write-Host "`n  ❌ 无效选项，请重新选择。" -ForegroundColor $ColorError
            Start-Sleep -Seconds 1
        }
    }
} while ($true)