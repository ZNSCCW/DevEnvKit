# 🛠️ 开发环境一键配置工具 v1.2

适用于 **Windows 10/11** 的开发环境快速部署工具，通过 Windows 包管理器 (winget) 自动安装主流开发工具。

---

## 支持的工具

| 类别 | 工具 | winget Package ID | 备注 |
|------|------|-------------------|------|
| 版本控制 | **Git** | `Git.Git` | 最新稳定版 |
| 编程语言 | **Python 3.12** | `Python.Python.3.12` | 自动安装 pip |
| 编程语言 | **Java JDK 21 LTS** | `EclipseAdoptium.Temurin.21.JDK` | 自动配置 `JAVA_HOME` |
| 编程语言 | **C/C++ (GCC/G++)** | `WinLibs.GCC`（优先） / `MSYS2.MSYS2`（回退） | MinGW-w64 多 ID 回退，替代方案：MSVC / Clang |
| 构建工具 | **CMake** | `Kitware.CMake` | 最新版 |
| 构建工具 | **Apache Maven** | `Apache.Maven.3` | 自动配置 `MAVEN_HOME` |
| 运行时 | **Node.js LTS** | `OpenJS.NodeJS.LTS` | 自动安装 npm |
| 容器 | **Docker Desktop** | `Docker.DockerDesktop` | 需要系统重启 |
| 数据库 | **MySQL Community** | `Oracle.MySQL` | 需手动初始化 root 密码 |
| 编辑器 | **Visual Studio Code** | `Microsoft.VisualStudioCode` | 最新稳定版 |

---

## 特性

### ✅ 核心功能
- 🚀 **一键安装全部** — 菜单选项 `[1]`，9 个工具全自动部署
- 🎯 **选择性安装** — 菜单选项 `[2]~[10]`，单独安装某个工具
- 🔄 **智能版本检测** — 已安装工具显示当前版本，Y=升级覆盖 / N=跳过保留
- 📋 **环境摘要** — 菜单选项 `[11]`，检测 14 项组件安装状态

### ✅ 安全设计 (v1.2 审计通过)
- **零命令注入** — 全脚本使用 ScriptBlock `{}` + `&` 调用操作符，无 `Invoke-Expression`
- **零参数注入** — 所有 `winget install --id` 的 PackageId 为硬编码常量，不接受外部输入
- **零路径遍历** — 日志路径由 `Get-Date` 格式化生成，用户输入不参与路径拼接
- **安全重启** — `Invoke-Reboot` 移除 `-Force` 并增加二次确认提示，防止数据丢失
- **输入校验** — 所有 Read-Host 输入仅做布尔匹配 `-match '^[Yy]$'` 或精确 `menu.ContainsKey` 匹配
- **死代码清理** — 移除未使用的 `Test-InternetConnection` 函数

### ✅ 代码质量 (v1.2)
- **JAVA_HOME 通配检测** — 移除硬编码补丁版本号 `jdk-21.0.0.35-hotspot`，统一使用 `jdk-21*` 通配
- **MAVEN_HOME 回退推导** — 若安装目录扫描失败，自动从 `Get-Command mvn` 的路径反推 `MAVEN_HOME`
- **winget 下载完整性校验** — 验证下载文件存在且 > 1MB，防止损坏文件通过 `Add-AppxPackage` 安装
- **日志自动清理** — `Save-Log` 前自动清除旧日志，仅保留最近 10 个 `install_log_*.txt`
- **`completedSteps` 语义注释** — 明确该变量计数"已就绪项"非"新安装数"
- **退出菜单 emoji 修正** — `❌ 退出` → `👋 退出`

### ✅ 代码精简 (v1.2)
- **switch 冗余消除** — 11 个重复分支改为 `$menu` 字典 + `Invoke-Installer` 统一入口
- **按任意键重复消除** — 重复代码提取为 `Wait-Key` 函数（1 行调用）
- **Show-Summary 循环驱动** — 14 次重复检测改为 `foreach` 遍历 `$tools` 数组
- **Update-Path 集中管理** — PATH 刷新统一在 `Invoke-Installer` 内部调用
- **总行数**: 677 → 509（↓25%）

