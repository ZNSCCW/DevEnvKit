# 🛠️ 开发环境一键配置工具 v2.1

适用于 **Windows 10/11** 的开发环境快速部署工具，通过 Windows 包管理器 (winget) 自动安装主流开发工具。

---

## 支持的工具（按开发方向分组）

> 共 17 个工具（GUI 勾选项），菜单已按以下分组展示；除"一键安装全部"外，每个方向还有"全家桶"批量安装项。

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
- 🚀 **一键安装全部** — 菜单选项 `[1]`，17 个工具全自动部署 (国内网络下 Android SDK 走腾讯云镜像)
- 🎯 **选择性安装** — 菜单选项 `[2]~[22]`，单独安装某个工具或按方向全家桶
- 🧩 **按方向全家桶** — 菜单选项 `[12]/[14]/[17]/[22]`，按开发方向批量安装（Java 后端/前端/Python/容器运维）
- 🔄 **智能版本检测** — 已安装工具显示当前版本，Y=升级覆盖 / N=跳过保留
- 📋 **环境摘要** — 菜单选项 `[23]`，检测 23 项组件安装状态
- 🔀 **版本切换** — 菜单 `[24]` 切换 Java 版本 (JAVA_HOME)、`[25]` 切换 Python 版本 (PATH)
- 📍 **安装位置 / 目录设置** — 菜单 `[26]` 查看已装工具安装位置、`[27]` 设置 Maven/Android SDK 安装目录
- 🗑️ **卸载** — 菜单 `[28]` 卸载已安装工具

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

## 新增功能 (v2.0)

### 🎉 图形界面主版本（v2.0 → 持续演进）
- 从 v1.x（命令行）升级为 **v2.0（图形界面为主）**：新增 WinForms GUI（`启动图形界面.bat` 双击即开），控制台版保留
- **v2.1 演进**：安装/卸载改**后台 job 执行**（窗口不卡死，日志实时刷新，完成后弹结果框）；修复卸载失效（Invoke-GuiAction 嵌套导致内层空跑）；移除无用进度条
- **打包分发**：`build.ps1` 打包单文件 exe（ps2exe + 自签名 + SHA256），防拦截策略见打包章节
- 修复 bat 启动器编码问题（改为 ASCII 提示，避免 UTF-8 无 BOM 被 cmd 按 GBK 解析产生乱码）
- 入口选择：**`启动图形界面.bat`**（GUI） / **`启动配置工具.bat`**（控制台）

---

## 新增功能 (v1.8)

### 🖥️ 图形界面（WinForms，v2.0）
- **`启动图形界面.bat`** 双击即开 GUI（或 `powershell -File devkit_gui.ps1`）
- 左侧：**17 个工具按开发方向分组勾选**（含 ☑️ 全选/全不选）；右侧：**实时日志框** + 底部按钮区
- 按钮：**⬇ 安装所选**（批量安装）、**📍 查看安装位置**、**🗑️ 卸载所选**（勾选→确认→`winget uninstall`，Maven 特例清环境变量）、**🔀 切换 JDK / 切换 Python**（InputBox 选版本，复用环境管理函数）、**☑️ 全选/全不选**
- **安装/卸载在后台 job（独立 powershell 子进程）执行，窗口全程不卡**：日志由覆盖版 `Write-Host` 写入文件、Timer 每 500ms 刷新日志框；完成后弹结果提示框并恢复按钮
- GUI 自动模式：已装工具不重复安装；**版本选择弹 ComboBox 对话框**（Java/Python/Node 安装时可选，取消用推荐版）
- **可打包成单文件 exe**：`.\build.ps1`（ps2exe + 自签名）→ `DevEnvKit.exe`

### 📍 安装位置查看与配置
- 菜单 **[26] 查看已装工具安装位置**：探测并列出全部工具的安装路径（`Get-Command` 来源 + 已知路径回退 + 环境变量），纯只读
- 菜单 **[27] 安装目录设置**：可自定义 **Maven** 安装目录（存 `devkit.conf` 配置文件）；**winget 安装的工具（JDK/Python/Node 等）位置由安装器决定，不可自定义**——如实说明

### 🗑️ 卸载已安装工具
- 菜单 **[28] 卸载**：列出 16 个可卸载工具 → 选择 → 确认（Y/N）→ `winget uninstall` 卸载
- Maven / Android 特例：卸载后**清理环境变量**（MAVEN_HOME / ANDROID_HOME / PATH 残留条目）
- 卸载前必须二次确认，避免误删

### 📄 配置文件 devkit.conf
- 工具根目录生成 `devkit.conf`（key=value），启动时自动加载（`Load-Config`），Maven 目录等自定义项持久化

---

## 新增功能 (v1.7)

