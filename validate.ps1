# 验证 setup_dev_env.ps1 语法和逻辑健全性
$ErrorActionPreference = "Stop"
$scriptPath = Join-Path $PSScriptRoot "setup_dev_env.ps1"

Write-Host "`n  ═══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "    setup_dev_env.ps1 代码审查 (精简版 v1.3)" -ForegroundColor Cyan
Write-Host "  ═══════════════════════════════════════════`n" -ForegroundColor Cyan

# === 1. 语法检查 ===
Write-Host "  [1/6] 语法检查..." -ForegroundColor White
$tokens = @()
$errors = @()
$ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$errors)
if ($errors.Count -eq 0) {
    Write-Host "  ✅ 语法: 通过 (0 错误)" -ForegroundColor Green
} else {
    Write-Host "  ❌ 语法: 发现 $($errors.Count) 个错误" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host "     - $($_.Message)" -ForegroundColor Red }
    exit 1
}

# 关键：PowerShell 5.1 的 Get-Content 默认 ANSI(GBK) 解码，UTF-8 无 BOM 文件会错位——
# 必须显式 -Encoding UTF8（否则 ^function 捕获组提取的函数名会错乱）
$content = Get-Content $scriptPath -Raw -Encoding UTF8
$lineCount = ($content -split "`n").Count

# === 2. 结构完整性检查 ===
Write-Host "`n  [2/6] 结构完整性..." -ForegroundColor White
$funcCount = [regex]::Matches($content, '(?m)^function \w+').Count
$structuralChecks = @(
    @{Name="函数声明完整性"; Pass=($content -match "function Write-Title" -and 
        $content -match "function Install-All" -and 
        $content -match "function Show-Menu")},
    @{Name="主循环 do..while"; Pass=($content -match 'do \{' -and $content -match '\} while \(\$true\)')},
    @{Name="菜单字典 `$menu"; Pass=($content -match '\$menu\s*=\s*\[ordered\]@\{' -and $content -match "menu\.Contains")},
    @{Name="通用安装包装器 Invoke-Installer"; Pass=($content -match "function Invoke-Installer")},
    @{Name="winget 自动安装 Install-Winget"; Pass=($content -match "function Install-Winget" -and $content -match "Add-AppxPackage")}
)

foreach ($c in $structuralChecks) {
    if ($c.Pass) {
        Write-Host "  ✅ $($c.Name)" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $($c.Name)" -ForegroundColor Red
    }
}

