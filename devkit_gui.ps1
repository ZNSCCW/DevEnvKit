<#
============================================================================
  🛠️  DevEnvKit 图形界面 (v2.0 GUI)
  基于 WinForms，复用 setup_dev_env.ps1 全部函数
  用法: powershell -ExecutionPolicy Bypass -File devkit_gui.ps1
  打包: ps2exe -inputFile devkit_gui.ps1 -outputFile DevEnvKit.exe -noConsole
============================================================================
#>
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic   # InputBox 支持（版本切换）

# ===== 1. 加载 setup_dev_env.ps1 的全部函数（AST 提取，不执行主流程） =====
# 注意：ps2exe 打包成 exe 后 $PSScriptRoot 为空字符串——用 Get-ScriptDir 兼容 exe/ps1 两种运行方式
function Get-ScriptDir {
    if ($PSScriptRoot) { return $PSScriptRoot }
    return Split-Path -Parent ([Environment]::GetCommandLineArgs()[0])
}
$script:setupPath = Join-Path (Get-ScriptDir) "setup_dev_env.ps1"
if (-not (Test-Path $script:setupPath)) { $script:setupPath = "setup_dev_env.ps1" }
$script:tokens = $null; $script:parseErrors = $null
$script:setupAst = [System.Management.Automation.Language.Parser]::ParseFile(
    $script:setupPath, [ref]$script:tokens, [ref]$script:parseErrors)
