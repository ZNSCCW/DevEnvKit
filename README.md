# 🛠️ 开发环境一键配置工具 v1.6

适用于 **Windows 10/11** 的开发环境快速部署工具，通过 Windows 包管理器 (winget) 自动安装主流开发工具。

---

## 支持的工具（按开发方向分组）

> 共 18 个工具，菜单已按以下分组展示；除"一键安装全部"外，每个方向还有"全家桶"批量安装项。

### 🧩 基础必备

| 工具 | winget Package ID | 备注 |
|------|-------------------|------|
| **Git** | `Git.Git` | 版本控制，最新稳定版 |
| **7-Zip** | `7zip.7zip` | 解压工具 |
| **Windows Terminal** | `Microsoft.WindowsTerminal` | 现代终端 |
| **PowerToys** | `Microsoft.PowerToys` | Windows 效率工具集 |
| **Visual Studio Code** | `Microsoft.VisualStudioCode` | 通用编辑器 |

### ☕ Java 后端（全家桶：JDK + Maven + MySQL + Redis + DBeaver）

| 工具 | winget Package ID | 备注 |
|------|-------------------|------|
| **Java JDK 21 LTS** | `EclipseAdoptium.Temurin.21.JDK` | 自动配置 `JAVA_HOME` |
| **Apache Maven** | 官方源 `dlcdn.apache.org` | 自动配置 `MAVEN_HOME`（winget 无 Maven 包） |
| **MySQL Community** | `Oracle.MySQL` | 支持非 PATH 检测 (Program Files 回退) |
| **Redis** | `Redis.Redis` | 本地缓存（Redis on Windows 官方） |
| **DBeaver Community** | `DBeaver.DBeaver.Community` | 数据库图形化管理 |

### 🖥️ 前端 / Web（全家桶：Node.js + VS Code）

| 工具 | winget Package ID | 备注 |
|------|-------------------|------|
| **Node.js LTS** | `OpenJS.NodeJS.LTS` | 自动安装 npm |

### 🐍 Python（全家桶：Python + Miniconda）

| 工具 | winget Package ID | 备注 |
|------|-------------------|------|
| **Python 3.12** | `Python.Python.3.12` | 自动安装 pip |
| **Miniconda3** | `Anaconda.Miniconda3` | 数据科学/环境管理 |

### ⚙️ C/C++

| 工具 | winget Package ID | 备注 |
|------|-------------------|------|
| **C/C++ (GCC/G++)** | `MSYS2.MSYS2` | MSYS2 + pacman 装 MinGW-w64 编译链（winget 无 niXman.mingw-w64 包） |
| **CMake** | `Kitware.CMake` | 构建工具（随 C/C++ 一起装） |

### 🤖 移动开发

| 工具 | winget Package ID | 备注 |
|------|-------------------|------|
| **Android Studio + SDK 34+** | `Google.AndroidStudio` | 国内镜像下载 SDK 组件 |

### 🐳 容器 / 运维（全家桶：Docker + kubectl）

| 工具 | winget Package ID | 备注 |
|------|-------------------|------|
| **Docker Desktop** | `Docker.DockerDesktop` | 需要系统重启 |
| **kubectl** | `Kubernetes.kubectl` | Kubernetes CLI |

### 📋 速查：我想做 X → 装哪些？

| 目标 | 一键选择 |
|------|----------|
| **新机基础环境** | 菜单 `1` 一键全部（或基础必备组） |
| **Java 后端开发** | 菜单 `12` ☕ Java 后端全家桶 |
| **前端 / Web 开发** | 菜单 `14` 🖥️ 前端全家桶 |
| **Python / 数据科学** | 菜单 `17` 🐍 Python 全家桶 |
| **C/C++ / 底层开发** | 菜单 `18` |
| **Android 开发** | 菜单 `19` |
| **容器 / Kubernetes** | 菜单 `22` 🐳 容器/运维全家桶 |
| **只查环境状态** | 菜单 `23` 📋 环境摘要 |

---

## 特性

### ✅ 核心功能
- 🚀 **一键安装全部** — 菜单选项 `[1]`，18 个工具全自动部署 (国内网络下 Android SDK 走腾讯云镜像)
- 🎯 **选择性安装** — 菜单选项 `[2]~[22]`，单独安装某个工具
- 🧩 **按方向全家桶** — 菜单选项 `[12]/[14]/[17]/[22]`，按开发方向批量安装（Java 后端/前端/Python/容器运维）
- 🔄 **智能版本检测** — 已安装工具显示当前版本，Y=升级覆盖 / N=跳过保留
- 📋 **环境摘要** — 菜单选项 `[23]`，检测 23 项组件安装状态