### 🔀 环境管理器基础：多版本切换
- 新增菜单项 **[24] 切换 Java 版本 (JAVA_HOME)**：列出已装 Temurin JDK → 选择 → 一键切换默认
- 新增菜单项 **[25] 切换 Python 版本 (PATH)**：列出已装 Python（用户级/系统级）→ 选择 → 更新 PATH（pyenv 思路）
- `Set-JavaEnv`：**PATH 用 `%JAVA_HOME%\bin` 变量引用**（切换只改 JAVA_HOME 一处），并**自动清理 PATH 中旧 JDK 的绝对路径**（避免老版本抢先生效）
- `JAVA_HOME` 不再"只在未设置时写"——安装/切换都会更新
- **Node.js 说明**：winget 装 Node 到同一目录是**覆盖安装**（无法共存），多版本请用 `fnm` 或 `nvm-windows`——脚本不内置 Node 切换

### 🛡️ 环境变量安全（PowerShell 三件套）
- `Add-ToPath` 统一 PATH 追加：**去重（幂等）+ 2047 字符长度保护**（超限不追加并提示，避免截断导致系统命令失灵）
- `Remove-FromPath` 按正则清理旧条目（旧 JDK 路径）
- 全部 PATH 写入收敛到统一入口（MinGW / Maven / Android platform-tools）
- **双作用域处理**：`-AllScopes` 同时清理 Machine + User PATH——实测发现 winget 用户级工具（如 Python 装到 `AppData\Local\Programs\Python`）在 **User PATH**，单清 Machine 会切换失败，Java/Python 切换均已双 scope

### 🔒 下载完整性 + 兼容
- `Download-WithProgress` 支持 **SHA256/SHA512 Checksum 校验**（传 `-ExpectedHash` 即校验，不匹配自动重试）
- Maven 下载接入**官方 .sha512 校验**（拿不到则跳过，不阻塞）
- 脚本开头显示**系统架构**（arm64/x64/x86）并提示**杀毒软件拦截**风险（360/Defender）

### 🧹 注册表残留清理
- 安装 JDK 后清理 `HKLM\SOFTWARE\JavaSoft` 旧残留（Eclipse 等 IDE 读注册表，保证"干净安装"）

---

## 新增功能 (v1.6)

### 🎯 版本选择（JDK / Python / Node.js）
- 安装 JDK 时可选择 **JDK 8 / 11 / 17 / 21 (LTS)**，Python 可选 **3.11 / 3.12 / 3.13**，Node.js 可选 **20 / 22 (LTS)**
- **命令行版**：安装前弹出交互版本菜单，直接回车用推荐版本（第 1 项）
- **动态探测**：菜单末尾的「其他版本」会实时调用 `winget search` 列出该产品线**当前全部可用版本**——**未来新版本（JDK 24/25、Python 3.14 等）发布后零改动自动支持**，老版本（如 JDK 8 之前的更老版本不在 winget 内）也都能选
- **GUI 版**：勾选 Java/Python/Node 点击安装时，弹出版本选择框（ComboBox），选完再装；点「跳过此工具」则不安装
- `JAVA_HOME` 自动指向最新已装 JDK
- **版本边界**：支持 **JDK 8+**（Adoptium/Temurin 产品线下限就是 JDK 8）；JDK 5-7 需 Oracle 归档（需 Oracle 账号 + 许可），脚本不提供

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

### 📦 打包 exe 与防拦截（可选）
- **打包**：`.\build.ps1`（需 ps2exe 模块；加 `-InstallPs2Exe` 自动安装）→ 生成 `DevEnvKit.exe`（含自签名签名 + SHA256 校验输出）
- **为什么会被拦**：ps2exe 打包的 exe **无有效代码签名** + 新文件流行度低 → Defender SmartScreen / 360 等会提示
- **处理方法**：
  - Defender：点「更多信息」→「仍要运行」
  - 误报申诉：微软 WDSI（https://www.microsoft.com/en-us/wdsi/filesubmission）、360 安全卫士误报申诉、火绒安全中心
  - 攒信誉：发布到 GitHub Releases，下载量上升后 SmartScreen 自动放行
  - **零拦截方案**：直接用 `devkit_gui.ps1`（源码运行，无需 exe）——简历项目本来就要展示源码