### ✅ 其他特性
- 🎨 彩色终端输出，每步带时间戳
- 🔧 自动刷新 `PATH` 环境变量
- 📄 安装日志自动保存 (`install_log_YYYYMMDD_HHmmss.txt`)
- 🔌 管理员权限智能检测（可非管理员运行，但会给出警告）
- 🌐 网络故障自动诊断（区分 winget 源不可达 / 包未找到 / 安装失败）
- ⚙️ **winget 自动安装** — 检测到缺失时自动从 GitHub Release 下载安装，失败则回退打开下载页

---

## 新增功能 (v1.2)

### 🏗️ Apache Maven
- 通过 `Apache.Maven.3` winget 包安装
- 自动检测 `mvn` 命令并显示版本
- 自动搜索安装目录并配置 `MAVEN_HOME` 环境变量
- 支持已安装版本的升级覆盖确认

### ⚙️ winget 自动安装
- 脚本启动时自动检测 `winget` 命令是否可用
- 如未检测到，自动调用 GitHub API 获取最新 `microsoft/winget-cli` Release
- 下载 `.msixbundle` 安装包并通过 `Add-AppxPackage` 安装
- 安装后刷新 PATH 并验证可用性
- 若 GitHub API 超时或网络不可达，回退打开 `https://aka.ms/getwinget` 下载页面

### 🗄️ MySQL Community Server
- 通过 `Oracle.MySQL` winget 包安装
- 自动检测 `mysql` 命令并显示版本
- 安装后提供首次使用初始化指引：
  1. 打开 MySQL Installer 或命令行
  2. 运行 `mysqld --initialize --console` 生成随机 root 密码
  3. 运行 `mysql_secure_installation` 修改密码 + 安全加固

---

## 文件结构

```
dev_env_setup/
├── 启动配置工具.bat        # 中文名启动器（双击即可, 推荐）
├── launch.bat             # 纯英文启动器（双击即可）
├── setup_dev_env.ps1      # PowerShell 主脚本（509 行, 精简版）
├── validate.ps1           # 代码审查脚本（35 项检查）
├── b64.txt                # 主脚本的 Base64 编码（跨机传输用）
├── decode.ps1             # 解码器：从 b64.txt 还原 setup_dev_env.ps1
├── encode.ps1             # 编码器（开发者用，用户无需关心）
├── LICENSE                # MIT 许可证
└── README.md              # 本说明文件
```

---

## 使用方法

### 🖥️ 本机直接使用

1. 双击 `启动配置工具.bat` 或 `launch.bat`（建议**右键 → 以管理员身份运行**）
2. 在菜单界面选择操作：

```
  [1]  🚀 一键安装全部 (推荐)
  [2]  🔧 仅安装 Git
  [3]  🐍 仅安装 Python
  [4]  ☕ 仅安装 Java (JDK)
  [5]  ⚙️  仅安装 C/C++ 开发工具 (MinGW + CMake)
  [6]  🟢 仅安装 Node.js
  [7]  🐳 仅安装 Docker
  [8]  📝 仅安装 VS Code
  [9]  🏗️  仅安装 Maven
  [10] 🗄️  仅安装 MySQL
  [11] 📋 查看当前环境摘要
  [0]  👋 退出
```

### 📦 从其他机器/虚拟机复制到主机

直接复制 `.ps1` 文件会因为编码问题导致中文乱码。请按以下步骤操作：

1. **将整个 `dev_env_setup` 文件夹** 复制到目标主机
2. **先双击运行 `decode.ps1`**（右键 → 用 PowerShell 运行），从 `b64.txt` 还原出正确的 `setup_dev_env.ps1`
3. **再右键管理员运行 `launch.bat`** 启动工具

> **为什么需要这样？**  
> `setup_dev_env.ps1` 含大量中文注释和菜单提示。通过 U盘/共享文件夹/剪贴板 复制时，Windows 可能会改变文件编码（UTF-8 → ANSI），导致 PowerShell 解析失败。  
> `b64.txt` 是纯 ASCII 文本，任何传输方式都不会损坏；`decode.ps1` 负责将其还原为正确的 UTF-8 脚本。

### ⌨️ PowerShell 命令行运行

```powershell
# 以管理员身份打开 PowerShell，cd 到脚本目录后执行：
Set-ExecutionPolicy Bypass -Scope Process -Force
.\setup_dev_env.ps1
```

---

## 安装流程说明

`[1] 一键安装全部` 的完整流程：

