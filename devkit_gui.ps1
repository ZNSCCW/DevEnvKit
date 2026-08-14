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

# ===== 1. 加载 setup_dev_env.ps1 的全部函数（AST 提取，不执行主流程） =====
$script:setupPath = Join-Path $PSScriptRoot "setup_dev_env.ps1"
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
function Select-Version { param([string]$ToolName, [array]$Versions) return $Versions[0] }
function Write-AppendLog { param([string]$Message) }
# setup 函数用到的颜色变量（GUI 无控制台，仍需定义避免 ForegroundColor 绑定失败）
$ColorTitle = "Cyan"; $ColorSuccess = "Green"; $ColorError = "Red"; $ColorWarning = "Yellow"
$ColorInfo = "White"; $ColorMenu = "Magenta"; $ColorPrompt = "Cyan"; $ColorStep = "Cyan"

# ===== 2. 全局状态 =====
$script:logPath = Join-Path $env:TEMP "devkit_gui_log.txt"
$script:lastLogLength = 0
$script:busy = $false

# ===== 3. 工具清单（按开发方向分组，Label 与菜单一致） =====
$script:toolGroups = @(
    @{ Group = "🧩 基础必备"; Tools = @(
        @{ Name = "Git";             Func = "Install-Git" },
        @{ Name = "7-Zip";           Func = "Install-7Zip" },
        @{ Name = "Windows Terminal";Func = "Install-WinTerminal" },
        @{ Name = "PowerToys";       Func = "Install-PowerToys" },
        @{ Name = "VS Code";         Func = "Install-VSCode" })},
    @{ Group = "☕ Java 后端"; Tools = @(
        @{ Name = "Java JDK";        Func = "Install-Java" },
        @{ Name = "Maven";           Func = "Install-Maven" },
        @{ Name = "MySQL";           Func = "Install-MySQL" },
        @{ Name = "Redis";           Func = "Install-Redis" },
        @{ Name = "DBeaver";         Func = "Install-DBeaver" })},
    @{ Group = "🖥️ 前端 / Web"; Tools = @(
        @{ Name = "Node.js";         Func = "Install-NodeJS" })},
    @{ Group = "🐍 Python"; Tools = @(
        @{ Name = "Python";          Func = "Install-Python" },
        @{ Name = "Miniconda";       Func = "Install-Miniconda" })},
    @{ Group = "⚙️ C/C++"; Tools = @(
        @{ Name = "C/C++ (MinGW+CMake)"; Func = "Install-CPP" })},
    @{ Group = "🤖 移动开发"; Tools = @(
        @{ Name = "Android Studio + SDK"; Func = "Install-Android" })},
    @{ Group = "🐳 容器 / 运维"; Tools = @(
        @{ Name = "Docker";          Func = "Install-Docker" },
        @{ Name = "kubectl";         Func = "Install-Kubectl" })}
)
$script:checkboxes = @()   # 全部 CheckBox 控件