### ✅ 安全设计 (v1.4 审计通过)
- **零命令注入** — 全脚本使用 ScriptBlock `{}` + `&` 调用操作符，无 `Invoke-Expression`
- **零参数注入** — 所有 `winget install --id` 的 PackageId 为硬编码常量，不接受外部输入
- **零路径遍历** — 日志路径由 `Get-Date` 格式化生成，用户输入不参与路径拼接
- **安全重启** — `Invoke-Reboot` 移除 `-Force` 并增加二次确认提示，防止数据丢失
- **输入校验** — 所有 Read-Host 输入仅做布尔匹配 `-match '^[Yy]$'` 或精确 `menu.Contains()` 匹配
- **死代码清理** — 移除未使用的 `Test-InternetConnection` 函数

### ✅ 代码质量 (v1.4)
- **JAVA_HOME 通配检测** — 移除硬编码补丁版本号 `jdk-21.0.0.35-hotspot`，统一使用 `jdk-21*` 通配
- **MAVEN_HOME 回退推导** — 若安装目录扫描失败，自动从 `Get-Command mvn` 的路径反推 `MAVEN_HOME`
- **winget 下载完整性校验** — 验证下载文件存在且 > 1MB，防止损坏文件通过 `Add-AppxPackage` 安装
- **网络超时防护** — GitHub API 请求和文件下载均设置合理超时 (15s / 120s)
- **一键安装容错** — 任意工具失败不中断后续安装，`foreach` + `try/catch` 独立执行
- **MySQL 多路径检测** — 除 PATH 外支持 `Program Files\MySQL\MySQL Server *\bin` 回退探测
- **MSYS2 编译器自举** — MSYS2 安装后自动调用 `pacman -S mingw-w64-ucrt64-gcc` 安装编译链
- **日志自动清理** — `Save-Log` 前自动清除旧日志，仅保留最近 10 个 `logs/install_log_*.txt`
- **`completedSteps` 语义注释** — 明确该变量计数"已就绪项"非"新安装数"
- **退出菜单 emoji 修正** — `❌ 退出` → `👋 退出`

### ✅ 代码精简 (v1.4)
- **switch 冗余消除** — 11 个重复分支改为 `$menu` 字典 + `Invoke-Installer` 统一入口
- **按任意键重复消除** — 重复代码提取为 `Wait-Key` 函数 (1 行调用)
- **Show-Summary 循环驱动** — 14 次重复检测改为 `foreach` 遍历 `$tools` 数组
- **Update-Path 集中管理** — PATH 刷新统一在 `Invoke-Installer` 内部调用
- **总行数**: 677 → ~603 (减约 11%)

### ✅ 其他特性
- 🎨 彩色终端输出，每步带时间戳
- 🔧 自动刷新 `PATH` 环境变量
- 📄 安装日志自动保存 (`logs/install_log_YYYYMMDD_HHmmss.txt`)
- 🔌 管理员权限智能检测 (可非管理员运行，但会给出警告)
- 🌐 网络故障自动诊断 (区分 winget 源不可达 / 包未找到 / 安装失败)
- ⚙️ **winget 自动安装** — 检测到缺失时自动从 GitHub Release 下载安装，失败则回退打开下载页

---

## 新增功能 (v1.5)

### 🧩 工具扩展至 18 个，按开发方向分组
- 新增 7 个工具：7-Zip / Windows Terminal / PowerToys / Redis / Miniconda / kubectl / DBeaver
- 菜单按 **7 个开发方向分组**展示（基础必备 / Java 后端 / 前端 / Python / C-C++ / 移动 / 容器运维），见顶部工具表
- 新增 **4 个"全家桶"一键安装**：Java 后端（12）、前端（14）、Python（17）、容器运维（22）——复用现有 Install-* 函数，`$funcs.Count` 动态计数

---

## 新增功能 (v1.6)

### 🎯 版本选择（JDK / Python / Node.js）
- 安装 JDK 时可选择 **JDK 8 / 11 / 17 / 21 (LTS)**，Python 可选 **3.11 / 3.12 / 3.13**，Node.js 可选 **20 / 22 (LTS)**
- 安装前弹出版本菜单，直接回车用推荐版本（第 1 项）
- `JAVA_HOME` 自动指向最新已装 JDK

