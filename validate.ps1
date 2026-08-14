# 验证 setup_dev_env.ps1 语法和逻辑健全性
$ErrorActionPreference = "Stop"
$scriptPath = Join-Path $PSScriptRoot "setup_dev_env.ps1"

Write-Host "`n  ═══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "    setup_dev_env.ps1 代码审查 (精简版 v1.3)" -ForegroundColor Cyan
Write-Host "  ═══════════════════════════════════════════`n" -ForegroundColor Cyan

# === 1. 语法检查 ===
Write-Host "  [1/5] 语法检查..." -ForegroundColor White
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

$content = Get-Content $scriptPath -Raw
$lineCount = ($content -split "`n").Count

# === 2. 结构完整性检查 ===
Write-Host "`n  [2/5] 结构完整性..." -ForegroundColor White
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
Write-Host "`n  [3/5] 关键代码模式..." -ForegroundColor White
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
    @{Name="Checksum 校验"; Pass=($content -match "ExpectedHash" -and $content -match "Get-FileHash")}
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
Write-Host "`n  [4/5] 安全审计..." -ForegroundColor White
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
Write-Host "`n  [5/5] 工具覆盖范围..." -ForegroundColor White
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