# ===== 4. 日志刷新（Timer 读 transcript 文件追加到文本框） =====
function Update-LogBox {
    if (-not (Test-Path $script:logPath)) { return }
    $content = Get-Content $script:logPath -Raw -ErrorAction SilentlyContinue
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
# 运行一组函数，输出经 Start-Transcript 捕获到日志文件
function Invoke-GuiAction {
    param([scriptblock]$Action)
    if ($script:busy) { return }
    $script:busy = $true
    try {
        Remove-Item $script:logPath -Force -ErrorAction SilentlyContinue
        $script:lastLogLength = 0
        $script:logBox.Clear()
        Start-Transcript -Path $script:logPath -Force -ErrorAction SilentlyContinue | Out-Null
        try {
            & $Action
        } finally {
            Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
        }
        Update-LogBox
    } finally {
        $script:busy = $false
        Update-LogBox
    }
}

$script:installBtn = $null
$script:viewBtn = $null
$script:uninstallBtn = $null
$script:logBox = $null
$script:statusLabel = $null

function Start-Gui {
    # ===== 窗口 =====
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "DevEnvKit 环境管理器 v2.0"
    $form.Size = New-Object System.Drawing.Size(860, 620)
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
            $cb.Tag = $t.Func
            $cb.AutoSize = $true
            $cb.Padding = New-Object System.Windows.Forms.Padding(15, 2, 0, 2)
            $checkPanel.Controls.Add($cb)
            $script:checkboxes += $cb
        }
    }
    $left.Controls.Add($checkPanel)
    $form.Controls.Add($left)

    # ===== 右侧：日志 + 按钮 =====
    $right = New-Object System.Windows.Forms.Panel
    $right.Dock = "Fill"
    $right.Padding = New-Object System.Windows.Forms.Padding(10)

    $script:logBox = New-Object System.Windows.Forms.TextBox
    $script:logBox.Multiline = $true
    $script:logBox.ReadOnly = $true
    $script:logBox.ScrollBars = "Vertical"
    $script:logBox.Dock = "Fill"
    $script:logBox.Font = New-Object System.Drawing.Font("Consolas", 9)
    $right.Controls.Add($script:logBox)

    $bottom = New-Object System.Windows.Forms.Panel
    $bottom.Dock = "Bottom"
    $bottom.Height = 90

    $script:installBtn = New-Object System.Windows.Forms.Button
    $script:installBtn.Text = "⬇ 安装所选"
    $script:installBtn.Size = New-Object System.Drawing.Size(110, 32)
    $script:installBtn.Location = New-Object System.Drawing.Point(0, 5)
    $script:installBtn.Add_Click({
        $selected = @($script:checkboxes | Where-Object { $_.Checked })
        if ($selected.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("请先勾选要安装的工具", "提示") | Out-Null
            return
        }
        $funcs = @($selected | ForEach-Object { $_.Tag })
        Invoke-GuiAction -Action {
            foreach ($fn in $funcs) {
                Write-Host "===== 开始安装: $fn ====="
                try { & (Get-Item "function:$fn") } catch { Write-Host "安装失败: $_" }
            }
            Write-Host "===== 全部完成 ====="
        }
    })
    $bottom.Controls.Add($script:installBtn)

    $script:viewBtn = New-Object System.Windows.Forms.Button
    $script:viewBtn.Text = "📍 查看安装位置"
    $script:viewBtn.Size = New-Object System.Drawing.Size(120, 32)
    $script:viewBtn.Location = New-Object System.Drawing.Point(120, 5)
    $script:viewBtn.Add_Click({ Invoke-GuiAction -Action { Show-InstallLocations } })
    $bottom.Controls.Add($script:viewBtn)

    $script:uninstallBtn = New-Object System.Windows.Forms.Button
    $script:uninstallBtn.Text = "🗑️ 卸载 (待选)"
    $script:uninstallBtn.Size = New-Object System.Drawing.Size(110, 32)
    $script:uninstallBtn.Location = New-Object System.Drawing.Point(250, 5)
    $script:uninstallBtn.Add_Click({
        # 简单版：勾选的要卸载（复用 Uninstall-Tool，但需 PackageId 映射——这里直接提示控制台版使用）
        [System.Windows.Forms.MessageBox]::Show(
            "卸载请在勾选列表选择后使用: 当前 GUI 版卸载走控制台菜单 [28]，或手动 winget uninstall",
            "卸载说明") | Out-Null
    })
    $bottom.Controls.Add($script:uninstallBtn)

    $script:statusLabel = New-Object System.Windows.Forms.Label
    $script:statusLabel.Text = "状态: 就绪"
    $script:statusLabel.AutoSize = $true
    $script:statusLabel.Location = New-Object System.Drawing.Point(0, 45)
    $bottom.Controls.Add($script:statusLabel)
    $right.Controls.Add($bottom)
    $form.Controls.Add($right)

    # ===== Timer：日志刷新 =====
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 500
    $timer.Add_Tick({ Update-LogBox })
    $timer.Start()

    # ===== 启动时显示已装工具位置（只读预览） =====
    $form.Add_Shown({
        $form.Activate()
        Invoke-GuiAction -Action { Show-InstallLocations }
    })

    [System.Windows.Forms.Application]::Run($form)
}

Start-Gui