### 🛡️ 安装可靠性（PackageId 全部实测验证）
- 所有 winget PackageId 已用 `winget show` 实测确认存在（修正了 Redis/DBeaver/MinGW 的错误 id）
- 安装失败时按退出码给出可行动提示：已安装 / 需提权 / 源不可达 / 包不存在等
- 失败后提示重试命令 `winget install --id <PackageId>` 或官网手动下载

### 📊 下载进度条（自动换单位 + 显示总大小）
- 自定义流式下载：实时进度显示 **已下载 / 共 XX MB (xx%)** 与 **下载速度**
- 大小**自动换单位**（B → KB → MB → GB），不刷屏（PowerShell 原生进度条）
- 已应用到：Android SDK 镜像下载、Maven 官方源下载、winget 自动安装

### 🐢 下载缓慢应对（国内网络友好）
- **停滞检测**：下载 15 秒无数据判定卡死，自动中断（避免无限挂起）
- **自动重试**：下载失败自动重试 2 次（间隔 3 秒）
- **断点续传**：失败保留半成品，下次运行自动从断点继续（HTTP Range；服务器支持 206 续写、不支持自动退化全量重下——腾讯云/阿里云/Apache 官方源均已实测支持）
- **代理感知**：自动读取 `HTTPS_PROXY` / `HTTP_PROXY` / `ALL_PROXY` 环境变量走代理（未设置则用 Windows 系统代理）
- **多镜像回退**：
  - Android SDK：腾讯云镜像 `mirrors.cloud.tencent.com`（国内直连）
  - Maven：Apache 官方源 `dlcdn.apache.org` → 阿里云镜像 `mirrors.aliyun.com` 自动回退
  - winget 安装包：GitHub Release 失败时打开下载页面人工处理
- 慢速网络下总超时放宽到 10 分钟，靠停滞检测而非固定超时兜底

### 🔬 实机验证（提取函数实测）
- 用 AST 从脚本**提取函数**（不跑主流程）在 PowerShell 5.1 下实测下载，发现并修复 **3 个静态审查发现不了的运行时 bug**：
  1. `System.Net.Http` 程序集 5.1 不自动加载 → `Add-Type` 显式加载
  2. `RangeHeaderValue.From` 是 .NET Core API，5.1 的 .NET Framework 没有 → 改用构造器
  3. PowerShell 方法返回值默认输出到管道，`EnsureSuccessStatusCode()` 污染函数返回 → `$null =`
- 实测确认：完整下载 ✅、**断点续传**（4MB 半成品 → 续传后完整文件 9395475 字节分毫不差）✅、代理感知 ✅
- **教训：bat 启动器默认 powershell.exe (PS 5.1)，与 pwsh 7 行为不同，跨版本 API 必须实测**

---

## 新增功能 (v1.4)

### 🤖 Android Studio + SDK 34+
- 通过 winget `Google.AndroidStudio` 安装 Android Studio
- **国内网络适配**:
  - SDK 组件直接从 `mirrors.cloud.tencent.com` 腾讯云镜像下载
  - 无需 VPN / 梯子即可自动获取 platform-tools、build-tools 34.0.0、platform android-34
  - 自动配置 `ANDROID_HOME` / `ANDROID_SDK_ROOT` 环境变量
  - 自动追加 `platform-tools`（含 adb）到系统 PATH
- 安装方式: 从 `repository2-1.xml` 实时解析最新组件版本号，按序下载
- Android Studio 自动安装失败时提供 3 种手动方案（中国站 / 热点 / 其他电脑拷贝）

### 🐛 Bug 修复 (v1.4)
- **Install-CPP `completedSteps` 双倍计数修复**: 一键安装时 C/C++ 项只计 1 次
- **`chcp` 命令缺失修复**: 批处理 stderr 屏蔽，`chcp` 不可用时不再显示错误

---

## 新增功能 (v1.3)

### 🏗️ Apache Maven
- 从 Apache 官方源 `dlcdn.apache.org` 自动获取最新 3.x 版本并下载 zip（winget 无 Maven 包，已实测）
- 自动检测 `mvn` 命令并显示版本
- 自动搜索安装目录并配置 `MAVEN_HOME` 环境变量

### ⚙️ winget 自动安装
- 脚本启动时自动检测 `winget` 命令是否可用
- 如未检测到，自动调用 GitHub API 获取最新 `microsoft/winget-cli` Release
- 下载 `.msixbundle` 安装包并通过 `Add-AppxPackage` 安装
- 安装后刷新 PATH 并验证可用性
- 若 GitHub API 超时或网络不可达，回退打开 `https://aka.ms/getwinget` 下载页面