```
  1. Git          → 检测版本 → 确认 → 安装
  2. Python 3.12  → 检测版本 → 确认 → 安装 → 验证 pip
  3. Java JDK 21  → 检测版本 → 确认 → 安装 → 配置 JAVA_HOME
  4. C/C++ 工具   → 检测编译器(GCC/Clang/MSVC) → 确认 → 安装 MinGW → 安装 CMake
  5. Node.js LTS  → 检测版本 → 确认 → 安装 → 验证 npm
  6. Docker       → 检测版本 → 确认 → 安装
  7. VS Code      → 检测版本 → 确认 → 安装
  8. Maven        → 检测版本 → 确认 → 安装 → 配置 MAVEN_HOME
  9. MySQL        → 检测版本 → 确认 → 安装 → 初始化指引
```

每个步骤都会：
1. 检查该工具是否已安装
2. 如已安装则展示**当前版本**，询问是否重新安装/升级 (Y/N)
3. 如未安装则通过 winget 下载安装
4. 通过 `Invoke-Installer` 统一刷新 `PATH`（`Update-Path`）

安装完成后：
- 展示 **14 项环境检测摘要** (Git/Python/pip/Java/javac/Maven/GCC/G++/Node.js/npm/Docker/MySQL/CMake/VS Code)
- 询问是否**立即重启**（Docker Desktop 需要重启生效，会先提示保存工作）

---

## C/C++ 编译器检测策略

脚本按以下优先级检测已有编译器：

| 优先级 | 检测方式 | 说明 |
|--------|----------|------|
| 1 | `gcc --version` + `g++ --version` | 检测 MinGW/GCC |
| 2 | `clang --version` | 检测 Clang/LLVM |
| 3 | `vswhere.exe` + 安装目录扫描 | 检测 Visual Studio MSVC (cl.exe 不在系统 PATH 中) |

若三种编译器均已存在，脚本会提示跳过。若均不存在，则自动安装 MinGW-w64（多 ID 回退：WinLibs.GCC 优先 → MSYS2 回退）。

---

## 错误处理

| 错误类型 | 现象 | 原因 |
|----------|------|------|
| **网络不可达** | `InternetOpenUrl() failed. 0x80072efd` | 机器无法访问外网，winget 无法下载 |
| **包未找到** | `No package found matching input criteria` | winget 源中不存在该包 ID |
| **编码损坏** | `Unexpected token` / `字符串缺少终止符` / 乱码 | `.ps1` 文件 UTF-8 编码被破坏 |

> 遇到编码损坏：删除 `setup_dev_env.ps1`，双击 `decode.ps1` 重新还原。

---

## 系统要求

| 要求 | 说明 |
|------|------|
| 操作系统 | Windows 10 1809+ 或 Windows 11 |
| winget | 系统自带 (Win10 1809+)。**若缺失，脚本会自动从 GitHub Release 下载安装** |
| 权限 | 推荐以**管理员权限**运行 |
| 网络 | 需要网络连接 (用于 winget 下载安装包) |

---

## 注意事项

1. **Docker Desktop** 安装后需要**重启系统**才能完全生效
2. **MySQL** 安装后需手动执行 `mysqld --initialize` 和 `mysql_secure_installation` 完成初始化
3. 部分工具 (如 MinGW-w64、Maven) 安装后，在新终端中才会加载最新的 PATH
4. 非管理员权限运行时，部分安装可能因 UAC 失败
5. 安装日志默认保存在脚本同目录下 (`install_log_YYYYMMDD_HHmmss.txt`)
6. 如遇 winget 源问题，可先执行 `winget source update` 更新源
7. 脚本启动时会自动检测 winget 是否可用，不可用时从 GitHub Release 自动下载安装

---

## 安全审计摘要

v1.2 已完成逐函数安全审计（validate.ps1，35 项检查），审计维度：

| 攻击面 | 检查点 | 结果 |
|--------|--------|------|
| 命令注入 | 16 处 `&` ScriptBlock 调用 | ✅ 安全 |
| 参数注入 | 11 处 `winget install --id` | ✅ 全部硬编码 |
| 路径遍历 | 日志/文件路径操作 | ✅ 不可控 |
| 代码注入 | 全脚本 | ✅ 零 `Invoke-Expression` |
| 用户输入 | 13 处 Read-Host | ✅ 正则 + menu.ContainsKey |

**结论: 0 个高危漏洞，0 个中危漏洞，可安全使用。**

---

## 许可证
本项目基于 [MIT License](LICENSE)