# === 3. 关键代码模式检查 ===
Write-Host "`n  [3/6] 关键代码模式..." -ForegroundColor White
$patternChecks = @(
    @{Name="completedSteps++ 存在"; Pass=($content -match '\$script:completedSteps\+\+')},
    @{Name="Request-Confirmation 确认机制"; Pass=($content -match "function Request-Confirmation")},
    @{Name="Get-InstalledVersion 安全脚本块"; Pass=($content -match "function Get-InstalledVersion" -and $content -match '& \$VersionCommand')},
    @{Name="Invoke-Installer 通用包装器"; Pass=($content -match "function Invoke-Installer")},
    @{Name="winget --disable-interactivity"; Pass=($content -match '--disable-interactivity')},
    @{Name="winget 网络错误检测"; Pass=($content -match '0x80072efd|0x80072ee7|0x80072f8f')},
    @{Name="Wait-Key 统一等待按键"; Pass=($content -match "function Wait-Key")},
    @{Name="UTF8 编码设置"; Pass=($content -match 'OutputEncoding.*UTF8')},
    @{Name="管理员权限检查"; Pass=($content -match 'WindowsPrincipal')},
    @{Name="winget 可用性检查"; Pass=($content -match 'Get-Command winget')},
    @{Name="JAVA_HOME 设置"; Pass=($content -match 'JAVA_HOME')},
    @{Name="MAVEN_HOME 设置"; Pass=($content -match 'MAVEN_HOME')},
    @{Name="安装日志保存"; Pass=($content -match 'Save-Log|install_log_')},
    @{Name="MSYS2 提供 MinGW-w64"; Pass=($content -match "MSYS2.MSYS2")},
    @{Name="MSYS2 PATH 手动追加"; Pass=($content -match "msys64\\\\mingw64\\\\bin" -or $content -match 'msys64\\mingw64\\bin')},
    @{Name="编译器独立检测 ArrayList"; Pass=($content -match "ArrayList")},
    @{Name="版本选择 Select-Version"; Pass=($content -match "function Select-Version" -and $content -match "JDK 8|3.11|Node.js 20")},
    @{Name="下载进度 Download-WithProgress"; Pass=($content -match "function Download-WithProgress" -and $content -match "Write-Progress")},
    @{Name="大小格式化 Format-Size"; Pass=($content -match "function Format-Size" -and $content -match "1GB")},
    @{Name="winget 退出码解释 Get-WingetExitHint"; Pass=($content -match "function Get-WingetExitHint" -and $content -match "0x8A150014")},
    @{Name="Maven 阿里云镜像回退"; Pass=($content -match "mirrors\.aliyun\.com")},
    @{Name="下载停滞检测"; Pass=($content -match "StallSeconds" -and $content -match "停滞")},
    @{Name="下载自动重试"; Pass=($content -match "Retries" -and $content -match "重试")},
    @{Name="断点续传 Range"; Pass=($content -match "RangeHeaderValue" -and $content -match "PartialContent" -and $content -match "Append")},
    @{Name="代理感知环境变量"; Pass=($content -match "HTTPS_PROXY" -and $content -match "WebProxy")},
    @{Name="版本切换 Switch-JavaVersion"; Pass=($content -match "function Switch-JavaVersion" -and $content -match "Set-JavaEnv")},
    @{Name="PATH 长度保护"; Pass=($content -match "function Add-ToPath" -and $content -match "2047")},
    @{Name="%JAVA_HOME% 变量引用"; Pass=($content -match '%JAVA_HOME%\\bin')},
    @{Name="注册表残留清理"; Pass=($content -match "function Clear-JavaRegistry" -and $content -match "JavaSoft")},
    @{Name="架构检测"; Pass=($content -match "function Get-OSArch" -and $content -match "PROCESSOR_ARCHITECTURE")},
    @{Name="Checksum 校验"; Pass=($content -match "ExpectedHash" -and $content -match "Get-FileHash")},
    @{Name="Python 版本切换"; Pass=($content -match "function Switch-PythonVersion" -and $content -match "Python3\\d\+")},
    @{Name="安装位置查看"; Pass=($content -match "function Show-InstallLocations" -and $content -match "Get-Command")},
    @{Name="卸载功能"; Pass=($content -match "function Uninstall-Tool" -and $content -match "winget uninstall")},
    @{Name="配置文件 devkit.conf"; Pass=($content -match "function Load-Config" -and $content -match "devkit.conf")}
)

$allPatternsPass = $true
foreach ($c in $patternChecks) {
    if ($c.Pass) {
        Write-Host "  ✅ $($c.Name)" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $($c.Name)" -ForegroundColor Red
        $allPatternsPass = $false
    }
}

# === 4. 安全审计 ===
Write-Host "`n  [4/6] 安全审计..." -ForegroundColor White
$dangerPatterns = @(
    @{Name="无 Invoke-Expression 实际调用"; Pattern="Invoke-Expression"; Should=$true},
    @{Name="无 iex 别名"; Pattern="\biex\b"; Should=$false},
    @{Name="无 Start-Process -FilePath cmd"; Pattern="Start-Process.*cmd"; Should=$false},
    @{Name="Remove-Item 仅用于临时清理"; Pattern='Remove-Item.*-Recurse.*-Force.*\$tempDir'; Should=$true},
    @{Name="无 Set-ExecutionPolicy 修改"; Pattern="Set-ExecutionPolicy"; Should=$false}
)

$allSafe = $true
foreach ($d in $dangerPatterns) {
    $found = $content -match $d.Pattern
    if ($found -eq $d.Should) {
        Write-Host "  ✅ $($d.Name)" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $($d.Name) — 检测到危险模式: $($d.Pattern)" -ForegroundColor Red
        $allSafe = $false
    }
}