if ($script:parseErrors.Count -gt 0) {
    [System.Windows.Forms.MessageBox]::Show("setup_dev_env.ps1 解析失败: $($script:parseErrors[0].Message)", "DevEnvKit 错误",
        [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    exit 1
}
$script:setupFuncs = $script:setupAst.FindAll(
    { param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
foreach ($f in $script:setupFuncs) {
    Set-Item -Path "function:$($f.Name)" -Value $f.Body.GetScriptBlock()
}
# 覆盖交互函数为"GUI 自动模式"：已装不重装、版本选第 1 个（避免 Read-Host 卡住无控制台的 GUI）
function Request-Confirmation { param([string]$ToolName, [string]$InstalledVersion, [string]$TargetVersionDesc) return $false }
function Select-Version { param([string]$ToolName, [array]$Versions, [string]$SearchPrefix = "", [string]$Exclude = "") return $Versions[0] }
function Write-AppendLog { param([string]$Message) }

# GUI 版本选择对话框：主线程弹 ComboBox 让用户选安装版本（供安装按钮收集版本映射）
function Show-VersionDialog {
    param([string]$ToolName, [array]$Versions, [string]$SearchPrefix = "", [string]$Exclude = "", [switch]$NoDynamic)
    if (-not $Versions -or $Versions.Count -le 1) { return $Versions[0] }
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "选择 $ToolName 版本"
    $form.Size = New-Object System.Drawing.Size(400, 170)
    $form.StartPosition = "CenterParent"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $label = New-Object System.Windows.Forms.Label
    $label.Text = "请选择要安装的 $ToolName 版本："
    $label.Location = New-Object System.Drawing.Point(15, 15)
    $label.AutoSize = $true
    $combo = New-Object System.Windows.Forms.ComboBox
    $combo.Location = New-Object System.Drawing.Point(15, 45)
    $combo.Size = New-Object System.Drawing.Size(345, 25)
    $combo.DropDownStyle = "DropDownList"
    foreach ($v in $Versions) { [void]$combo.Items.Add($v.Label) }
    $dynamicIdx = -1
    if (-not $NoDynamic -and $SearchPrefix) {
        $dynamicIdx = $Versions.Count
        [void]$combo.Items.Add("其他版本（winget 实时探测）")
    }
    $combo.SelectedIndex = 0
    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = "确定"
    $ok.DialogResult = "OK"
    $ok.Location = New-Object System.Drawing.Point(195, 90)
    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = "跳过此工具"
    $cancel.DialogResult = "Cancel"
    $cancel.Location = New-Object System.Drawing.Point(280, 90)
    $form.Controls.AddRange(@($label, $combo, $ok, $cancel))
    $form.AcceptButton = $ok
    $form.CancelButton = $cancel
    if ($form.ShowDialog() -eq "OK") {
        $sel = $combo.SelectedIndex
        if ($sel -eq $dynamicIdx) {
            # 动态探测分支：winget 实时列出全部可用版本（未来新版本零改动支持）
            try {
                $found = Search-WingetVersions -Prefix $SearchPrefix -Exclude $Exclude
                if (-not $found -or $found.Count -eq 0) {
                    [System.Windows.Forms.MessageBox]::Show("winget 探测无结果（可能源不可达），改用推荐版本", "$ToolName 版本") | Out-Null
                    return $Versions[0]
                }
                return Show-VersionDialog -ToolName $ToolName -Versions @($found) -NoDynamic
            } catch {
                [System.Windows.Forms.MessageBox]::Show("探测失败: $_`n改用推荐版本", "$ToolName 版本") | Out-Null
                return $Versions[0]
            }
        }
        return $Versions[$sel]
    }
    return $null   # 跳过 → 不安装此工具
}
# setup 函数用到的颜色变量（GUI 无控制台，仍需定义避免 ForegroundColor 绑定失败）
$ColorTitle = "Cyan"; $ColorSuccess = "Green"; $ColorError = "Red"; $ColorWarning = "Yellow"
$ColorInfo = "White"; $ColorMenu = "Magenta"; $ColorPrompt = "Cyan"; $ColorStep = "Cyan"

# ===== 1.5 覆盖 Write-Host：ps2exe -noConsole 下 Write-Host 没有控制台可写，会**逐条弹 MessageBox**！
#      改为写入日志文件（日志框由 Timer 读取刷新）。setup 提取的函数与 GUI 自身都走这里。
function Write-Host {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, ValueFromRemainingArguments = $true)] [object]$Object,
        [object]$ForegroundColor,
        [object]$BackgroundColor,
        [switch]$NoNewline,
        [object]$Separator = ' '
    )
    $text = ($Object | ForEach-Object { if ($null -eq $_) { '' } else { [string]$_ } }) -join "$Separator"
    if (-not $NoNewline) { $text += "`r`n" }
    Add-Content -Path $script:logPath -Value $text -Encoding UTF8 -ErrorAction SilentlyContinue
}

# ===== 2. 全局状态 =====
$script:logPath = Join-Path $env:TEMP "devkit_gui_log.txt"
$script:lastLogLength = 0
$script:busy = $false
$script:activeJob = $null    # 后台 PowerShell 任务（runspace）

# ===== 3. 工具清单（按开发方向分组，Label 与菜单一致） =====
$script:toolGroups = @(
    @{ Group = "🧩 基础必备"; Tools = @(
        @{ Name = "Git";             Func = "Install-Git";             Id = "Git.Git" },
        @{ Name = "7-Zip";           Func = "Install-7Zip";           Id = "7zip.7zip" },
        @{ Name = "Windows Terminal";Func = "Install-WinTerminal";    Id = "Microsoft.WindowsTerminal" },
        @{ Name = "PowerToys";       Func = "Install-PowerToys";      Id = "Microsoft.PowerToys" },
        @{ Name = "VS Code";         Func = "Install-VSCode";         Id = "Microsoft.VisualStudioCode" })},
    @{ Group = "☕ Java 后端"; Tools = @(
        @{ Name = "Java JDK";        Func = "Install-Java";           Id = "EclipseAdoptium.Temurin.21.JDK"; SearchPrefix = "EclipseAdoptium.Temurin"; Exclude = "\.JRE"; Versions = @(
            @{Label="JDK 21 (LTS, 推荐)"; PackageId="EclipseAdoptium.Temurin.21.JDK"},
            @{Label="JDK 17 (LTS)";       PackageId="EclipseAdoptium.Temurin.17.JDK"},
            @{Label="JDK 11 (LTS)";       PackageId="EclipseAdoptium.Temurin.11.JDK"},
            @{Label="JDK 8 (LTS)";        PackageId="EclipseAdoptium.Temurin.8.JDK"}) },
        @{ Name = "Maven";           Func = "Install-Maven";          Id = "" },
        @{ Name = "MySQL";           Func = "Install-MySQL";          Id = "Oracle.MySQL" },
        @{ Name = "Redis";           Func = "Install-Redis";          Id = "Redis.Redis" },
        @{ Name = "DBeaver";         Func = "Install-DBeaver";        Id = "DBeaver.DBeaver.Community" })},
    @{ Group = "🖥️ 前端 / Web"; Tools = @(
        @{ Name = "Node.js";         Func = "Install-NodeJS";         Id = "OpenJS.NodeJS.LTS"; SearchPrefix = "OpenJS.NodeJS"; Exclude = ""; Versions = @(
            @{Label="Node.js 22 (LTS, 推荐)"; PackageId="OpenJS.NodeJS.LTS"},
            @{Label="Node.js 20 (LTS)";       PackageId="OpenJS.NodeJS.20"}) })},
    @{ Group = "🐍 Python"; Tools = @(
        @{ Name = "Python";          Func = "Install-Python";         Id = "Python.Python.3.12"; SearchPrefix = "Python.Python.3"; Exclude = ""; Versions = @(
            @{Label="Python 3.12 (推荐)"; PackageId="Python.Python.3.12"},
            @{Label="Python 3.13";        PackageId="Python.Python.3.13"},
            @{Label="Python 3.11";        PackageId="Python.Python.3.11"}) },
        @{ Name = "Miniconda";       Func = "Install-Miniconda";      Id = "Anaconda.Miniconda3" })},
    @{ Group = "⚙️ C/C++"; Tools = @(
        @{ Name = "C/C++ (MinGW+CMake)"; Func = "Install-CPP";        Id = "MSYS2.MSYS2" })},
    @{ Group = "🤖 移动开发"; Tools = @(
        @{ Name = "Android Studio + SDK"; Func = "Install-Android";   Id = "Google.AndroidStudio" })},
    @{ Group = "🐳 容器 / 运维"; Tools = @(
        @{ Name = "Docker";          Func = "Install-Docker";         Id = "Docker.DockerDesktop" },
        @{ Name = "kubectl";         Func = "Install-Kubectl";        Id = "Kubernetes.kubectl" })}
)
$script:checkboxes = @()   # 全部 CheckBox 控件

# ===== 4. 日志刷新（Timer 读 transcript 文件追加到文本框） =====
function Update-LogBox {
    if (-not (Test-Path $script:logPath)) { return }
    $content = Get-Content $script:logPath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($content) {
        $newText = $content.Substring([Math]::Min($script:lastLogLength, $content.Length))
        if ($newText) {
            $script:logBox.AppendText($newText)
            $script:logBox.SelectionStart = $script:logBox.TextLength
            $script:logBox.ScrollToCaret()
            $script:lastLogLength = $content.Length
        }
    }
    $script:statusLabel.Text = "状态: $(if ($script:busy) { '执行中...' } else { '就绪' })"
    $script:installBtn.Enabled = -not $script:busy
    $script:viewBtn.Enabled = -not $script:busy
    $script:uninstallBtn.Enabled = -not $script:busy
}

# ===== 5. 动作 =====
# 安装/卸载在【后台 job（独立 powershell 子进程）】执行——否则 winget 耗时时 UI 线程被占、窗口卡死。
# 子进程内重新加载 setup 函数 + 覆盖 Write-Host 写日志文件。
# 日志框由 Timer 每 500ms 读文件刷新；完成时 Timer 检查 job 状态恢复按钮。
function Invoke-GuiAction {
    param([scriptblock]$Action, [hashtable]$Inject = @{}, [string]$ActionName = "操作")
    if ($script:busy) { return }
    $script:busy = $true
    $script:lastActionName = $ActionName
    Update-LogBox
    Remove-Item $script:logPath -Force -ErrorAction SilentlyContinue
    $script:lastLogLength = 0
    $script:logBox.Clear()

    # 注入变量（数组转 PS 字面量，供子进程脚本使用）
    $injectText = ""
    foreach ($k in $Inject.Keys) {
        $v = $Inject[$k]
        if ($v -is [array]) {
            $items = @($v | ForEach-Object { "'" + $_.ToString().Replace("'", "''") + "'" })
            $injectText += "`$$k = @($($items -join ', '))`n"
        } else {
            $injectText += "`$$k = '" + $v.ToString().Replace("'", "''") + "'`n"
        }
    }

    $setupPath = $script:setupPath
    $logPath = $script:logPath
    # 子进程初始化：加载 setup 函数 + GUI 自动模式覆盖 + Write-Host 覆盖写日志文件
    $initText = @"
`$script:logPath = '$logPath'
`$tokens = `$null; `$errors = `$null
`$ast = [System.Management.Automation.Language.Parser]::ParseFile('$setupPath', [ref]`$tokens, [ref]`$errors)
if (`$errors.Count -gt 0) { throw 'setup 解析失败' }
`$funcs2 = `$ast.FindAll({ param(`$n) `$n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, `$true)
foreach (`$f in `$funcs2) { Set-Item -Path "function:`$(`$f.Name)" -Value `$f.Body.GetScriptBlock() }
function Request-Confirmation { param(`$ToolName, `$InstalledVersion, `$TargetVersionDesc) return `$false }
function Select-Version {
    param(`$ToolName, [array]`$Versions, [string]`$SearchPrefix = "", [string]`$Exclude = "")
    if (`$versionMapText) {
        foreach (`$entry in (`$versionMapText -split ';')) {
            `$parts = `$entry -split '\|'
            if (`$parts.Count -ge 2 -and `$parts[0] -eq `$ToolName) {
                `$v = `$Versions | Where-Object { `$_.PackageId -eq `$parts[1] }
                if (`$v) { return `$v }
            }
        }
    }
    return `$Versions[0]
}
function Write-AppendLog { param(`$Message) }
`$ColorTitle = 'Cyan'; `$ColorSuccess = 'Green'; `$ColorError = 'Red'; `$ColorWarning = 'Yellow'
`$ColorInfo = 'White'; `$ColorMenu = 'Magenta'; `$ColorPrompt = 'Cyan'; `$ColorStep = 'Cyan'
`$script:baseDir = Split-Path '$setupPath'
function Write-Host {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, ValueFromRemainingArguments = `$true)] [object]`$Object,
        [object]`$ForegroundColor, [object]`$BackgroundColor, [switch]`$NoNewline, [object]`$Separator = ' '
    )
    `$text = (`$Object | ForEach-Object { if (`$null -eq `$_) { '' } else { [string]`$_ } }) -join "`$Separator"
    if (-not `$NoNewline) { `$text += "`r`n" }
    Add-Content -Path `$script:logPath -Value `$text -Encoding UTF8 -ErrorAction SilentlyContinue
}
"@
    $jobScript = [scriptblock]::Create($injectText + $initText + $Action.ToString())
    $script:activeJob = Start-Job -ScriptBlock $jobScript
}

$script:installBtn = $null
$script:viewBtn = $null
$script:uninstallBtn = $null
$script:selectAllBtn = $null
$script:switchJdkBtn = $null
$script:switchPyBtn = $null
$script:logBox = $null
$script:statusLabel = $null

# 管理员检测：卸载/切换 JDK/Python 需要写注册表环境变量，必须管理员
function Test-IsAdmin {
    $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    return (New-Object System.Security.Principal.WindowsPrincipal($id)).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Start-Gui {
    # ===== 窗口 =====
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "DevEnvKit 环境管理器 v2.0"
    $form.Size = New-Object System.Drawing.Size(860, 620)
    $form.MinimumSize = New-Object System.Drawing.Size(700, 500)
    $form.StartPosition = "CenterScreen"
    $form.Font = New-Object System.Drawing.Font("Microsoft YaHei", 9)

    # ===== 左侧：工具勾选（按组） =====
    $left = New-Object System.Windows.Forms.Panel
    $left.Dock = "Left"
    $left.Width = 360
    $left.Padding = New-Object System.Windows.Forms.Padding(10)

    $checkPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $checkPanel.Dock = "Fill"
    $checkPanel.AutoScroll = $true
    $checkPanel.FlowDirection = "TopDown"
    $checkPanel.WrapContents = $false

    foreach ($g in $script:toolGroups) {
        $lbl = New-Object System.Windows.Forms.Label
        $lbl.Text = "── $($g.Group) ──"
        $lbl.AutoSize = $true
        $lbl.ForeColor = [System.Drawing.Color]::DarkCyan
        $checkPanel.Controls.Add($lbl)
        foreach ($t in $g.Tools) {
            $cb = New-Object System.Windows.Forms.CheckBox
            $cb.Text = $t.Name
            $cb.Tag = $t          # Tag 存工具对象（含 Func/Id/Name）
            $cb.AutoSize = $true
            $cb.Padding = New-Object System.Windows.Forms.Padding(15, 2, 0, 2)
            $checkPanel.Controls.Add($cb)
            $script:checkboxes += $cb
        }
    }
    $left.Controls.Add($checkPanel)

    # ===== 左右分割容器：SplitContainer（Panel1 固定勾选列表，Panel2 自动剩余，杜绝 Dock Fill 重叠） =====
    # 注意：SplitterDistance / Panel1MinSize / Panel2MinSize 都必须在窗口显示后（Add_Shown）设置——
    #       SplitContainer 默认 SplitterDistance 很小，创建时设 MinSize 会立即校验越界抛异常；
    #       且三者互相约束（SplitterDistance ∈ [Panel1MinSize, Width - Panel2MinSize]），须按序设置
    $split = New-Object System.Windows.Forms.SplitContainer
    $split.Dock = "Fill"
    $split.Orientation = "Vertical"
    $split.SplitterWidth = 6
    $split.Panel1.Controls.Add($checkPanel)

    # ===== 右侧：日志 + 按钮（手动 Anchor 布局，规避 Dock Fill/Bottom 在 PowerShell 下的重叠坑） =====
    $right = New-Object System.Windows.Forms.Panel
    $right.Dock = "Fill"
    $right.Padding = New-Object System.Windows.Forms.Padding(10)

    $script:logBox = New-Object System.Windows.Forms.TextBox
    $script:logBox.Multiline = $true
    $script:logBox.ReadOnly = $true
    $script:logBox.ScrollBars = "Vertical"
    $script:logBox.Font = New-Object System.Drawing.Font("Microsoft YaHei", 9)
    $script:logBox.Anchor = "Top, Left, Right"
    $script:logBox.Location = New-Object System.Drawing.Point(10, 10)
    $script:logBox.Size = New-Object System.Drawing.Size(820, 470)
    $right.Controls.Add($script:logBox)

    $bottom = New-Object System.Windows.Forms.Panel
    $bottom.Anchor = "Bottom, Left, Right"
    $bottom.Location = New-Object System.Drawing.Point(10, 490)
    $bottom.Size = New-Object System.Drawing.Size(820, 90)

    $script:installBtn = New-Object System.Windows.Forms.Button
    $script:installBtn.Text = "⬇ 安装所选"
    $script:installBtn.Size = New-Object System.Drawing.Size(95, 32)
    $script:installBtn.Location = New-Object System.Drawing.Point(0, 5)
    $script:installBtn.Add_Click({
        $selected = @($script:checkboxes | Where-Object { $_.Checked })
        if ($selected.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("请先勾选要安装的工具", "提示") | Out-Null
            return
        }
        $tools = @($selected | ForEach-Object { $_.Tag })
        # 版本选择：对支持多版本的工具（Java/Python/Node）弹选择框；点「跳过此工具」= 不安装
        $versionMap = @{}
        $installTools = @()
        $skipped = @()
        foreach ($t in $tools) {
            if ($t.Versions) {
                $chosen = Show-VersionDialog -ToolName $t.Name -Versions @($t.Versions) -SearchPrefix $t.SearchPrefix -Exclude $t.Exclude
                if ($null -eq $chosen) { $skipped += $t.Name; continue }
                $versionMap[$t.Name] = $chosen.PackageId
            }
            $installTools += $t
        }
        if ($installTools.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("没有要安装的工具（已全部跳过）", "提示") | Out-Null
            return
        }
        $mapText = ($versionMap.GetEnumerator() | ForEach-Object { "$($_.Key)|$($_.Value)" }) -join ';'
        $skippedText = $skipped -join '、'
        Invoke-GuiAction -Action {
            if ($skippedText) { Write-Host "已跳过（版本选择时点「跳过」）: $skippedText" }
            for ($i = 0; $i -lt $funcs.Count; $i++) {
                Write-Host "===== 开始安装: $($names[$i]) ====="
                try { & (Get-Item "function:$($funcs[$i])") } catch { Write-Host "安装失败: $_" }
                Write-Host "----- 完成: $($names[$i]) -----"
            }
            Write-Host "===== 全部完成 ====="
        } -Inject @{ funcs = @($installTools | ForEach-Object { $_.Func }); names = @($installTools | ForEach-Object { $_.Name }); versionMapText = $mapText; skippedText = $skippedText } -ActionName "安装 $($installTools.Count) 个工具"
    })
    $bottom.Controls.Add($script:installBtn)

    $script:viewBtn = New-Object System.Windows.Forms.Button
    $script:viewBtn.Text = "📍 位置"
    $script:viewBtn.Size = New-Object System.Drawing.Size(95, 32)
    $script:viewBtn.Location = New-Object System.Drawing.Point(100, 5)
    $script:viewBtn.Add_Click({
        if ($script:busy) { return }
        $script:logBox.Clear()
        Remove-Item $script:logPath -Force -ErrorAction SilentlyContinue
        $script:lastLogLength = 0
        Show-InstallLocations
        Update-LogBox
    })
    $bottom.Controls.Add($script:viewBtn)

    $script:uninstallBtn = New-Object System.Windows.Forms.Button
    $script:uninstallBtn.Text = "🗑️ 卸载"
    $script:uninstallBtn.Size = New-Object System.Drawing.Size(95, 32)
    $script:uninstallBtn.Location = New-Object System.Drawing.Point(200, 5)
    $script:uninstallBtn.Add_Click({
        if (-not (Test-IsAdmin)) {
            [System.Windows.Forms.MessageBox]::Show("卸载需要管理员权限。`n请关闭本窗口，右键『启动图形界面.bat』→『以管理员身份运行』。", "需要管理员权限") | Out-Null
            return
        }
        $selected = @($script:checkboxes | Where-Object { $_.Checked })
        if ($selected.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("请先勾选要卸载的工具", "提示") | Out-Null
            return
        }
        $tools = @($selected | ForEach-Object { $_.Tag })
        $names = ($tools | ForEach-Object { $_.Name }) -join ', '
        $r = [System.Windows.Forms.MessageBox]::Show("确认卸载: $names ?", "卸载确认",
            [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
        if ($r -ne [System.Windows.Forms.DialogResult]::Yes) { return }
        Invoke-GuiAction -Action {
            for ($i = 0; $i -lt $funcs.Count; $i++) {
                Write-Host "===== 卸载: $($names[$i]) ====="
                try {
                    if ($ids[$i]) {
                        winget uninstall --id $ids[$i] --silent --accept-source-agreements 2>&1 | ForEach-Object { Write-Host "  $_" }
                        Write-Host "  卸载指令已执行 (退出码 $LASTEXITCODE)"
                    } else {
                        # Maven 特例（无 winget 包）：提示手动清理
                        Write-Host "  Maven 无 winget 包——请手动删除目录并清理 MAVEN_HOME"
                        [System.Environment]::SetEnvironmentVariable("MAVEN_HOME", $null, "Machine")
                        $null = Remove-FromPath -Pattern 'maven' -AllScopes
                        Write-Host "  MAVEN_HOME 已清除"
                    }
                } catch { Write-Host "卸载失败: $_" }
                Write-Host "----- 完成: $($names[$i]) -----"
            }
            Write-Host "===== 卸载流程完成 ====="
        } -Inject @{ funcs = @($tools | ForEach-Object { $_.Func }); names = @($tools | ForEach-Object { $_.Name }); ids = @($tools | ForEach-Object { $_.Id }) } -ActionName "卸载 $($tools.Count) 个工具"
    })
    $bottom.Controls.Add($script:uninstallBtn)

    # 环境检测按钮（第二行）：job 后台跑 Show-Summary，结果实时显示到日志框
    $script:envBtn = New-Object System.Windows.Forms.Button
    $script:envBtn.Text = "🔍 环境检测"
    $script:envBtn.Size = New-Object System.Drawing.Size(140, 32)
    $script:envBtn.Location = New-Object System.Drawing.Point(0, 42)
    $script:envBtn.Add_Click({
        if ($script:busy) { return }
        Invoke-GuiAction -Action {
            Show-Summary
            Write-Host ""
            Write-Host "===== 环境检测完成 ====="
        } -ActionName "环境检测"
    })
    $bottom.Controls.Add($script:envBtn)

    # 全选/全不选
    $script:selectAllBtn = New-Object System.Windows.Forms.Button
    $script:selectAllBtn.Text = "☑️ 全选"
    $script:selectAllBtn.Size = New-Object System.Drawing.Size(80, 32)
    $script:selectAllBtn.Location = New-Object System.Drawing.Point(370, 5)
    $script:selectAllBtn.Add_Click({
        $allChecked = @($script:checkboxes | Where-Object { -not $_.Checked }).Count -eq 0
        foreach ($cb in $script:checkboxes) { $cb.Checked = -not $allChecked }
        $script:selectAllBtn.Text = $(if ($allChecked) { "☑️ 全选" } else { "⬜ 全不选" })
    })
    $bottom.Controls.Add($script:selectAllBtn)

    # 切换 JDK 版本（InputBox 选编号，复用 Set-JavaEnv）
    $script:switchJdkBtn = New-Object System.Windows.Forms.Button
    $script:switchJdkBtn.Text = "🔀 切换 JDK"
    $script:switchJdkBtn.Size = New-Object System.Drawing.Size(100, 30)
    $script:switchJdkBtn.Location = New-Object System.Drawing.Point(0, 42)
    $script:switchJdkBtn.Add_Click({
        # 切换是秒级操作，同步执行（不经 runspace，需 InputBox 交互）
        if ($script:busy) { return }
        $script:logBox.Clear()
        Remove-Item $script:logPath -Force -ErrorAction SilentlyContinue
        $script:lastLogLength = 0
        if (-not (Test-IsAdmin)) {
            Write-Host "[需要管理员] 请关闭本窗口，右键『启动图形界面.bat』→『以管理员身份运行』后重试"
            Update-LogBox; return
        }
        # 扫描 Temurin (Eclipse Adoptium) + Oracle (C:\Program Files\Java) 两种安装路径
        $jdks = @()
        foreach ($base in @("C:\Program Files\Eclipse Adoptium\jdk-*", "C:\Program Files\Java\jdk-*")) {
            $jdks += @(Get-ChildItem $base -Directory -ErrorAction SilentlyContinue)
        }
        $jdks = @($jdks | Sort-Object Name -Descending | Select-Object -Unique)
        if ($jdks.Count -eq 0) { Write-Host "未检测到已安装 JDK，请先安装"; Update-LogBox; return }
        for ($i = 0; $i -lt $jdks.Count; $i++) { Write-Host "  [$($i + 1)]  $($jdks[$i].Name)" }
        $sel = [Microsoft.VisualBasic.Interaction]::InputBox("输入 JDK 编号 [1-$($jdks.Count)]，回车默认 1", "切换 Java 版本", "1")
        $idx = 0
        if ($sel -match '^\d+$' -and [int]$sel -ge 1 -and [int]$sel -le $jdks.Count) { $idx = [int]$sel - 1 }
        $null = Set-JavaEnv -JdkPath $jdks[$idx].FullName
        Write-Host "已切换 JDK → $($jdks[$idx].Name)（新终端生效，java -version 验证）"
        Update-LogBox
    })
    $bottom.Controls.Add($script:switchJdkBtn)

    # 切换 Python 版本（InputBox 选编号，复用 Remove-FromPath/Add-ToPath）
    $script:switchPyBtn = New-Object System.Windows.Forms.Button
    $script:switchPyBtn.Text = "🔀 切换 Python"
    $script:switchPyBtn.Size = New-Object System.Drawing.Size(110, 30)
    $script:switchPyBtn.Location = New-Object System.Drawing.Point(110, 42)
    $script:switchPyBtn.Add_Click({
        # 切换是秒级操作，同步执行（不经 runspace，需 InputBox 交互）
        if ($script:busy) { return }
        $script:logBox.Clear()
        Remove-Item $script:logPath -Force -ErrorAction SilentlyContinue
        $script:lastLogLength = 0
        if (-not (Test-IsAdmin)) {
            Write-Host "[需要管理员] 请关闭本窗口，右键『启动图形界面.bat』→『以管理员身份运行』后重试"
            Update-LogBox; return
        }
        $pythons = @()
        foreach ($base in @((Join-Path $env:LOCALAPPDATA "Programs\Python"), "C:\Program Files\Python3*")) {
            $pythons += @(Get-ChildItem $base -Directory -Filter "Python3*" -ErrorAction SilentlyContinue)
        }
        $pythons = @($pythons | Sort-Object Name -Descending | Select-Object -Unique)
        if ($pythons.Count -eq 0) { Write-Host "未检测到已安装 Python，请先安装"; Update-LogBox; return }
        for ($i = 0; $i -lt $pythons.Count; $i++) {
            $ver = ""
            try { $ver = (& (Join-Path $pythons[$i].FullName "python.exe") --version 2>&1) -replace '^Python\s*', '' } catch {}
            $verPart = if ($ver) { " (Python $ver)" } else { "" }
            Write-Host "  [$($i + 1)]  $($pythons[$i].Name)$verPart"
        }
        $sel = [Microsoft.VisualBasic.Interaction]::InputBox("输入 Python 编号 [1-$($pythons.Count)]，回车默认 1", "切换 Python 版本", "1")
        $idx = 0
        if ($sel -match '^\d+$' -and [int]$sel -ge 1 -and [int]$sel -le $pythons.Count) { $idx = [int]$sel - 1 }
        $null = Remove-FromPath -Pattern 'Python3\d+' -AllScopes
        $null = Add-ToPath -Entry $pythons[$idx].FullName -AllScopes
        Write-Host "已切换 Python → $($pythons[$idx].Name)（新终端生效，python --version 验证）"
        Update-LogBox
    })
    $bottom.Controls.Add($script:switchPyBtn)

    $script:statusLabel = New-Object System.Windows.Forms.Label
    $script:statusLabel.Text = "状态: 就绪"
    $script:statusLabel.AutoSize = $true
    $script:statusLabel.Location = New-Object System.Drawing.Point(240, 47)
    $bottom.Controls.Add($script:statusLabel)
    $right.Controls.Add($bottom)
    # Resize 联动：日志框高度 = 客户区 - 按钮面板（避免重叠）
    $right.Add_Resize({
        $w = $right.ClientSize.Width - 20
        $h = $right.ClientSize.Height
        $script:logBox.Size = New-Object System.Drawing.Size($w, [Math]::Max(100, $h - 120))
        $bottom.Location = New-Object System.Drawing.Point(10, [Math]::Max(110, $h - 100))
        $bottom.Size = New-Object System.Drawing.Size($w, 90)
    })
    $split.Panel2.Controls.Add($right)
    $form.Controls.Add($split)

    # ===== Timer：日志刷新 + 后台任务进度/完成检测 =====
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 500
    $timer.Add_Tick({
        Update-LogBox
        if ($script:activeJob) {
            # 完成：job 状态非 Running → 恢复 UI
            $job = Get-Job -Id $script:activeJob.Id -ErrorAction SilentlyContinue
            if ($job -and $job.State -ne 'Running') {
                try {
                    $jobOk = ($job.State -eq 'Completed')
                    $script:statusLabel.Text = "状态: $(if ($jobOk) { '完成' } else { '出错' })"
                    if (-not $jobOk) {
                        # job 失败：把错误写入日志
                        $err = @(Receive-Job -Id $job.Id -ErrorAction SilentlyContinue)
                        foreach ($line in $err) { Write-Host "  $line" }
                        Update-LogBox
                    }
                } finally {
                    Remove-Job -Id $job.Id -Force -ErrorAction SilentlyContinue
                    $script:activeJob = $null
                    $script:busy = $false
                    Update-LogBox
                }
                # 结果提示（弹一次）
                [System.Windows.Forms.MessageBox]::Show(
                    "$(if ($jobOk) { '操作完成' } else { '操作失败，详见日志' }): $($script:lastActionName)",
                    "DevEnvKit") | Out-Null
            }
        }
    })
    $timer.Start()

    # ===== 启动时显示已装工具位置（只读预览） =====
    $form.Add_Shown({
        $form.Activate()
        # SplitContainer 参数须在窗口显示后按序设置（互相约束，创建时设会校验越界抛异常）
        $split.SplitterDistance = 360
        $split.Panel1MinSize = 280
        $split.Panel2MinSize = 320
        # 启动预览：同步执行（秒级）
        Remove-Item $script:logPath -Force -ErrorAction SilentlyContinue
        $script:lastLogLength = 0
        Show-InstallLocations
        Update-LogBox
    })

    [System.Windows.Forms.Application]::Run($form)
}

Start-Gui