- 注意：故意**不加壳 / 不加密**（ps2exe 的 `-encrypt`、UPX 等混淆反而**增加**启发式误报）
- **已知坑（已修复）**：ps2exe 打包后 `$PSScriptRoot` 为空字符串，会报 `Path 参数为空`——`devkit_gui.ps1` 已用 `Get-ScriptDir`（ps1 用 `$PSScriptRoot`，exe 用 `GetCommandLineArgs()[0]`）兼容两种运行方式
- **已知坑（已修复）**：ps2exe `-noConsole` 下 `Write-Host` 没有控制台可写，会**逐条弹 MessageBox**——已覆盖 `Write-Host` 为"写入日志文件"版本（日志框由 Timer 读取刷新），不再用 Start-Transcript
- **已知坑（已修复）**：bat 自动提权（`net session` 检测 + `Start-Process -Verb RunAs`）会导致**黑窗一闪即退**——回退为普通启动 + 提示"右键以管理员身份运行"；GUI 内卸载/切换前检测管理员并弹友好提示
- **已知坑（已修复）**：`.gitignore` 曾为 **UTF-16 编码**（`Add-Content -Encoding Unicode` 写入），git 只认 UTF-8/ASCII → **ignore 规则从未生效**；已转 UTF-8

---

## 新增功能 (v1.5)

### 🧩 工具扩展至 18 个，按开发方向分组
- 新增 7 个工具：7-Zip / Windows Terminal / PowerToys / Redis / Miniconda / kubectl / DBeaver
- 菜单按 **7 个开发方向分组**展示（基础必备 / Java 后端 / 前端 / Python / C-C++ / 移动 / 容器运维），见顶部工具表
- 新增 **4 个"全家桶"一键安装**：Java 后端（12）、前端（14）、Python（17）、容器运维（22）——复用现有 Install-* 函数，`$funcs.Count` 动态计数

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
├── setup_dev_env.ps1      # PowerShell 主脚本 (v2.1, ~1660 行)
├── validate.ps1           # 静态审查脚本 (81 项检查)
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
  [24] 🔀 切换 Java 版本 (JAVA_HOME)
  ── 🖥️ 前端 / Web ──
  [13] 🟢 Node.js      [14] 🖥️ 前端全家桶
  ── 🐍 Python ──
  [15] 🐍 Python       [16] 🐍 Miniconda
  [17] 🐍 Python 全家桶
  [25] 🔀 切换 Python 版本 (PATH)
  ── ⚙️ C/C++ ──
  [18] ⚙️ C/C++ (MinGW + CMake)
  ── 🤖 移动开发 ──
  [19] 🤖 Android Studio + SDK 34+
  ── 🐳 容器 / 运维 ──
  [20] 🐳 Docker       [21] ☸️ kubectl
  [22] 🐳 容器/运维全家桶
  ── 📋 系统 ──
  [23] 📋 查看当前环境摘要
  [26] 📍 查看已装工具安装位置
  [27] 📍 安装目录设置 (Maven/Android SDK)
  [28] 🗑️ 卸载已安装工具
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
  1. Git              → 检测 → 确认 → winget 安装
  2. 7-Zip            → 检测 → 确认 → winget 安装
  3. Python           → 版本选择(3.11/3.12/3.13) → 检测 → 确认 → 安装 → 验证 pip
  4. Java JDK         → 版本选择(8/11/17/21) → 检测 → 确认 → 安装 → 配置 JAVA_HOME
  5. C/C++ 工具       → 检测编译器(GCC/Clang/MSVC) → 确认 → MSYS2 + pacman 装 MinGW → 装 CMake
  6. Node.js          → 版本选择(20/22 LTS) → 检测 → 确认 → 安装 → 验证 npm
  7. Maven            → 检测 → 确认 → Apache 官方源下载(阿里云镜像回退) → 配置 MAVEN_HOME
  8. MySQL            → 检测 → 确认 → winget 安装 → 初始化指引
  9. Redis            → 检测 → 确认 → winget 安装
  10. DBeaver         → 检测 → 确认 → winget 安装
  11. Docker          → 检测 → 确认 → winget 安装
  12. kubectl         → 检测 → 确认 → winget 安装
  13. Miniconda       → 检测 → 确认 → winget 安装
  14. VS Code         → 检测 → 确认 → winget 安装
  15. Windows Terminal→ 检测 → 确认 → winget 安装
  16. PowerToys       → 检测 → 确认 → winget 安装
  17. Android         → 检测 → 确认 → 装 Android Studio → 腾讯云镜像下载 SDK 组件 → 配置 ANDROID_HOME + PATH
```

每个步骤都会:
1. 检查该工具是否已安装
2. 如已安装则展示**当前版本**，询问是否重新安装/升级 (Y/N)
3. 如未安装则安装——winget 安装 / Maven 官方源 / Android 腾讯云镜像（下载全程带**进度条 + 停滞检测 + 自动重试 + 断点续传 + 代理感知**）
4. Java / Python / Node.js 安装前先**选择版本**（回车用推荐）
5. 安装后统一刷新 `PATH`（`Update-Path`），并同步实时日志

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

v1.3 起持续用 validate.ps1 做静态审查（当前 **81 项检查**：结构 5 + 关键模式 35 + 安全 5 + 工具覆盖 23 + 冗余 13），审计维度:

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