# === 5. 工具覆盖范围 ===
Write-Host "`n  [5/6] 工具覆盖范围..." -ForegroundColor White
$tools = @(
    @{Name="Git";      Install="Git.Git";                       Summary="git --version"},
    @{Name="Python";   Install="Python.Python.3.12";            Summary="python --version"},
    @{Name="pip";      Install="";                              Summary="pip --version"},
    @{Name="Java JDK"; Install="EclipseAdoptium.Temurin.21.JDK"; Summary="java -version"},
    @{Name="javac";    Install="";                              Summary="javac --version"},
    @{Name="GCC";      Install="MSYS2.MSYS2";                   Summary="gcc --version"},
    @{Name="G++";      Install="MSYS2.MSYS2";                   Summary="g++ --version"},
    @{Name="Node.js";  Install="OpenJS.NodeJS.LTS";             Summary="node --version"},
    @{Name="npm";      Install="";                              Summary="npm --version"},
    @{Name="Docker";   Install="Docker.DockerDesktop";          Summary="docker --version"},
    @{Name="CMake";    Install="Kitware.CMake";                 Summary="cmake --version"},
    @{Name="VS Code";  Install="Microsoft.VisualStudioCode";    Summary="code --version"},
    @{Name="Maven";    Install="dlcdn.apache.org/maven";        Summary="mvn --version"},
    @{Name="MySQL";    Install="Oracle.MySQL";                  Summary="mysql --version"},
    @{Name="Android Studio"; Install="Google.AndroidStudio";     Summary="android-studio"},
    @{Name="Android SDK";    Install="";                        Summary="android-34"},
    @{Name="7-Zip";     Install="7zip.7zip";                 Summary="7z --help"},
    @{Name="WinTerminal"; Install="Microsoft.WindowsTerminal"; Summary="wt --version"},
    @{Name="PowerToys"; Install="Microsoft.PowerToys";       Summary="PowerToys"},
    @{Name="Redis";     Install="Redis.Redis";                Summary="redis-cli --version"},
    @{Name="Miniconda"; Install="Anaconda.Miniconda3";       Summary="conda --version"},
    @{Name="kubectl";   Install="Kubernetes.kubectl";        Summary="kubectl version"},
    @{Name="DBeaver";   Install="DBeaver.DBeaver.Community"; Summary="dbeaver --version"}
)

foreach ($t in $tools) {
    $hasInstall = if ($t.Install -eq "") { $true } else { $content -match [regex]::Escape($t.Install) }
    $hasSummary = $content -match [regex]::Escape($t.Summary)
    
    if ($hasInstall -and $hasSummary) {
        Write-Host "  ✅ $($t.Name.PadRight(10)) : 安装 + 检测" -ForegroundColor Green
    } elseif ($hasSummary) {
        Write-Host "  ⚡ $($t.Name.PadRight(10)) : 仅检测 (捆绑安装)" -ForegroundColor Yellow
    } else {
        Write-Host "  ❌ $($t.Name.PadRight(10)) : 缺失" -ForegroundColor Red
    }
}

# === 冗余检测 ===
Write-Host "`n  ── 冗余检测 ────────────────────────────────────────────" -ForegroundColor Cyan
$redundancyPatterns = @(
    @{Name="无重复 switch 分支";        Pass=($content -match '\$menu\[')},
    @{Name="无重复 '按 Enter 返回' 代码"; Pass=(($content -match "function Wait-Key") -and (([regex]::Matches($content, "按 Enter 返回主菜单").Count) -le 1))},
    @{Name="Show-Summary 循环驱动";     Pass=($content -match 'foreach \(\$t in \$tools\)' -and $content -match '& \$t\.C')},
    @{Name="Update-Path 集中管理";      Pass=($content -match "function Invoke-Installer" -and $content -match "Update-Path")},
    @{Name="Invoke-Installer 统一入口";  Pass=([regex]::Matches($content, "Invoke-Installer ").Count -ge 5)},
    @{Name="Install-Maven/MySQL 独立函数"; Pass=($content -match "function Install-Maven" -and $content -match "function Install-MySQL")},
    @{Name="菜单项数量 12+";            Pass=([regex]::Matches($content, "'\d+'\s*=\s*@\{Label=").Count -ge 12)},
    @{Name="无死代码 Test-InternetConnection"; Pass=($content -notmatch "Test-InternetConnection")},
    @{Name="winget GitHub API 自动下载"; Pass=($content -match "api.github.com/repos/microsoft/winget-cli" -and $content -match "msixbundle")},
    @{Name="winget 缺失退出前自动清理"; Pass=($content -match 'Remove-Item.*-Recurse.*-Force.*\$tempDir' -and $content -match 'return \$false' -and $content -match 'exit 1')},
    @{Name="Install-Android 函数";      Pass=($content -match "function Install-Android")},
    @{Name="ANDROID_HOME 环境变量";     Pass=($content -match 'ANDROID_HOME')},
    @{Name="Android SDK 镜像解析";      Pass=($content -match 'repository2-1\.xml' -and $content -match 'mirrors\.cloud\.tencent\.com')}
)