### 🗄️ MySQL Community Server
- 通过 `Oracle.MySQL` winget 包安装
- 支持多路径检测: PATH → `Program Files\MySQL` → `Program Files (x86)\MySQL`
- 安装后提供首次使用初始化指引:
  1. 打开 MySQL Installer 或命令行
  2. 运行 `mysqld --initialize --console` 生成随机 root 密码
  3. 运行 `mysql_secure_installation` 修改密码 + 安全加固

### 🐛 Bug 修复 (v1.3)
- **P0-1**: 菜单 `ContainsKey()` → `Contains()` (PSCustomObject 方法名修正)
- **P0-2**: Maven 无 winget 包 → 改为 Apache 官方源 `dlcdn.apache.org` 下载
- **P0-3**: MinGW PackageId `niXman.mingw-w64`（winget 实测不存在）→ 统一用 `MSYS2.MSYS2` + pacman
- **P0-4**: MSYS2 安装后追加 `pacman -S mingw-w64-ucrt64-gcc` 编译链
- **P0-5**: MySQL 检测从仅 PATH 扩展为多路径回退
- **P1**: 摘要显示 `已处理 n/9 项` (含分母) + MySQL 版本正则提取 + 菜单列对齐
- **P2**: 网络超时 (15s/120s) + 一键安装 foreach try/catch 容错

---

## 文件结构

```
dev_env_setup/
├── 启动配置工具.bat        # 主启动器 (双击即可, 推荐)
├── setup_dev_env.ps1      # PowerShell 主脚本 (v1.6, ~1200 行)
├── validate.ps1           # 静态审查脚本 (71 项检查)
├── logs/                  # 安装日志存放目录 (每次运行自动生成 *.txt)
├── LICENSE                # MIT 许可证
└── README.md              # 本说明文件
```

---

## 使用方法

### 🖥️ 本机直接使用

1. 双击 `启动配置工具.bat` (建议**右键 → 以管理员身份运行**)
2. 在菜单界面选择操作:

```
  ── 🧩 基础必备 ──
  [1]  🚀 一键安装全部 (推荐)
  [2]  🔧 Git          [3]  🗜️ 7-Zip
  [4]  🪟 Windows Terminal   [5]  ⚡ PowerToys
  [6]  📝 VS Code
  ── ☕ Java 后端 ──
  [7]  ☕ Java (JDK)   [8]  🏗️ Maven
  [9]  🗄️ MySQL        [10] 🔴 Redis
  [11] 🗄️ DBeaver      [12] ☕ Java 后端全家桶
  ── 🖥️ 前端 / Web ──
  [13] 🟢 Node.js      [14] 🖥️ 前端全家桶
  ── 🐍 Python ──
  [15] 🐍 Python       [16] 🐍 Miniconda
  [17] 🐍 Python 全家桶
  ── ⚙️ C/C++ ──
  [18] ⚙️ C/C++ (MinGW + CMake)
  ── 🤖 移动开发 ──
  [19] 🤖 Android Studio + SDK 34+
  ── 🐳 容器 / 运维 ──
  [20] 🐳 Docker       [21] ☸️ kubectl
  [22] 🐳 容器/运维全家桶
  ── 📋 系统 ──
  [23] 📋 查看当前环境摘要
  [0]  👋 退出
```

### ⌨️ PowerShell 命令行运行

```powershell
# 以管理员身份打开 PowerShell，cd 到脚本目录后执行:
Set-ExecutionPolicy Bypass -Scope Process -Force
.\setup_dev_env.ps1
```

---

## 安装流程说明

`[1] 一键安装全部` 的完整流程:

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
  10. Android     → 检测版本 → 确认 → 安装 Android Studio → 腾讯云镜像下载 SDK 组件 → 配置 ANDROID_HOME + PATH
