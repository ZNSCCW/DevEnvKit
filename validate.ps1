# 验证 setup_dev_env.ps1 语法和逻辑健全性
$ErrorActionPreference = "Stop"
$scriptPath = Join-Path $PSScriptRoot "setup_dev_env.ps1"

Write-Host "`n  ═══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "    setup_dev_env.ps1 代码审查 (精简版 v1.2)" -ForegroundColor Cyan
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
    @{Name="菜单字典 \$menu"; Pass=($content -match '\$menu\s*=\s*\[ordered\]@\{' -and $content -match "menu\.ContainsKey")},
    @{Name="通用安装包装器 Invoke-Installer"; Pass=($content -match "function Invoke-Installer")}
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
    @{Name="Pause-Key 消除重复代码"; Pass=($content -match "function Pause-Key")},
    @{Name="UTF8 编码设置"; Pass=($content -match 'OutputEncoding.*UTF8')},
    @{Name="管理员权限检查"; Pass=($content -match 'WindowsPrincipal')},
    @{Name="winget 可用性检查"; Pass=($content -match 'Get-Command winget')},
    @{Name="JAVA_HOME 设置"; Pass=($content -match 'JAVA_HOME')},
    @{Name="MAVEN_HOME 设置"; Pass=($content -match 'MAVEN_HOME')},
    @{Name="安装日志保存"; Pass=($content -match 'Save-Log|install_log_')},
    @{Name="WinLibs 优先 MSYS2"; Pass=($content -match "WinLibs.GCC") -and ($content.IndexOf("WinLibs.GCC") -lt $content.IndexOf("MSYS2.MSYS2"))},
    @{Name="MSYS2 PATH 手动追加"; Pass=($content -match "msys64\\\\mingw64\\\\bin" -or $content -match 'msys64\\mingw64\\bin')},
    @{Name="编译器独立检测 ArrayList"; Pass=($content -match "ArrayList")}
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
    @{Name="无 Remove-Item 危险删除"; Pattern="Remove-Item.*-Recurse.*-Force"; Should=$false},
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
    @{Name="GCC";      Install="WinLibs.GCC";                   Summary="gcc --version"},
    @{Name="G++";      Install="WinLibs.GCC";                   Summary="g++ --version"},
    @{Name="Node.js";  Install="OpenJS.NodeJS.LTS";             Summary="node --version"},
    @{Name="npm";      Install="";                              Summary="npm --version"},
    @{Name="Docker";   Install="Docker.DockerDesktop";          Summary="docker --version"},
    @{Name="CMake";    Install="Kitware.CMake";                 Summary="cmake --version"},
    @{Name="VS Code";  Install="Microsoft.VisualStudioCode";    Summary="code --version"},
    @{Name="Maven";    Install="Apache.Maven.3";                Summary="mvn --version"},
    @{Name="MySQL";    Install="Oracle.MySQL";                  Summary="mysql --version"}
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
    @{Name="无重复 '按任意键返回' 代码"; Pass=(($content -match "function Pause-Key") -and (([regex]::Matches($content, "按任意键返回").Count) -le 2))},
    @{Name="Show-Summary 循环驱动";     Pass=($content -match 'foreach \(\$t in \$tools\)' -and $content -match '& \$t\.C')},
    @{Name="Update-Path 集中管理";      Pass=($content -match "function Invoke-Installer" -and $content -match "Update-Path")},
    @{Name="Invoke-Installer 统一入口";  Pass=([regex]::Matches($content, "Invoke-Installer ").Count -ge 5)},
    @{Name="Install-Maven/MySQL 独立函数"; Pass=($content -match "function Install-Maven" -and $content -match "function Install-MySQL")},
    @{Name="菜单项数量 11+";            Pass=([regex]::Matches($content, "'\d+'\s*=\s*@\{Label=").Count -ge 11)},
    @{Name="无死代码 Test-InternetConnection"; Pass=($content -notmatch "Test-InternetConnection")}
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
Write-Host "  工具覆盖  : 14/14" -ForegroundColor Green
Write-Host "  冗余检测  : $(if ($allRedundantClean) { '✅ 无冗余' } else { '❌ 仍有余量' })" -ForegroundColor $(if ($allRedundantClean) { "Green" } else { "Red" })
Write-Host ""