$allRedundantClean = $true
foreach ($r in $redundancyPatterns) {
    if ($r.Pass) {
        Write-Host "  ✅ $($r.Name)" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $($r.Name)" -ForegroundColor Red
        $allRedundantClean = $false
    }
}

# === 6. GUI (devkit_gui.ps1) 检查 ===
Write-Host "`n  [6/6] GUI (devkit_gui.ps1) 检查..." -ForegroundColor White
$guiPath = Join-Path $PSScriptRoot "devkit_gui.ps1"
$batPath = Join-Path $PSScriptRoot "启动图形界面.bat"

if (-not (Test-Path $guiPath)) {
    Write-Host "  ❌ devkit_gui.ps1 不存在" -ForegroundColor Red
} else {
    # 6.1 GUI 语法
    $guiTokens = @(); $guiErrors = @()
    $null = [System.Management.Automation.Language.Parser]::ParseFile($guiPath, [ref]$guiTokens, [ref]$guiErrors)
    if ($guiErrors.Count -eq 0) {
        Write-Host "  ✅ GUI 语法: 通过 (0 错误)" -ForegroundColor Green
    } else {
        Write-Host "  ❌ GUI 语法: $($guiErrors.Count) 个错误" -ForegroundColor Red
        $guiErrors | Select-Object -First 3 | ForEach-Object { Write-Host "     - $($_.Message)" -ForegroundColor Red }
    }

    # 6.2 toolGroups 里 Func 映射必须存在于 setup（同样必须 -Encoding UTF8）
    # 注意：函数名含连字符（Install-Java），正则必须用 [\w-]+（\w 不含 -，只抓 Install 会误报缺失）
    $guiContent = Get-Content $guiPath -Raw -Encoding UTF8
    $setupFuncs = @([regex]::Matches($content, '(?m)^function ([\w-]+)') | ForEach-Object { $_.Groups[1].Value })
    $guiToolFuncs = @([regex]::Matches($guiContent, 'Func = "([^"]+)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    $missingFuncs = @($guiToolFuncs | Where-Object { $_ -notin $setupFuncs })
    if ($missingFuncs.Count -eq 0) {
        Write-Host "  ✅ GUI 工具函数映射: $($guiToolFuncs.Count) 个全部在 setup 中存在" -ForegroundColor Green
    } else {
        Write-Host "  ❌ GUI 工具函数缺失: $($missingFuncs -join ', ')" -ForegroundColor Red
    }

    # 6.3 GUI 直接调用的 setup 函数
    $guiDirectCalls = @('Show-InstallLocations', 'Set-JavaEnv', 'Remove-FromPath', 'Add-ToPath', 'Load-Config', 'Save-Config', 'Write-Info', 'Write-OK', 'Write-Warn', 'Write-AppendLog', 'Search-WingetVersions')
    $missingCalls = @($guiDirectCalls | Where-Object { $_ -notin $setupFuncs })
    if ($missingCalls.Count -eq 0) {
        Write-Host "  ✅ GUI 直接调用函数: $($guiDirectCalls.Count) 个全部存在" -ForegroundColor Green
    } else {
        Write-Host "  ❌ GUI 调用缺失: $($missingCalls -join ', ')" -ForegroundColor Red
    }
}

if (Test-Path $batPath) {
    Write-Host "  ✅ 启动图形界面.bat 存在" -ForegroundColor Green
} else {
    Write-Host "  ❌ 启动图形界面.bat 不存在" -ForegroundColor Red
}

# === 总结 ===
Write-Host "`n  ═══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  审查总结 (精简版)" -ForegroundColor Cyan
Write-Host "  ═══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  总行数    : $lineCount 行" -ForegroundColor White
Write-Host "  函数数    : $funcCount 个" -ForegroundColor White
Write-Host "  语法      : ✅ 通过" -ForegroundColor Green
Write-Host "  安全      : $(if ($allSafe) { '✅ 通过' } else { '❌ 有风险' })" -ForegroundColor $(if ($allSafe) { "Green" } else { "Red" })
Write-Host "  模式      : $(if ($allPatternsPass) { '✅ 全部通过' } else { '❌ 有缺失' })" -ForegroundColor $(if ($allPatternsPass) { "Green" } else { "Red" })
Write-Host "  工具覆盖  : $($tools.Count)/$($tools.Count) 全部通过" -ForegroundColor Green
Write-Host "  冗余检测  : $(if ($allRedundantClean) { '✅ 无冗余' } else { '❌ 仍有余量' })" -ForegroundColor $(if ($allRedundantClean) { "Green" } else { "Red" })
Write-Host ""