```

每个步骤都会:
1. 检查该工具是否已安装
2. 如已安装则展示**当前版本**，询问是否重新安装/升级 (Y/N)
3. 如未安装则通过 winget 下载安装
4. 通过 `Invoke-Installer` 统一刷新 `PATH` (`Update-Path`)

安装完成后:
- 展示 **23 项环境检测摘要** (Git/Python/pip/Java/javac/Maven/GCC/G++/Node.js/npm/Docker/MySQL/CMake/VS Code/Android Studio/Android SDK/7-Zip/WinTerminal/PowerToys/Redis/Miniconda/kubectl/DBeaver)
- 询问是否**立即重启** (Docker Desktop 需要重启生效，会先提示保存工作)

---

## C/C++ 编译器检测策略

脚本按以下优先级检测已有编译器:

| 优先级 | 检测方式 | 说明 |
|--------|----------|------|
| 1 | `gcc --version` + `g++ --version` | 检测 MinGW/GCC |
| 2 | `clang --version` | 检测 Clang/LLVM |
| 3 | `vswhere.exe` + 安装目录扫描 | 检测 Visual Studio MSVC (cl.exe 不在系统 PATH 中) |

若三种编译器均已存在，脚本会提示跳过。若均不存在，则自动安装 MinGW-w64（`MSYS2.MSYS2` + pacman 安装 mingw-w64-ucrt64-gcc 编译链）。

---

## 错误处理

| 错误类型 | 现象 | 原因 |
|----------|------|------|
| **网络不可达** | `InternetOpenUrl() failed. 0x80072efd` | 机器无法访问外网，winget 无法下载 |
| **包未找到** | `No package found matching input criteria` | winget 源中不存在该包 ID |
| **Android 组件下载失败** | `远程服务器返回错误: (404)` | 镜像站命令字不匹配，脚本会自动从 XML 解析最新文件名 |

---

## Android SDK 国内镜像下载策略

为解决国内网络环境无法访问 Google 服务器的问题，Android SDK 组件采用**直接从腾讯云镜像下载**的方式：

```
① 从 mirrors.cloud.tencent.com/AndroidSDK/repository2-1.xml 实时解析最新文件名
         ↓
② platform-tools_rXX-win.zip  → extract → %LOCALAPPDATA%\Android\Sdk\platform-tools\
③ build-tools_r34-windows.zip → extract → %LOCALAPPDATA%\Android\Sdk\build-tools\34.0.0\
④ platform-34-extXX_r01.zip   → extract → %LOCALAPPDATA%\Android\Sdk\platforms\android-34\
         ↓
⑤ ANDROID_HOME / ANDROID_SDK_ROOT / PATH 自动配置
```

此方案无需 cmdline-tools 和 sdkmanager，无需 VPN 或梯子。

Android Studio 本身（Google 专有软件）无法通过镜像自动安装，脚本会打印清晰的手动指引。

---

## 系统要求

| 要求 | 说明 |
|------|------|
| 操作系统 | Windows 10 1809+ 或 Windows 11 |
| winget | 系统自带 (Win10 1809+). **若缺失，脚本会自动从 GitHub Release 下载安装** |
| 权限 | 推荐以**管理员权限**运行 |
| 网络 | 需要网络连接 (用于 winget 下载安装包) |

---

## 注意事项

1. **Docker Desktop** 安装后需要**重启系统**才能完全生效
2. **MySQL** 安装后需手动执行 `mysqld --initialize` 和 `mysql_secure_installation` 完成初始化
3. **Android Studio** 在国内网络下可能无法自动下载，脚本会自动安装 SDK 组件并给出手动下载方案
5. 部分工具 (如 MinGW-w64、Maven) 安装后，在新终端中才会加载最新的 PATH
6. 非管理员权限运行时，部分安装可能因 UAC 失败
7. 安装日志默认保存在 `logs/` 子目录下 (`logs/install_log_YYYYMMDD_HHmmss.txt`)
8. 如遇 winget 源问题，可先执行 `winget source update` 更新源
9. 脚本启动时会自动检测 winget 是否可用，不可用时从 GitHub Release 自动下载安装

---

## 安全审计摘要

v1.3 起持续用 validate.ps1 做静态审查（当前 **71 项检查**：结构 5 + 关键模式 25 + 安全 5 + 工具覆盖 23 + 冗余 13），审计维度:

| 攻击面 | 检查点 | 结果 |
|--------|--------|------|
| 命令注入 | 16 处 `&` ScriptBlock 调用 | ✅ 安全 |
| 参数注入 | 11 处 `winget install --id` | ✅ 全部硬编码 |
| 路径遍历 | 日志/文件路径操作 | ✅ 不可控 |
| 代码注入 | 全脚本 | ✅ 零 `Invoke-Expression` |
| 死代码 | 全脚本 | ✅ 零死代码 (v1.3) |
| 用户输入 | 13 处 Read-Host | ✅ 正则 + menu.Contains() |
| 网络超时 | GitHub API + 下载 | ✅ 15s / 120s |
| 安装容错 | Install-All foreach | ✅ try/catch 不中断 |

**结论: 0 个高危漏洞，0 个中危漏洞，可安全使用.**

---

## 许可证
本项目基于 [MIT License](LICENSE)