# Windows PowerShell自动化

<cite>
**本文档引用的文件**
- [_common.ps1](file://scripts/windows/_common.ps1)
- [install_1_base_tools_bywin.ps1](file://scripts/windows/install_1_base_tools_bywin.ps1)
- [install_2_ruby_bywin.ps1](file://scripts/windows/install_2_ruby_bywin.ps1)
- [install_3_fastlane_bywin.ps1](file://scripts/windows/install_3_fastlane_bywin.ps1)
- [install_4_android_sdk_bywin.ps1](file://scripts/windows/install_4_android_sdk_bywin.ps1)
- [remove_1_android_sdk_bywin.ps1](file://scripts/windows/remove_1_android_sdk_bywin.ps1)
- [sync_version_bywin.ps1](file://scripts/windows/sync_version_bywin.ps1)
- [build_android_bywin.ps1](file://scripts/windows/build_android_bywin.ps1)
- [build_web_bywin.ps1](file://scripts/windows/build_web_bywin.ps1)
</cite>

## 更新摘要
**变更内容**
- **新增-Build选项综合参数说明**：Android构建脚本提供完整的命令行参数文档和使用示例
- **支持发布APK/AAB构建**：新增-Publish参数支持直接发布已有构建产物到GitHub/Gitee Release
- **自动versionCode递增功能**：构建时自动读取并递增versionCode，确保版本号唯一性
- **改进的用户体验功能**：增强的帮助系统、详细的进度反馈和错误提示
- **多平台发布支持**：支持GitHub和Gitee两个平台的Release发布功能

## 目录
1. [简介](#简介)
2. [项目结构](#项目结构)
3. [核心组件](#核心组件)
4. [架构概览](#架构概览)
5. [详细组件分析](#详细组件分析)
6. [依赖关系分析](#依赖关系分析)
7. [性能考虑](#性能考虑)
8. [故障排除指南](#故障排除指南)
9. [结论](#结论)

## 简介

Macro Deck Client App 是一个基于 Angular 和 Ionic 框架的跨平台应用程序，支持 Android 和 Web 平台。该项目包含了完整的 Windows PowerShell 自动化脚本系统，专门用于简化开发环境的搭建、维护和管理。

**新增-Build选项综合参数说明** 项目最新更新中为Android构建脚本提供了全面的命令行参数文档。build_android_bywin.ps1脚本现在支持多个专业级参数：-Build用于构建release APK/AAB（不发布），-Check用于仅检查构建环境，-Publish用于直接发布已有产物，-Platform指定发布平台（github/gitee），-Help显示详细帮助信息。这些参数的引入显著提升了脚本的可操作性和用户体验。

**支持发布APK/AAB构建** 最新更新的构建脚本实现了完整的发布流程自动化。通过-Publish参数，开发者可以直接将已有的APK和AAB构建产物发布到GitHub或Gitee的Release页面。该功能支持自动生成tag名称（格式：v<versionName>+<versionCode>）、上传构建产物、读取RELEASE_NOTES.md作为发布说明，以及处理认证和权限验证等复杂场景。

**自动versionCode递增功能** 构建脚本现在具备智能的版本号管理能力。在构建过程中，系统会自动从android/app/build.gradle读取当前versionCode值，然后递增1作为新的BUILD_NUMBER环境变量。这一机制确保了每次构建都生成唯一的版本号，避免了版本冲突问题。同时，versionName保持不变，保持语义化版本的一致性。

**改进的用户体验功能** 整个脚本系统进行了全面的用户体验优化。包括增强的帮助系统输出、详细的进度反馈、清晰的错误提示信息、中文本地化的用户界面等。特别是在发布流程中，提供了实时的进度显示、详细的错误诊断信息和友好的修复建议，大大降低了使用门槛。

**多平台发布支持** 最新版本支持两个主要代码托管平台的Release发布功能。对于GitHub平台，需要安装并登录gh CLI工具；对于Gitee平台，需要在本地签名配置文件中设置GITEE_TOKEN环境变量。两种平台都支持完整的发布流程，包括创建Release、上传构建产物和处理错误情况。

这些 PowerShell 脚本提供了从基础环境检查到复杂工具链安装的全方位自动化支持，特别针对 Windows 开发环境进行了深度优化。脚本系统采用模块化设计，通过共享的通用函数库实现代码复用，确保了一致的用户体验和可靠的执行流程。

## 项目结构

项目中的 Windows PowerShell 自动化脚本主要位于 `scripts/windows/` 目录下，现已发展为包含十个核心脚本的完整生态系统：

```mermaid
graph TB
subgraph "Windows PowerShell自动化脚本系统"
Common[_common.ps1<br/>通用函数库<br/>新增Resolve-JunctionPath函数<br/>新增Java版本验证函数<br/>新增Set-AndroidGradleValue函数<br/>新增Sync-AppVersion版本同步函数]
subgraph "基础工具管理"
BaseTools[install_1_base_tools_bywin.ps1<br/>基础工具安装]
end
subgraph "Ruby + Fastlane工具链"
InstallRuby[install_2_ruby_bywin.ps1<br/>Ruby + Devkit安装<br/>新增PATH同步机制<br/>新增RubyGems镜像检测]
InstallFastlane[install_3_fastlane_bywin.ps1<br/>Fastlane安装<br/>新增PATH同步机制<br/>新增Bundler版本检查<br/>新增Ruby 4.0+兼容性]
end
subgraph "Android SDK安装"
InstallSDK[install_4_android_sdk_bywin.ps1<br/>Android SDK安装<br/>新增Java版本验证]
end
subgraph "应用构建脚本"
BuildAndroid[build_android_bywin.ps1<br/>Android应用构建<br/>新增-Build选项参数说明<br/>新增自动versionCode递增<br/>新增发布功能]
BuildWeb[build_web_bywin.ps1<br/>Web应用构建<br/>新增版本同步集成]
end
subgraph "版本同步脚本"
SyncVersion[sync_version_bywin.ps1<br/>版本号同步脚本<br/>参数化版本设置<br/>增强帮助系统]
end
subgraph "卸载清理脚本"
RemoveSDK[remove_1_android_sdk_bywin.ps1<br/>Android SDK卸载]
RemoveRuby[remove_3_ruby_bywin.ps1<br/>Ruby卸载]
end
Common --> BaseTools
Common --> InstallRuby
Common --> InstallFastlane
Common --> InstallSDK
Common --> BuildAndroid
Common --> BuildWeb
Common --> SyncVersion
Common --> RemoveSDK
Common --> RemoveRuby
InstallRuby --> InstallFastlane
InstallFastlane --> BuildAndroid
InstallFastlane --> BuildWeb
InstallSDK --> BuildAndroid
BuildAndroid --> SyncVersion
BuildWeb --> SyncVersion
RemoveSDK --> BuildAndroid
RemoveRuby --> BuildAndroid
BaseTools --> InstallRuby
BaseTools --> InstallFastlane
BaseTools --> InstallSDK
```

**图表来源**
- [scripts/windows/_common.ps1:1-1344](file://scripts/windows/_common.ps1#L1-L1344)
- [scripts/windows/install_1_base_tools_bywin.ps1:1-930](file://scripts/windows/install_1_base_tools_bywin.ps1#L1-L930)
- [scripts/windows/install_2_ruby_bywin.ps1:1-173](file://scripts/windows/install_2_ruby_bywin.ps1#L1-L173)
- [scripts/windows/install_3_fastlane_bywin.ps1:1-218](file://scripts/windows/install_3_fastlane_bywin.ps1#L1-L218)
- [scripts/windows/install_4_android_sdk_bywin.ps1:1-249](file://scripts/windows/install_4_android_sdk_bywin.ps1#L1-L249)
- [scripts/windows/remove_1_android_sdk_bywin.ps1:1-162](file://scripts/windows/remove_1_android_sdk_bywin.ps1#L1-L162)
- [scripts/windows/build_android_bywin.ps1:1-352](file://scripts/windows/build_android_bywin.ps1#L1-L352)
- [scripts/windows/build_web_bywin.ps1:1-298](file://scripts/windows/build_web_bywin.ps1#L1-L298)
- [scripts/windows/sync_version_bywin.ps1:1-80](file://scripts/windows/sync_version_bywin.ps1#L1-L80)

**章节来源**
- [scripts/windows/_common.ps1:1-1344](file://scripts/windows/_common.ps1#L1-L1344)
- [scripts/windows/install_1_base_tools_bywin.ps1:1-930](file://scripts/windows/install_1_base_tools_bywin.ps1#L1-L930)
- [scripts/windows/install_2_ruby_bywin.ps1:1-173](file://scripts/windows/install_2_ruby_bywin.ps1#L1-L173)
- [scripts/windows/install_3_fastlane_bywin.ps1:1-218](file://scripts/windows/install_3_fastlane_bywin.ps1#L1-L218)
- [scripts/windows/install_4_android_sdk_bywin.ps1:1-249](file://scripts/windows/install_4_android_sdk_bywin.ps1#L1-L249)
- [scripts/windows/remove_1_android_sdk_bywin.ps1:1-162](file://scripts/windows/remove_1_android_sdk_bywin.ps1#L1-L162)
- [scripts/windows/build_android_bywin.ps1:1-352](file://scripts/windows/build_android_bywin.ps1#L1-L352)
- [scripts/windows/build_web_bywin.ps1:1-298](file://scripts/windows/build_web_bywin.ps1#L1-L298)
- [scripts/windows/sync_version_bywin.ps1:1-80](file://scripts/windows/sync_version_bywin.ps1#L1-L80)

## 核心组件

### 通用函数库 (_common.ps1)

这是整个 PowerShell 自动化系统的核心基础设施，提供了以下关键功能：

#### 日志记录系统
- **成功日志** (`Write-Ok`): 绿色显示成功信息
- **警告日志** (`Write-Warn`): 黄色显示警告信息  
- **失败日志** (`Write-Fail`): 红色显示错误信息
- **状态行** (`Write-StatusLine`): 统一的状态显示格式
- **横幅输出** (`Write-Banner`): 格式化的标题横幅

#### 交互确认机制
- **自动确认模式**: 支持 `-y` 静默模式
- **菜单选择系统**: 统一的编号菜单界面
- **确认对话框**: 支持默认值和自动确认标签

#### 系统集成工具
- **原生命令执行**: 处理 PowerShell 5.1 的特殊兼容性问题
- **路径管理**: 自动添加到 PATH 和用户环境变量
- **下载管理**: 多源并行下载和文件校验
- **编译器检测**: MSVC 和 GNU 工具链的智能检测

#### 命令执行增强功能
**更新** Install-WingetPackage函数现在提供更好的命令执行可视化：

- **命令显示增强** (`Install-WingetPackage`): 在执行winget安装时显示完整的命令行，便于调试和审计
- **进度条优化** (`Invoke-NativeStream`): 改进的进度条显示，支持单行覆盖避免刷屏
- **错误处理改进**: 更好的错误信息输出和异常处理

#### 新增的Ionic + Capacitor + fastlane工具链支持
- **环境变量验证** (`Require-Env`): 确保必需环境变量存在
- **命令执行封装** (`Invoke-InRoot`, `Invoke-NativeIn`): 统一的命令执行接口
- **依赖管理** (`Ensure-NodeModules`): 处理npm peer dependency冲突
- **前端构建** (`Invoke-IonicBuild`): Ionic Web应用构建
- **平台同步** (`Invoke-CapSync`): Capacitor平台同步
- **fastlane集成** (`Get-FastlaneBundleRoot`, `Get-FastlaneCommand`): Ruby + fastlane工具链管理
- **Android配置** (`Read-AndroidGradleValue`, `Load-AndroidSigningPs1`): Android构建配置管理

#### **新增** NTFS junction路径解析功能
**重大更新** 新增了Resolve-JunctionPath函数，专门解决Windows开发环境中的路径解析问题：

- **路径解析** (`Resolve-JunctionPath`): 将路径中的NTFS junction解析为真实物理路径
- **兼容性处理**: 解决PowerShell Resolve-Path与Node.js/webpack路径解析不一致的问题
- **标准API实现**: 基于.NET API，无需管理员权限，不依赖fsutil
- **逐级检查机制**: 从当前路径向上逐级检查junction并替换为Substitute Name
- **根目录处理**: 根目录（如C:\）直接返回，避免不必要的处理

#### **新增** Java版本验证功能
**重大更新** 新增了精确的Java版本验证函数，确保Android构建环境的兼容性：

- **Java版本检测** (`Get-JavaMajorVersion`): 检测当前安装的Java主版本号
- **Java 17+验证** (`Assert-Java17`): 强制要求Java 17+版本
- **Android专用Java验证** (`Assert-JavaForAndroid`): 强制JDK 17-21版本范围，确保Gradle 8.13兼容性

#### **新增** Android Gradle值修改功能
**重大更新** 新增了精确的Android Gradle文件值修改功能：

- **版本值修改** (`Set-AndroidGradleValue`): 安全修改build.gradle中的versionCode和versionName
- **正则表达式匹配**: 精确匹配Gradle文件中的键值对
- **UTF-8无BOM写回**: 确保文件编码一致性
- **版本名自动引号**: versionName自动添加双引号，versionCode保持整数格式

#### **新增** 版本同步功能
**重大更新** 新增了完整的版本同步机制，确保三端版本一致性：

- **版本同步函数** (`Sync-AppVersion`): 从android/app/build.gradle读取版本信息并同步到iOS和Web
- **iOS版本同步** (`CURRENT_PROJECT_VERSION`, `MARKETING_VERSION`): 更新Xcode工程的版本信息
- **Web版本同步** (`environment*.ts`): 更新四个环境配置文件的版本信息
- **版本读取函数** (`Read-AndroidGradleValue`): 从Gradle文件读取版本字段

#### **新增** Android签名配置管理
**重大更新** 新增了完整的Android签名配置管理功能：

- **本地签名加载** (`Load-AndroidSigningPs1`): 加载本地Android签名配置
- **签名配置帮助** (`Print-AndroidSigningHelp`): 输出签名配置创建指导
- **环境变量管理**: 自动设置KEYSTORE_FILE_PASSWORD等必需环境变量

**章节来源**
- [scripts/windows/_common.ps1:22-61](file://scripts/windows/_common.ps1#L22-L61)
- [scripts/windows/_common.ps1:63-65](file://scripts/windows/_common.ps1#L63-L65)
- [scripts/windows/_common.ps1:11-120](file://scripts/windows/_common.ps1#L11-L120)
- [scripts/windows/_common.ps1:123-213](file://scripts/windows/_common.ps1#L123-L213)
- [scripts/windows/_common.ps1:242-341](file://scripts/windows/_common.ps1#L242-L341)
- [scripts/windows/_common.ps1:945-972](file://scripts/windows/_common.ps1#L945-972)
- [scripts/windows/_common.ps1:284-329](file://scripts/windows/_common.ps1#L284-L329)
- [scripts/windows/_common.ps1:1161-1180](file://scripts/windows/_common.ps1#L1161-L1180)
- [scripts/windows/_common.ps1:1194-1238](file://scripts/windows/_common.ps1#L1194-L1238)
- [scripts/windows/_common.ps1:1249-1289](file://scripts/windows/_common.ps1#L1249-L1289)

### 基础工具管理脚本 (install_1_base_tools_bywin.ps1)

**新增** 该脚本提供了Windows基础工具的完整管理功能，包括winget、Windows终端和Microsoft Store的安装与配置。

#### 核心功能特性
- **winget管理**: 自动检测、安装和配置winget包管理器
- **Windows终端**: 支持多种安装方式（GitHub、winget、Microsoft Store）
- **Microsoft Store**: 系统组件的自动安装与验证
- **Node.js LTS**: 作为Ionic + Capacitor构建的前置依赖

#### 智能安装策略
- **多源下载**: 优先使用GitHub镜像，失败时回退到官方源
- **安装包验证**: 下载完成后进行文件大小校验
- **安装后验证**: 自动检测安装结果并输出详细信息

**章节来源**
- [scripts/windows/install_1_base_tools_bywin.ps1:47-80](file://scripts/windows/install_1_base_tools_bywin.ps1#L47-L80)
- [scripts/windows/install_1_base_tools_bywin.ps1:176-259](file://scripts/windows/install_1_base_tools_bywin.ps1#L176-L259)
- [scripts/windows/install_1_base_tools_bywin.ps1:321-440](file://scripts/windows/install_1_base_tools_bywin.ps1#L321-L440)

### Ruby + Fastlane工具链安装脚本

**重大更新** 该脚本提供了Ruby + fastlane工具链的智能安装功能，专门用于Android应用构建。最新版本引入了革命性的多源下载机制和增强的功能。

#### Ruby安装功能
- **智能版本检测**: 优先安装Ruby 4.0+，降级到3.4、3.3
- **Devkit集成**: 自动安装Ruby + Devkit组合包
- **winget集成**: 通过winget进行Ruby安装
- **多源下载机制**: 并行竞速选择最优下载源
- **UTF-8支持**: 通过Inno Setup参数启用defaultutf8任务
- **PATH配置**: 通过Inno Setup参数启用modpath任务

#### Fastlane安装功能
- **Gemfile集成**: 通过Bundler管理fastlane依赖
- **环境隔离**: 使用Gemfile固定fastlane版本
- **命令验证**: 确保fastlane命令可用

#### 新增功能特性
- **RubyGems镜像检测**: 动态探测可用的国内RubyGems镜像源
- **多源下载源**: gh-proxy.com、ghfast.top、github.com
- **并行测速**: 自动选择最快下载源
- **文件大小校验**: 防止下载到错误页面
- **详细错误处理**: 提供下载失败和安装失败的具体原因
- **用户界面优化**: 更清晰的进度反馈和状态提示
- **PATH同步机制**: 新增Sync-PathFromRegistry函数解决PATH同步问题
- **Bundler版本检查**: 新增Test-LockfileBundlerMismatch函数确保版本兼容性
- **Ruby 4.0+兼容性**: **新增** 支持Ruby 4.0+的Fastlane集成

#### RubyGems镜像检测系统
**更新** 动态探测RubyGems镜像源：

```powershell
function Select-GemMirror {
  $candidates = @(
    'https://mirrors.cloud.tencent.com/rubygems/',
    'https://repo.huaweicloud.com/repository/rubygems/'
  )
  foreach ($m in $candidates) {
    try {
      # 探测 /info/fastlane（compact index 的依赖解析端点）。必须禁止自动重定向：
      # 部分镜像该端点会 302 跳回 rubygems.org，跟随后会拿到 200 的假象。
      # 只有"直接 200、无 Location 跳转"的镜像才能真正离线解析依赖。
      $probe = ($m.TrimEnd('/')) + '/info/fastlane'
      $req = [System.Net.HttpWebRequest]::Create($probe)
      $req.Method = 'HEAD'
      $req.Timeout = 8000
      $req.AllowAutoRedirect = $false
      $resp = $req.GetResponse()
      $code = [int]$resp.StatusCode
      $resp.Close()
      if ($code -eq 200) {
        Write-Ok "选用 RubyGems 镜像：$m"
        return $m
      }
      Write-Warn "镜像 $m 的 /info 返回 $code（疑似重定向），尝试下一个"
    } catch {
      Write-Warn "镜像不可用，尝试下一个：$m"
    }
  }
  return $null
}
```

该函数会依次探测两个国内RubyGems镜像源，自动选择可用的镜像源，显著提升了下载成功率和速度。新的镜像源包括腾讯云和华为云，替代了之前的USTC、清华、Ruby-China镜像。

#### PATH同步机制
**新增** Ruby安装后立即同步PATH环境变量：

```powershell
function Sync-PathFromRegistry {
  $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
  $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
  $merged = @($machinePath, $userPath |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join ';'
  if (-not [string]::IsNullOrWhiteSpace($merged)) {
    $env:Path = $merged
  }
}
```

该函数从注册表重新读取机器级和用户级PATH，合并注入当前PowerShell会话，确保Ruby和Bundler在当前会话中立即可用。

#### Bundler版本兼容性检查
**新增** 确保Gemfile.lock与当前Bundler版本兼容：

```powershell
function Test-LockfileBundlerMismatch {
  param([Parameter(Mandatory)] [string]$BundleRoot)

  $lockfile = Join-Path $BundleRoot 'Gemfile.lock'
  if (-not (Test-Path -LiteralPath $lockfile)) { return $false }

  $lines = Get-Content -LiteralPath $lockfile -ErrorAction SilentlyContinue
  $idx = [Array]::FindIndex($lines, [Predicate[string]] { param($l) $l.Trim() -eq 'BUNDLED WITH' })
  if ($idx -lt 0 -or $idx + 1 -ge $lines.Count) { return $false }
  $lockedVersion = $lines[$idx + 1].Trim()
  if ([string]::IsNullOrWhiteSpace($lockedVersion)) { return $false }

  $currentVersion = (Invoke-NativeText -FilePath 'bundle' -Arguments @('--version') |
    Select-Object -First 1) -replace '[^0-9.]', ''
  if ([string]::IsNullOrWhiteSpace($currentVersion)) { return $false }

  return ($lockedVersion -ne $currentVersion)
}
```

该函数会自动检测lockfile中的BUNDLED WITH版本，并与当前Bundler版本进行对比，必要时自动对齐版本。

#### Ruby 4.0+兼容性增强
**新增** 解决Ruby 4.0+的Fastlane集成问题：

```ruby
# android/Gemfile
source "https://rubygems.org"

gem 'fastlane'
gem 'fiddle'  # Ruby 4.0 起 fiddle 不再是默认 gem，fastlane 依赖链需要
```

自Ruby 4.0起，fiddle不再作为默认gem包含，但fastlane依赖链需要此gem才能正常工作。通过在android/Gemfile中显式声明gem 'fiddle'，确保了在Ruby 4.0+环境中Fastlane的稳定运行。

**章节来源**
- [scripts/windows/install_2_ruby_bywin.ps1:16-42](file://scripts/windows/install_2_ruby_bywin.ps1#L16-L42)
- [scripts/windows/install_2_ruby_bywin.ps1:52-85](file://scripts/windows/install_2_ruby_bywin.ps1#L52-L85)
- [scripts/windows/install_2_ruby_bywin.ps1:98-129](file://scripts/windows/install_2_ruby_bywin.ps1#L98-L129)
- [scripts/windows/install_2_ruby_bywin.ps1:32-40](file://scripts/windows/install_2_ruby_bywin.ps1#L32-L40)
- [scripts/windows/install_2_ruby_bywin.ps1:124-139](file://scripts/windows/install_2_ruby_bywin.ps1#L124-L139)

### Fastlane安装脚本 (install_3_fastlane_bywin.ps1)

**重大更新** 该脚本提供了fastlane的智能安装功能，基于Bundler和Gemfile进行依赖管理。最新版本增强了RubyGems镜像检测和Bundler版本兼容性检查功能。

#### 核心功能特性
- **Gemfile检测**: 自动查找包含fastlane声明的Gemfile
- **Bundler集成**: 通过bundle install安装fastlane及其依赖
- **命令解析**: 优先使用bundle exec fastlane确保版本一致性
- **RubyGems镜像检测**: 动态探测可用的国内RubyGems镜像源
- **Bundler版本检查**: 确保Gemfile.lock与当前Bundler版本兼容
- **Ruby 4.0+兼容性**: **新增** 支持Ruby 4.0+的Fastlane集成

#### 高级功能
- **多目录支持**: 优先检查android/Gemfile，再检查仓库根目录
- **版本管理**: 通过Gemfile固定fastlane版本
- **环境隔离**: 避免全局fastlane版本冲突
- **PATH同步机制**: 新增Sync-PathFromRegistry函数确保PATH立即生效
- **镜像配置**: 自动配置bundle config mirror以提升下载速度
- **版本对齐**: 自动处理Bundler版本不匹配问题

**章节来源**
- [scripts/windows/install_3_fastlane_bywin.ps1:16-42](file://scripts/windows/install_3_fastlane_bywin.ps1#L16-L42)
- [scripts/windows/install_3_fastlane_bywin.ps1:52-85](file://scripts/windows/install_3_fastlane_bywin.ps1#L52-L85)
- [scripts/windows/install_3_fastlane_bywin.ps1:98-129](file://scripts/windows/install_3_fastlane_bywin.ps1#L98-L129)

### Android SDK安装脚本 (install_4_android_sdk_bywin.ps1)

**更新** 该脚本提供了完整的Android开发环境安装解决方案：

#### 核心功能
- **SDKManager引导安装**: 自动下载和安装命令行工具
- **Java 17环境检查**: 确保 Java 17 正确配置
- **组件安装**: 平台工具、平台和构建工具
- **环境变量配置**: 用户级和当前会话环境变量设置

#### 智能检测机制
- 多种 SDK 根目录定位策略
- 自动版本推导和验证
- 组件完整性检查

#### **新增** Java版本验证集成
**重大更新** 在Android SDK安装过程中集成了新的Java版本验证：

```powershell
Write-Host "[2/6] 检查 Java 环境" -ForegroundColor Cyan
if (-not (Assert-Java17)) { exit 1 }
```

该验证确保Android SDK安装前具备Java 17+环境，为后续的Android构建做好准备。

**章节来源**
- [scripts/windows/install_4_android_sdk_bywin.ps1:35-92](file://scripts/windows/install_4_android_sdk_bywin.ps1#L35-L92)
- [scripts/windows/install_4_android_sdk_bywin.ps1:127-150](file://scripts/windows/install_4_android_sdk_bywin.ps1#L127-L150)
- [scripts/windows/install_4_android_sdk_bywin.ps1:189-249](file://scripts/windows/install_4_android_sdk_bywin.ps1#L189-L249)

### **更新** Android应用构建脚本 (build_android_bywin.ps1)

**重大更新** 该脚本提供了完整的 Android 应用构建支持，集成了Ionic + Capacitor + fastlane工具链，并新增了综合的-Build选项参数说明和发布功能。

#### 新增的综合参数系统
**重大更新** 构建了完整的命令行参数体系：

- **-Build参数**: 构建 release APK/AAB（不发布），versionCode 自动递增
- **-Check参数**: 只检查签名变量、npx、fastlane 是否可用，不执行 Web/Android 构建
- **-Publish参数**: 仅发布：跳过构建，直接把已有 APK+AAB 发布到 Release
- **-Platform参数**: 发布平台，仅与 -Publish 搭配使用。可选值：github（默认）、gitee
- **-Help参数**: 显示本帮助（参数说明与用法示例）后退出，不执行任何构建

#### 自动versionCode递增功能
**重大更新** 实现了智能的版本号管理机制：

```powershell
$currentCode = Read-AndroidGradleValue 'versionCode'
$parsed = 0
if ([int]::TryParse($currentCode, [ref]$parsed)) {
  $env:BUILD_NUMBER = ($parsed + 1).ToString()
  Write-Ok "versionCode 自动递增：$currentCode -> $env:BUILD_NUMBER"
} else {
  Write-Warn "无法解析当前 versionCode（'$currentCode'），BUILD_NUMBER 回退为 1"
  $env:BUILD_NUMBER = '1'
}
```

该功能确保每次构建都生成唯一的版本号，避免版本冲突问题。

#### 多平台发布功能
**重大更新** 支持GitHub和Gitee两个平台的Release发布：

- **GitHub发布**: 通过gh CLI工具进行认证和发布
- **Gitee发布**: 通过REST API直接调用，支持自定义token
- **产物验证**: 自动检查APK和AAB文件是否存在
- **说明文件处理**: 从RELEASE_NOTES.md读取发布说明
- **Tag管理**: 自动生成格式化的tag名称（v<versionName>+<versionCode>）

#### 增强的用户体验功能
**重大更新** 提供了全面的用户界面优化：

- **详细帮助系统**: 完整的参数说明和使用示例
- **实时进度反馈**: 构建和发布过程中的详细进度显示
- **错误诊断**: 具体的错误信息和修复建议
- **中文本地化**: 所有用户界面消息均为中文

#### 特殊优化
- **本地签名配置**: 支持scripts/local/android-signing.ps1
- **环境变量管理**: 自动从build.gradle读取版本信息
- **命令执行封装**: 统一的命令执行和错误处理
- **版本同步**: 构建完成后自动同步版本号到iOS和Web

**章节来源**
- [scripts/windows/build_android_bywin.ps1:10-47](file://scripts/windows/build_android_bywin.ps1#L10-L47)
- [scripts/windows/build_android_bywin.ps1:56-80](file://scripts/windows/build_android_bywin.ps1#L56-L80)
- [scripts/windows/build_android_bywin.ps1:132-171](file://scripts/windows/build_android_bywin.ps1#L132-L171)
- [scripts/windows/build_android_bywin.ps1:174-303](file://scripts/windows/build_android_bywin.ps1#L174-L303)
- [scripts/windows/build_android_bywin.ps1:305-352](file://scripts/windows/build_android_bywin.ps1#L305-L352)

### **新增** Web应用构建脚本 (build_web_bywin.ps1)

**重大更新** 该脚本提供了完整的 Web 应用构建支持，集成了版本同步功能以确保Web构建时的版本一致性。

#### 核心功能
- **版本同步集成**: 构建前自动从android/app/build.gradle同步版本信息到Web环境
- **Ionic构建**: 使用指定配置构建Web资源
- **缓存管理**: 支持清理Angular缓存以解决编译问题
- **构建验证**: 验证构建产物的存在和完整性

#### **新增** 版本同步集成
**重大更新** 在Web构建前自动执行版本同步：

```powershell
# ─── 版本同步：以 build.gradle 为源，写入 environment*.ts，使界面显示与 Android 一致 ───
Write-Host "[版本同步] 从 android/app/build.gradle 同步版本到 Web" -ForegroundColor Cyan
Sync-AppVersion
Write-Host ""
```

该功能确保Web界面显示的版本信息与Android构建的版本信息保持一致。

#### 特殊优化
- **环境文件同步**: 自动更新四个environment*.ts文件的版本信息
- **构建缓存清理**: 支持清理Angular缓存以解决编译问题
- **构建产物验证**: 验证www目录和index.html的存在

**章节来源**
- [scripts/windows/build_web_bywin.ps1:266-268](file://scripts/windows/build_web_bywin.ps1#L266-L268)
- [scripts/windows/build_web_bywin.ps1:271-298](file://scripts/windows/build_web_bywin.ps1#L271-L298)

### **新增** 版本同步脚本 (sync_version_bywin.ps1)

**重大更新** 该脚本提供了独立的版本号同步功能，专门用于在不进行完整构建的情况下同步三端版本号。

#### 核心功能特性
- **参数化版本设置**: 支持通过命令行参数直接设置版本号
- **独立版本同步**: 仅同步版本号，不执行构建流程
- **版本源权威性**: 以android/app/build.gradle为唯一版本权威源
- **三端同步**: 同步到iOS和Web平台的版本信息
- **解耦构建**: 与构建流程解耦，适合"只想对齐版本号"的场景
- **增强帮助系统**: 提供完整的使用示例和参数说明

#### 版本同步机制
- **iOS同步**: 更新project.pbxproj的CURRENT_PROJECT_VERSION和MARKETING_VERSION
- **Web同步**: 更新四个environment*.ts文件的version和versionCode
- **UTF-8无BOM写回**: 确保文件编码一致性

#### 参数化功能
- **VersionName参数**: 设置版本名（如3.1.0）
- **VersionCode参数**: 设置版本号（正整数）
- **Help参数**: 显示详细帮助信息
- **自动验证**: VersionCode参数的正整数验证

#### 使用场景
- **版本对齐**: 当需要快速同步三端版本号而不需要完整构建时
- **预发布检查**: 在正式构建前验证版本号一致性
- **CI/CD集成**: 在持续集成流程中单独执行版本同步步骤
- **手动版本设置**: 直接通过命令行设置版本号并同步

**章节来源**
- [scripts/windows/sync_version_bywin.ps1:1-80](file://scripts/windows/sync_version_bywin.ps1#L1-L80)

## 架构概览

整个 PowerShell 自动化系统采用分层架构设计，确保了高内聚、低耦合的特性：

```mermaid
graph TB
subgraph "用户接口层"
CLI[命令行界面]
Menu[交互菜单]
Help[帮助系统]
end
subgraph "业务逻辑层"
EnvCheck[环境检查]
Install[安装流程]
Uninstall[卸载流程]
Build[构建流程]
BaseTools[基础工具管理]
RubyFastlane[Ruby + Fastlane管理]
AndroidSetup[Android环境配置]
VersionSync[版本同步管理]
JunctionPath[NTFS junction路径解析]
ReleasePublish[发布管理<br/>新增多平台发布功能]
AutoVersioning[自动版本管理<br/>新增versionCode递增]
end
subgraph "基础设施层"
Common[通用函数库<br/>新增Resolve-JunctionPath函数<br/>新增Java版本验证<br/>新增Set-AndroidGradleValue函数<br/>新增Sync-AppVersion版本同步函数<br/>新增Android签名配置管理]
Helpers[辅助工具]
Download[下载引擎]
Registry[注册表操作]
Mirror[RubyGems镜像检测]
IonicCapacitor[Ionic + Capacitor集成]
Fastlane[fastlane工具链]
Ruby[Ruby + Devkit]
AndroidSDK[Android SDK]
NodeJS[Node.js]
NPM[npm]
Winget[Winget包管理器]
WindowsTerminal[Windows终端]
MicrosoftStore[Microsoft Store]
Bundler[Bundler版本检查]
PATH[PATH同步机制]
Ruby40Compatibility[Ruby 4.0+兼容性]
JavaValidation[Java版本验证<br/>新增JDK 17-21强制验证]
VersionSyncFunction[版本同步函数<br/>新增三端版本统一]
AndroidGradleValue[Android Gradle值修改<br/>新增精确版本设置]
SignConfig[Android签名配置<br/>新增本地配置加载]
JunctionPathFunction[NTFS junction路径解析<br/>新增路径兼容性处理]
GitHubRelease[GitHub Release API<br/>新增发布功能]
GiteeRelease[Gitee Release API<br/>新增发布功能]
ArtifactValidation[构建产物验证<br/>新增APK/AAB检查]
end
CLI --> EnvCheck
CLI --> Install
CLI --> Uninstall
CLI --> Build
CLI --> BaseTools
CLI --> RubyFastlane
CLI --> AndroidSetup
CLI --> VersionSync
CLI --> JunctionPath
CLI --> ReleasePublish
CLI --> AutoVersioning
EnvCheck --> Common
Install --> Common
Uninstall --> Common
Build --> Common
BaseTools --> Common
RubyFastlane --> Common
AndroidSetup --> Common
VersionSync --> Common
JunctionPath --> Common
ReleasePublish --> Common
AutoVersioning --> Common
Common --> Helpers
Common --> Download
Common --> Registry
Common --> Mirror
Common --> Bundler
Common --> PATH
Common --> Ruby40Compatibility
Common --> JavaValidation
Common --> VersionSyncFunction
Common --> AndroidGradleValue
Common --> SignConfig
Common --> JunctionPathFunction
Common --> GitHubRelease
Common --> GiteeRelease
Common --> ArtifactValidation
Install --> Ruby
Install --> Fastlane
Install --> AndroidSDK
Install --> NodeJS
Install --> Winget
Install --> WindowsTerminal
Install --> MicrosoftStore
Build --> IonicCapacitor
Build --> Fastlane
Build --> AndroidSetup
Build --> VersionSyncFunction
Build --> JunctionPathFunction
Build --> AutoVersioning
ReleasePublish --> GitHubRelease
ReleasePublish --> GiteeRelease
ReleasePublish --> ArtifactValidation
RubyFastlane --> Ruby
RubyFastlane --> Fastlane
AndroidSetup --> AndroidSDK
VersionSync --> VersionSyncFunction
VersionSync --> AndroidGradleValue
JunctionPath --> JunctionPathFunction
AutoVersioning --> AndroidGradleValue
```

**图表来源**
- [scripts/windows/_common.ps1:1-1344](file://scripts/windows/_common.ps1#L1-L1344)
- [scripts/windows/install_1_base_tools_bywin.ps1:1-930](file://scripts/windows/install_1_base_tools_bywin.ps1#L1-L930)
- [scripts/windows/install_2_ruby_bywin.ps1:1-173](file://scripts/windows/install_2_ruby_bywin.ps1#L1-L173)
- [scripts/windows/install_3_fastlane_bywin.ps1:1-218](file://scripts/windows/install_3_fastlane_bywin.ps1#L1-L218)
- [scripts/windows/install_4_android_sdk_bywin.ps1:1-249](file://scripts/windows/install_4_android_sdk_bywin.ps1#L1-L249)
- [scripts/windows/remove_1_android_sdk_bywin.ps1:1-162](file://scripts/windows/remove_1_android_sdk_bywin.ps1#L1-L162)
- [scripts/windows/build_android_bywin.ps1:1-352](file://scripts/windows/build_android_bywin.ps1#L1-L352)
- [scripts/windows/build_web_bywin.ps1:1-298](file://scripts/windows/build_web_bywin.ps1#L1-L298)
- [scripts/windows/sync_version_bywin.ps1:1-80](file://scripts/windows/sync_version_bywin.ps1#L1-L80)

## 详细组件分析

### **更新** Android构建流程详细分析

```mermaid
sequenceDiagram
participant User as 用户
participant BuildScript as Android构建脚本
participant Common as 通用函数
participant JavaValidation as Java版本验证
participant VersionSync as 版本同步函数
participant JunctionPath as 路径解析函数
participant AutoVersioning as 自动版本管理
participant ReleasePublish as 发布管理
participant Ionic as Ionic CLI
participant Capacitor as Capacitor CLI
participant Fastlane as fastlane
participant GitHubAPI as GitHub API
participant GiteeAPI as Gitee API
User->>BuildScript : 执行build_android_bywin.ps1 -Build/-Publish/-Check
BuildScript->>Common : 加载签名配置
BuildScript->>Common : 验证环境变量
BuildScript->>JavaValidation : Assert-JavaForAndroid验证
JavaValidation->>Common : Get-JavaMajorVersion检测
JavaValidation-->>BuildScript : 返回JDK 17-21验证结果
BuildScript->>AutoVersioning : 自动versionCode递增
AutoVersioning->>Common : Read-AndroidGradleValue读取versionCode
AutoVersioning-->>BuildScript : 返回递增后的BUILD_NUMBER
BuildScript->>Common : Require-AndroidReleaseEnv验证
Common->>Common : Read-AndroidGradleValue读取版本
Common->>Common : 忽略残留环境变量，强制使用build.gradle
BuildScript->>JunctionPath : Resolve-JunctionPath解析项目路径
JunctionPath->>Common : 规范化路径并检查junction
JunctionPath-->>BuildScript : 返回真实物理路径
alt -Publish模式
BuildScript->>ReleasePublish : 执行发布流程
ReleasePublish->>ArtifactValidation : 验证APK/AAB文件存在
ReleasePublish->>GitHubAPI : GitHub发布如果Platform=github
ReleasePublish->>GiteeAPI : Gitee发布如果Platform=gitee
ReleasePublish-->>BuildScript : 返回发布结果
else -Build模式
BuildScript->>Ionic : ionic build production
Ionic-->>BuildScript : 返回构建结果
BuildScript->>Capacitor : cap sync android
Capacitor-->>BuildScript : 返回同步结果
BuildScript->>Fastlane : bundle exec fastlane build
Fastlane-->>BuildScript : 返回构建结果
BuildScript->>VersionSync : Sync-AppVersion同步版本
VersionSync->>Common : 读取android/app/build.gradle
VersionSync->>Common : 更新iOS project.pbxproj
VersionSync->>Common : 更新Web environment*.ts
VersionSync-->>BuildScript : 返回版本同步结果
end
BuildScript->>User : 显示APK/AAB路径或发布结果
```

**图表来源**
- [scripts/windows/build_android_bywin.ps1:110-149](file://scripts/windows/build_android_bywin.ps1#L110-L149)
- [scripts/windows/build_android_bywin.ps1:174-303](file://scripts/windows/build_android_bywin.ps1#L174-L303)
- [scripts/windows/build_android_bywin.ps1:305-352](file://scripts/windows/build_android_bywin.ps1#L305-L352)

### **更新** 发布流程详细分析

```mermaid
sequenceDiagram
participant User as 用户
participant PublishScript as 发布脚本
participant Common as 通用函数
participant ArtifactValidator as 产物验证器
participant GitHubClient as GitHub客户端
participant GiteeClient as Gitee客户端
participant FileHandler as 文件处理器
User->>PublishScript : 执行-Publish -Platform github/gitee
PublishScript->>Common : 读取版本号不递增
Common->>Common : Read-AndroidGradleValue读取versionCode/versionName
Common-->>PublishScript : 返回版本号
PublishScript->>ArtifactValidator : 验证构建产物
ArtifactValidator->>FileHandler : 检查APK文件存在
ArtifactValidator->>FileHandler : 检查AAB文件存在
ArtifactValidator-->>PublishScript : 返回验证结果
alt Platform=github
PublishScript->>GitHubClient : 检查gh CLI登录状态
GitHubClient->>GitHubClient : gh auth status
GitHubClient->>GitHubClient : gh release create tag artifacts
GitHubClient-->>PublishScript : 返回发布结果
else Platform=gitee
PublishScript->>GiteeClient : 检查GITEE_TOKEN环境变量
GiteeClient->>GiteeClient : 创建ReleasePOST API
GiteeClient->>GiteeClient : 上传APK附件
GiteeClient->>GiteeClient : 上传AAB附件
GiteeClient-->>PublishScript : 返回发布结果
end
PublishScript->>User : 显示发布完成信息
```

**图表来源**
- [scripts/windows/build_android_bywin.ps1:174-303](file://scripts/windows/build_android_bywin.ps1#L174-L303)

### Web构建流程详细分析

```mermaid
sequenceDiagram
participant User as 用户
participant BuildScript as Web构建脚本
participant Common as 通用函数
participant VersionSync as 版本同步函数
participant JunctionPath as 路径解析函数
participant Ionic as Ionic CLI
User->>BuildScript : 执行build_web_bywin.ps1
BuildScript->>JunctionPath : Resolve-JunctionPath解析项目路径
JunctionPath->>Common : 规范化路径并检查junction
JunctionPath-->>BuildScript : 返回真实物理路径
BuildScript->>VersionSync : Sync-AppVersion同步版本
VersionSync->>Common : 读取android/app/build.gradle
VersionSync->>Common : 更新Web environment*.ts
VersionSync-->>BuildScript : 返回版本同步结果
BuildScript->>Ionic : ionic build -c production
Ionic-->>BuildScript : 返回构建结果
BuildScript->>User : 显示www目录路径
```

**图表来源**
- [scripts/windows/build_web_bywin.ps1:266-268](file://scripts/windows/build_web_bywin.ps1#L266-L268)

### 版本同步流程详细分析

```mermaid
sequenceDiagram
participant User as 用户
participant SyncScript as 版本同步脚本
participant Common as 通用函数
participant GradleReader as Gradle文件读取
participant GradleWriter as Gradle文件写入
participant IOSync as iOS版本同步
participant WebSync as Web版本同步
User->>SyncScript : 执行sync_version_bywin.ps1
SyncScript->>Common : 检查参数VersionName/VersionCode
SyncScript->>GradleWriter : Set-AndroidGradleValue可选
GradleWriter->>Common : 读取android/app/build.gradle
GradleWriter->>Common : 正则表达式替换版本值
GradleWriter->>Common : UTF-8无BOM写回
GradleWriter-->>SyncScript : 返回写入结果
SyncScript->>Common : 调用Sync-AppVersion
Common->>GradleReader : Read-AndroidGradleValue读取版本
GradleReader-->>Common : 返回versionCode和versionName
Common->>IOSync : 更新project.pbxproj CURRENT_PROJECT_VERSION
IOSync-->>Common : 返回iOS同步结果
Common->>WebSync : 更新environment*.ts version和versionCode
WebSync-->>Common : 返回Web同步结果
Common-->>SyncScript : 返回版本同步完成
SyncScript->>User : 显示版本同步完成
```

**图表来源**
- [scripts/windows/sync_version_bywin.ps1:69-75](file://scripts/windows/sync_version_bywin.ps1#L69-L75)
- [scripts/windows/sync_version_bywin.ps1:77](file://scripts/windows/sync_version_bywin.ps1#L77)
- [scripts/windows/_common.ps1:1161-1180](file://scripts/windows/_common.ps1#L1161-L1180)
- [scripts/windows/_common.ps1:1194-1238](file://scripts/windows/_common.ps1#L1194-L1238)

### 基础工具管理流程

```mermaid
flowchart TD
Start([开始基础工具管理]) --> CheckTools[检测现有工具]
CheckTools --> ShowMenu[显示可用工具菜单]
ShowMenu --> SelectTools{用户选择?}
SelectTools --> |安装工具| InstallProcess[执行安装流程]
SelectTools --> |卸载工具| UninstallProcess[执行卸载流程]
InstallProcess --> InstallWinget[安装winget]
InstallWinget --> ConfigureMirror[配置镜像源]
InstallWinget --> InstallTerminal[安装Windows终端]
InstallTerminal --> InstallStore[安装Microsoft Store]
InstallStore --> InstallNode[安装Node.js LTS]
InstallNode --> Complete([安装完成])
UninstallProcess --> UninstallTerminal[卸载Windows终端]
UninstallTerminal --> Complete
CheckTools --> ShowMenu
```

**图表来源**
- [scripts/windows/install_1_base_tools_bywin.ps1:728-731](file://scripts/windows/install_1_base_tools_bywin.ps1#L728-L731)
- [scripts/windows/install_1_base_tools_bywin.ps1:781-800](file://scripts/windows/install_1_base_tools_bywin.ps1#L781-L800)

### Android SDK安装详细流程

```mermaid
flowchart TD
Start([开始安装]) --> CheckSDK[检查现有SDK]
CheckSDK --> FoundSDK{找到SDK?}
FoundSDK --> |是| BootstrapSDK[引导SDKManager]
FoundSDK --> |否| DownloadBoot[下载引导包]
DownloadBoot --> ExtractBoot[解压引导包]
ExtractBoot --> MoveBoot[移动到SDK目录]
MoveBoot --> VerifyBoot[验证安装]
BootstrapSDK --> VerifyBoot
VerifyBoot --> CheckJava[检查Java 17环境]
CheckJava --> JavaOK{Java 17就绪?}
JavaOK --> |否| InstallJava[安装Java 17]
JavaOK --> |是| InstallComponents[安装组件]
InstallJava --> InstallComponents
InstallComponents --> InstallPlatform[安装平台]
InstallPlatform --> InstallBuildTools[安装构建工具]
InstallBuildTools --> ConfigEnv[配置环境变量]
ConfigEnv --> Done([安装完成])
CheckSDK --> |无| DownloadBoot
```

**图表来源**
- [scripts/windows/install_4_android_sdk_bywin.ps1:35-249](file://scripts/windows/install_4_android_sdk_bywin.ps1#L35-L249)

### 卸载流程管理系统

```mermaid
flowchart TD
Start([开始卸载]) --> Detect[检测当前状态]
Detect --> ShowStatus[显示安装状态]
ShowStatus --> UserChoice{用户选择?}
UserChoice --> |仅卸载Ruby| RemoveRubyOnly[卸载Ruby + Devkit]
UserChoice --> |卸载SDK| RemoveSDK[卸载Android SDK]
UserChoice --> |全部卸载| FullUninstall[完整卸载]
RemoveRubyOnly --> RemoveRuby
RemoveSDK --> RemoveSDKProcess[卸载SDK目录]
FullUninstall --> RemoveRuby
FullUninstall --> RemoveSDKProcess
RemoveRuby --> RemoveEnv[清理环境变量]
RemoveSDKProcess --> RemoveEnv
RemoveEnv --> FinalCheck[最终检查]
FinalCheck --> StatusReport[生成卸载报告]
StatusReport --> End([卸载完成])
```

**图表来源**
- [scripts/windows/remove_1_android_sdk_bywin.ps1:141-190](file://scripts/windows/remove_1_android_sdk_bywin.ps1#L141-L190)

## 依赖关系分析

### 脚本间依赖关系

```mermaid
graph LR
subgraph "共享依赖"
Common[_common.ps1<br/>新增Resolve-JunctionPath函数<br/>新增Java版本验证函数<br/>新增Set-AndroidGradleValue函数<br/>新增Sync-AppVersion版本同步函数<br/>新增Android签名配置管理]
end
subgraph "基础工具管理"
BaseTools[install_1_base_tools_bywin.ps1]
end
subgraph "Ruby + Fastlane工具链"
InstallRuby[install_2_ruby_bywin.ps1]
InstallFastlane[install_3_fastlane_bywin.ps1]
end
subgraph "Android SDK安装"
InstallSDK[install_4_android_sdk_bywin.ps1]
end
subgraph "应用构建脚本"
BuildAndroid[build_android_bywin.ps1<br/>新增-Build选项参数<br/>新增发布功能<br/>新增自动versionCode递增]
BuildWeb[build_web_bywin.ps1]
end
subgraph "版本同步脚本"
SyncVersion[sync_version_bywin.ps1]
end
subgraph "卸载清理脚本"
RemoveSDK[remove_1_android_sdk_bywin.ps1]
RemoveRuby[remove_3_ruby_bywin.ps1]
end
Common --> BaseTools
Common --> InstallRuby
Common --> InstallFastlane
Common --> InstallSDK
Common --> BuildAndroid
Common --> BuildWeb
Common --> SyncVersion
Common --> RemoveSDK
Common --> RemoveRuby
InstallRuby --> InstallFastlane
InstallFastlane --> BuildAndroid
InstallFastlane --> BuildWeb
InstallSDK --> BuildAndroid
BuildAndroid --> SyncVersion
BuildWeb --> SyncVersion
RemoveSDK --> BuildAndroid
RemoveRuby --> BuildAndroid
BaseTools --> InstallRuby
BaseTools --> InstallFastlane
BaseTools --> InstallSDK
```

**图表来源**
- [scripts/windows/_common.ps1:24-33](file://scripts/windows/_common.ps1#L24-L33)
- [scripts/windows/install_1_base_tools_bywin.ps1:686-695](file://scripts/windows/install_1_base_tools_bywin.ps1#L686-L695)
- [scripts/windows/install_2_ruby_bywin.ps1:12-14](file://scripts/windows/install_2_ruby_bywin.ps1#L12-L14)
- [scripts/windows/install_3_fastlane_bywin.ps1:12-14](file://scripts/windows/install_3_fastlane_bywin.ps1#L12-L14)
- [scripts/windows/install_4_android_sdk_bywin.ps1:7-9](file://scripts/windows/install_4_android_sdk_bywin.ps1#L7-L9)
- [scripts/windows/build_android_bywin.ps1:27-29](file://scripts/windows/build_android_bywin.ps1#L27-L29)
- [scripts/windows/build_web_bywin.ps1:266-268](file://scripts/windows/build_web_bywin.ps1#L266-L268)
- [scripts/windows/sync_version_bywin.ps1:16-16](file://scripts/windows/sync_version_bywin.ps1#L16-L16)

### 外部依赖分析

系统依赖的主要外部组件包括：

#### Microsoft 生态系统
- **Visual Studio Build Tools**: MSVC 编译器
- **Windows SDK**: 平台支持
- **WebView2 Runtime**: 应用运行时

#### 开源工具链
- **MSYS2/Pacman**: GNU 工具链包管理
- **Android Studio**: Android 开发环境
- **RubyInstaller**: Ruby + Devkit工具链

#### Web 开发工具
- **Node.js LTS**: JavaScript 运行时环境
- **npm**: 包管理器
- **Ionic CLI**: Web 应用构建工具
- **Capacitor CLI**: 跨平台应用框架

#### Ruby生态工具
- **Ruby 3.0+**: Ruby运行时环境
- **Bundler**: Ruby依赖管理
- **fastlane**: Android/iOS应用构建工具
- **RubyGems**: Ruby包管理器
- **fiddle**: **新增** Ruby 4.0+必需的fiddle gem

#### 网络资源
- **国内RubyGems镜像**: 腾讯云、华为云镜像
- **GitHub**: 原始下载源
- **Microsoft Store**: 系统组件下载站

#### **新增** NTFS junction路径解析
**重大更新** 新增了NTFS junction路径解析功能，专门解决Windows开发环境中的路径兼容性问题：

- **Resolve-JunctionPath函数**: 将路径中的NTFS junction解析为真实物理路径
- **兼容性处理**: 解决PowerShell Resolve-Path与Node.js/webpack路径解析不一致的问题
- **标准API实现**: 基于.NET API，无需管理员权限，不依赖fsutil
- **逐级检查机制**: 从当前路径向上逐级检查junction并替换为Substitute Name
- **根目录处理**: 根目录（如C:\）直接返回，避免不必要的处理

#### **新增** Java运行时环境
**重大更新** 新增了严格的Java版本要求：

- **JDK 17-21**: Android构建的严格版本范围
- **Gradle 8.13兼容性**: 符合官方支持范围
- **Capacitor 7兼容性**: 支持sourceCompatibility VERSION_21

#### **新增** Android Gradle值修改功能
**重大更新** 新增了精确的Android Gradle文件值修改功能：

- **Set-AndroidGradleValue函数**: 安全修改build.gradle中的versionCode和versionName
- **正则表达式匹配**: 精确匹配Gradle文件中的键值对
- **UTF-8无BOM写回**: 确保文件编码一致性
- **版本名自动引号**: versionName自动添加双引号，versionCode保持整数格式

#### **新增** 版本同步功能
**重大更新** 新增了完整的版本同步机制：

- **版本权威源**: android/app/build.gradle
- **iOS同步目标**: ios/App/App.xcodeproj/project.pbxproj
- **Web同步目标**: src/environments/*.ts四个文件
- **同步字段**: CURRENT_PROJECT_VERSION/MARKETING_VERSION和version/versionCode
- **参数化版本设置**: 支持通过命令行参数直接设置版本号

#### **新增** Android签名配置管理
**重大更新** 新增了完整的Android签名配置管理功能：

- **Load-AndroidSigningPs1函数**: 加载本地Android签名配置
- **Print-AndroidSigningHelp函数**: 输出签名配置创建指导
- **环境变量管理**: 自动设置KEYSTORE_FILE_PASSWORD等必需环境变量

#### **新增** 多平台发布功能
**重大更新** 新增了完整的发布管理系统：

- **GitHub发布**: 通过gh CLI工具进行认证和发布
- **Gitee发布**: 通过REST API直接调用，支持自定义token
- **产物验证**: 自动检查APK和AAB文件是否存在
- **说明文件处理**: 从RELEASE_NOTES.md读取发布说明
- **Tag管理**: 自动生成格式化的tag名称（v<versionName>+<versionCode>）

#### **新增** 自动版本管理
**重大更新** 新增了智能的版本号管理机制：

- **versionCode自动递增**: 每次构建自动递增1
- **versionName保持不变**: 保持语义化版本的一致性
- **环境变量管理**: 自动设置BUILD_NUMBER和VERSION_NUMBER
- **版本冲突预防**: 确保每次构建都生成唯一的版本号

**章节来源**
- [scripts/windows/build_android_bywin.ps1:35-66](file://scripts/windows/build_android_bywin.ps1#L35-L66)
- [scripts/windows/build_web_bywin.ps1:266-268](file://scripts/windows/build_web_bywin.ps1#L266-L268)
- [scripts/windows/install_2_ruby_bywin.ps1:43-83](file://scripts/windows/install_2_ruby_bywin.ps1#L43-L83)
- [scripts/windows/install_4_android_sdk_bywin.ps1:39-43](file://scripts/windows/install_4_android_sdk_bywin.ps1#L39-L43)
- [scripts/windows/_common.ps1:22-61](file://scripts/windows/_common.ps1#L22-L61)
- [scripts/windows/_common.ps1:63-65](file://scripts/windows/_common.ps1#L63-L65)
- [scripts/windows/_common.ps1:1161-1180](file://scripts/windows/_common.ps1#L1161-L1180)
- [scripts/windows/_common.ps1:1194-1238](file://scripts/windows/_common.ps1#L1194-L1238)
- [scripts/windows/_common.ps1:1249-1289](file://scripts/windows/_common.ps1#L1249-L1289)

## 性能考虑

### 内存优化策略

Windows 平台上的 Rust 构建经常遇到内存不足的问题，脚本系统采用了多项优化措施：

#### Node.js 内存限制
- **最大堆大小**: 8GB (`--max-old-space-size=8192`)
- **新生代大小**: 512MB (`--max-semi-space-size=512`)

#### Ionic + Capacitor构建优化
- **依赖缓存**: 通过Ensure-NodeModules避免重复安装
- **并行执行**: 通过Invoke-NativeStream统一处理命令执行
- **环境隔离**: 通过Bundler确保fastlane版本一致性

### Ruby + fastlane性能优化

**重大更新** Ruby + fastlane工具链特别针对Android构建的性能要求进行了优化，新增了多源下载机制和RubyGems镜像检测系统：

#### 多源下载性能优化
- **并行竞速下载**: 同时测试gh-proxy.com、ghfast.top、github.com三个源的速度
- **智能选择算法**: 自动选择最快的下载源进行完整下载
- **超时控制**: 600秒连接和读写超时，确保长时间下载任务的稳定性
- **文件大小校验**: 51200KB最小文件大小校验，防止代理返回错误页面

#### RubyGems镜像检测性能优化
**更新** 动态探测RubyGems镜像源：
- **HEAD请求探测**: 使用HTTP HEAD请求快速检测镜像可用性
- **超时控制**: 8秒超时，避免长时间等待不可用镜像
- **智能回退**: 自动尝试下一个镜像源，确保下载成功率
- **进度反馈**: 实时显示镜像探测状态和选择结果
- **AllowAutoRedirect=$false**: 防止HTTP 302重定向导致的误判

#### Inno Setup安装优化
- **全静默安装**: `/VERYSILENT`参数确保无交互安装
- **UTF-8支持**: `/TASKS=defaultutf8`启用UTF-8编码支持
- **PATH配置**: `/TASKS=modpath`自动将Ruby加入用户PATH环境变量

#### 下载性能优化
- **多源并行下载**: 并行测试多个下载源的速度
- **智能选择**: 自动选择最快的下载源
- **文件校验**: 下载完成后验证文件大小

#### 网络优化
- **超时控制**: 30 秒连接和读写超时
- **断点续传**: 支持长时间下载任务
- **进度显示**: 实时进度和速度反馈

#### PATH同步优化
**新增** Ruby安装后立即同步PATH环境变量，提升安装可靠性：

- **注册表读取**: 从机器级和用户级注册表读取PATH
- **即时注入**: 将合并后的PATH注入当前PowerShell会话
- **避免重开窗口**: 确保Ruby和Bundler在当前会话中立即可用

#### Bundler版本检查优化
**新增** 自动处理版本不匹配问题：
- **版本对比**: 自动检测Gemfile.lock中的BUNDLED WITH版本
- **智能对齐**: 自动执行bundle update --bundler进行版本对齐
- **错误预防**: 避免Bundler 4.x下载并切换到旧版的无谓操作

#### Ruby 4.0+兼容性优化
**新增** 解决Ruby 4.0+的Fastlane集成问题：
- **fiddle gem自动安装**: 通过Gemfile确保fiddle gem可用
- **版本兼容性检查**: 自动检测Ruby版本并提供兼容性提示
- **依赖链优化**: 确保fastlane及其依赖的完整安装

#### **新增** NTFS junction路径解析性能优化
**重大更新** 新增的Resolve-JunctionPath函数具有以下性能特点：

- **标准化处理**: 规范化路径（去除尾部反斜杠），根目录直接返回
- **逐级检查**: 从当前路径向上逐级检查junction，记录最深一级的替换
- **最小化I/O**: 仅在必要时读取文件属性，避免不必要的磁盘访问
- **错误恢复**: 单个路径段检查失败不影响整体处理
- **内存优化**: 使用局部变量避免全局状态污染

#### **新增** Java版本验证性能优化
**重大更新** 新增的Java版本验证功能具有以下性能特点：

- **快速版本检测**: Get-JavaMajorVersion函数仅执行一次java -version调用
- **智能缓存**: 避免重复的版本查询操作
- **精确范围验证**: Assert-JavaForAndroid提供即时的版本范围检查
- **详细错误信息**: 提供具体的版本不兼容原因和解决方案
- **渐进式验证**: 在构建流程中尽早发现Java版本问题，避免后续步骤失败

#### **新增** Android Gradle值修改性能优化
**重大更新** 新增的Set-AndroidGradleValue函数具有以下性能特点：

- **正则表达式优化**: 使用高效的正则表达式匹配Gradle文件中的键值对
- **单次文件读取**: 一次性读取整个文件内容，避免多次I/O操作
- **精确替换**: 使用捕获组确保只替换匹配的键值对
- **UTF-8无BOM写回**: 避免编码转换开销，提升文件写入速度
- **错误恢复**: 单个键值对修改失败不影响其他操作

#### **新增** 版本同步性能优化
**重大更新** 新增的版本同步功能具有以下性能特点：

- **增量同步**: 仅在版本发生变化时执行同步操作
- **文件缓存**: 避免重复读取相同的Gradle文件
- **并行处理**: 同时处理iOS和Web的版本同步
- **错误恢复**: 单个文件同步失败不影响其他文件的处理
- **UTF-8无BOM**: 避免编码转换开销，提升文件写入速度
- **参数化优化**: 支持通过命令行参数直接设置版本号，避免不必要的读取操作

#### **新增** Android签名配置管理性能优化
**重大更新** 新增的Android签名配置管理功能具有以下性能特点：

- **延迟加载**: 仅在需要时才加载本地签名配置文件
- **环境变量缓存**: 避免重复设置相同的环境变量
- **配置验证**: 在加载前验证配置文件的有效性
- **错误处理**: 提供详细的配置错误信息和修复建议

#### **新增** 发布流程性能优化
**重大更新** 新增的发布功能具有以下性能特点：

- **异步处理**: 支持并发上传多个构建产物
- **断点续传**: 支持大文件上传的断点续传功能
- **错误重试**: 网络错误自动重试机制
- **进度反馈**: 实时显示上传进度和剩余时间
- **资源清理**: 发布完成后自动清理临时文件
- **并发控制**: 限制并发上传数量，避免网络拥塞

#### **新增** 自动版本管理性能优化
**重大更新** 新增的自动版本管理功能具有以下性能特点：

- **快速读取**: 直接从Gradle文件读取versionCode，避免额外I/O
- **原子操作**: 版本递增和写入操作保证原子性
- **错误恢复**: 版本读取失败时提供合理的默认值
- **缓存机制**: 避免重复读取相同的Gradle文件
- **类型安全**: 确保versionCode为有效的整数值

**章节来源**
- [scripts/windows/build_android_bywin.ps1:97-124](file://scripts/windows/build_android_bywin.ps1#L97-L124)
- [scripts/windows/build_web_bywin.ps1:266-268](file://scripts/windows/build_web_bywin.ps1#L266-L268)
- [scripts/windows/_common.ps1:607-728](file://scripts/windows/_common.ps1#L607-L728)
- [scripts/windows/_common.ps1:981-1020](file://scripts/windows/_common.ps1#L981-L1020)
- [scripts/windows/install_2_ruby_bywin.ps1:70-103](file://scripts/windows/install_2_ruby_bywin.ps1#L70-L103)
- [scripts/windows/install_2_ruby_bywin.ps1:32-40](file://scripts/windows/install_2_ruby_bywin.ps1#L32-L40)
- [scripts/windows/install_3_fastlane_bywin.ps1:50-75](file://scripts/windows/install_3_fastlane_bywin.ps1#L50-L75)
- [scripts/windows/install_3_fastlane_bywin.ps1:88-105](file://scripts/windows/install_3_fastlane_bywin.ps1#L88-L105)
- [scripts/windows/_common.ps1:22-61](file://scripts/windows/_common.ps1#L22-L61)
- [scripts/windows/_common.ps1:63-65](file://scripts/windows/_common.ps1#L63-L65)
- [scripts/windows/_common.ps1:1161-1180](file://scripts/windows/_common.ps1#L1161-L1180)
- [scripts/windows/_common.ps1:1194-1238](file://scripts/windows/_common.ps1#L1194-L1238)
- [scripts/windows/_common.ps1:1249-1289](file://scripts/windows/_common.ps1#L1249-L1289)

## 故障排除指南

### 常见问题诊断

#### 环境检查失败
```powershell
# 检查基础工具安装状态
Test-Winget
Test-WindowsTerminal
Test-MicrosoftStore
Test-NodeTool

# 检查Ruby + fastlane安装状态
Get-RubyVersion
Ensure-Bundler
Get-FastlaneCommand
```

#### Android构建问题
**新增** 针对 Android 构建的特定故障排除：

```powershell
# 检查Ruby安装状态
ruby -v

# 检查Bundler安装状态
bundle -v

# 检查fastlane安装状态
fastlane -v

# 手动安装fastlane依赖
cd android
bundle install

# 清理node_modules并重新安装
rm -rf node_modules
npm install --legacy-peer-deps
```

#### **新增** 发布相关问题
**重大更新** 针对新增的发布功能的故障排除：

```powershell
# 检查GitHub发布配置
gh auth status

# 检查Gitee发布配置
echo $env:GITEE_TOKEN

# 验证构建产物存在
Test-Path "android\app\build\outputs\apk\release\MacroDeckClient-*.apk"
Test-Path "android\app\build\outputs\bundle\release\MacroDeckClient-*.aab"

# 检查RELEASE_NOTES.md文件
Test-Path "RELEASE_NOTES.md"

# 手动测试GitHub发布
.\build_android_bywin.ps1 -Publish -Platform github

# 手动测试Gitee发布
.\build_android_bywin.ps1 -Publish -Platform gitee
```

#### **新增** NTFS junction路径解析问题
**重大更新** 针对新增的Resolve-JunctionPath函数的故障排除：

```powershell
# 检查路径解析功能
Resolve-JunctionPath "C:\MyWork"

# 手动检查junction状态
Get-ChildItem -LiteralPath "C:\MyWork" -Force | Select-Object FullName, Attributes

# 检查路径规范化
$normalized = "C:\MyWork\".TrimEnd('\')
Write-Host "规范化路径: $normalized"

# 手动解析路径
$junctionRoot = $null
$junctionSubstitute = $null
$current = $normalized
while ($current -and $current.Length -gt 3) {
    try {
        $item = Get-Item -LiteralPath $current -Force -ErrorAction SilentlyContinue
        if ($item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            $target = $item.Target
            if ($target) {
                $clean = $target -replace '^\\?\?\\', ''
                $junctionRoot = $current
                $junctionSubstitute = $clean
                break
            }
        }
    } catch { }
    $current = Split-Path $current -Parent
}
```

#### **新增** Java版本验证问题
**重大更新** 针对新增的Java版本验证功能的故障排除：

```powershell
# 检查Java版本
java -version

# 手动检测Java主版本
Get-JavaMajorVersion

# 检查Java 17+验证
Assert-Java17

# 检查Android专用Java验证
Assert-JavaForAndroid

# 手动安装JDK 17
winget install EclipseAdoptium.Temurin.17.JDK

# 或安装JDK 21（推荐）
winget install EclipseAdoptium.Temurin.21.JDK
```

#### **新增** Android Gradle值修改问题
**重大更新** 针对新增的Set-AndroidGradleValue函数的故障排除：

```powershell
# 检查build.gradle文件是否存在
Test-Path -LiteralPath 'android\app\build.gradle'

# 手动读取版本信息
Read-AndroidGradleValue 'versionCode'
Read-AndroidGradleValue 'versionName'

# 手动修改版本值
Set-AndroidGradleValue 'versionName' '3.1.0'
Set-AndroidGradleValue 'versionCode' '5'

# 检查修改结果
Get-Content 'android\app\build.gradle' | Select-String 'versionCode|versionName'
```

#### **新增** 版本同步问题
**重大更新** 针对新增的版本同步功能的故障排除：

```powershell
# 检查版本同步函数
Sync-AppVersion

# 手动读取Android版本
Read-AndroidGradleValue 'versionCode'
Read-AndroidGradleValue 'versionName'

# 检查iOS工程是否存在
Test-Path -LiteralPath 'ios\App\App.xcodeproj\project.pbxproj'

# 检查Web环境文件是否存在
Test-Path -LiteralPath 'src\environments\environment.ts'
Test-Path -LiteralPath 'src\environments\environment.prod.ts'
Test-Path -LiteralPath 'src\environments\environment.web.ts'
Test-Path -LiteralPath 'src\environments\environment.web.prod.ts'

# 手动执行版本同步
.\sync_version_bywin.ps1
```

#### **新增** Android签名配置问题
**重大更新** 针对新增的Android签名配置管理功能的故障排除：

```powershell
# 检查本地签名配置文件
Test-Path -LiteralPath 'scripts\local\android-signing.ps1'

# 手动加载签名配置
Load-AndroidSigningPs1 'scripts\local\android-signing.ps1'

# 检查环境变量
$env:KEYSTORE_FILE_PASSWORD
$env:BUILD_NUMBER
$env:VERSION_NUMBER

# 显示签名配置帮助
Print-AndroidSigningHelp 'scripts\local\android-signing.ps1' 'keystores\macrodeck.keystore' 'macrodeck'
```

#### **新增** 自动版本管理问题
**重大更新** 针对新增的自动versionCode递增功能的故障排除：

```powershell
# 检查当前versionCode
Read-AndroidGradleValue 'versionCode'

# 手动设置versionCode
Set-AndroidGradleValue 'versionCode' '100'

# 检查BUILD_NUMBER环境变量
echo $env:BUILD_NUMBER

# 验证版本递增逻辑
$currentCode = Read-AndroidGradleValue 'versionCode'
$newCode = [int]$currentCode + 1
Write-Host "新版本号: $newCode"
```

#### 基础工具安装问题
**新增** 针对基础工具管理的故障排除：

```powershell
# 检查 winget 安装状态
Test-Winget

# 检查 Windows 终端安装状态
Test-WindowsTerminal

# 检查 Microsoft Store 安装状态
Test-MicrosoftStore
```

#### Ruby安装问题
**重大更新** 针对Ruby安装脚本的故障排除：

```powershell
# 检查Ruby版本
Get-RubyVersion

# 手动下载RubyInstaller
$urls = @(
    "https://gh-proxy.com/https://github.com/oneclick/rubyinstaller2/releases/download/RubyInstaller-4.0.5-1/rubyinstaller-devkit-4.0.5-1-x64.exe",
    "https://ghfast.top/https://github.com/oneclick/rubyinstaller2/releases/download/RubyInstaller-4.0.5-1/rubyinstaller-devkit-4.0.5-1-x64.exe",
    "https://github.com/oneclick/rubyinstaller2/releases/download/RubyInstaller-4.0.5-1/rubyinstaller-devkit-4.0.5-1-x64.exe"
)
Save-WebFile -Urls $urls -OutFile "$env:TEMP\rubyinstaller-devkit-4.0.5-1-x64.exe" -TimeoutSec 600 -MinSizeKB 51200

# 检查UTF-8和PATH配置
ruby -e "puts Encoding.default_external"

# 手动同步PATH
Sync-PathFromRegistry
```

#### RubyGems镜像问题
**更新** 针对RubyGems镜像检测的故障排除：

```powershell
# 手动测试RubyGems镜像
$mirrors = @(
    'https://mirrors.cloud.tencent.com/rubygems/',
    'https://repo.huaweicloud.com/repository/rubygems/'
)

foreach ($mirror in $mirrors) {
    try {
        $probe = ($mirror.TrimEnd('/')) + '/info/fastlane'
        $req = [System.Net.HttpWebRequest]::Create($probe)
        $req.Method = 'HEAD'
        $req.Timeout = 8000
        $req.AllowAutoRedirect = $false
        $resp = $req.GetResponse()
        Write-Host "镜像可用: $mirror (状态码: $($resp.StatusCode))"
        $resp.Close()
    } catch {
        Write-Host "镜像不可用: $mirror"
    }
}

# 手动选择镜像
Select-GemMirror
```

#### Bundler版本不匹配问题
**新增** 针对Bundler版本兼容性的故障排除：

```powershell
# 检查当前Bundler版本
bundle --version

# 检查Gemfile.lock中的BUNDLED WITH版本
$lockfile = Join-Path (Get-Location) 'Gemfile.lock'
$lines = Get-Content $lockfile
$idx = [Array]::FindIndex($lines, { param($l) $l.Trim() -eq 'BUNDLED WITH' })
if ($idx -ge 0 -and $idx + 1 -lt $lines.Count) {
    Write-Host "Lockfile中的Bundler版本: $($lines[$idx + 1].Trim())"
}

# 手动对齐版本
bundle update --bundler
```

#### PATH同步问题
**新增** 针对PATH同步问题的故障排除：

```powershell
# 检查当前PATH
$env:Path

# 手动同步PATH
Sync-PathFromRegistry

# 验证Ruby是否可用
Get-CommandPath 'ruby'

# 验证Bundler是否可用
Get-CommandPath 'bundle'
```

#### Ruby 4.0+兼容性问题
**新增** 针对Ruby 4.0+的Fastlane集成问题：

```powershell
# 检查fiddle gem是否可用
ruby -e "require 'fiddle'; puts 'fiddle gem可用'"

# 手动安装fiddle gem
gem install fiddle

# 检查android/Gemfile中的fiddle声明
Get-Content android/Gemfile

# 重新安装fastlane依赖
cd android
bundle install
```

#### 下载问题
```powershell
# 检查网络连接
ping mirrors.cloud.tencent.com

# 手动下载测试
Save-WebFile -Urls @('https://mirrors.cloud.tencent.com/msys2/distrib/msys2-x86_64-latest.exe') -OutFile "test.exe"
```

#### 权限问题
```powershell
# 以管理员身份运行 PowerShell
# 检查执行策略
Get-ExecutionPolicy

# 临时允许脚本执行
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 卸载清理

#### 完整清理流程
```powershell
# 卸载 Android SDK
.\remove_1_android_sdk_bywin.ps1

# 卸载 Ruby + Devkit
.\remove_3_ruby_bywin.ps1
```

#### 手动清理步骤
- 删除 `C:\msys64` 目录
- 清理用户环境变量中的 PATH 条目
- 删除 `~\.cargo` 和 `~\.rustup` 目录

**章节来源**
- [scripts/windows/build_android_bywin.ps1:127-137](file://scripts/windows/build_android_bywin.ps1#L127-L137)
- [scripts/windows/build_web_bywin.ps1:266-268](file://scripts/windows/build_web_bywin.ps1#L266-L268)
- [scripts/windows/install_1_base_tools_bywin.ps1:728-731](file://scripts/windows/install_1_base_tools_bywin.ps1#L728-L731)
- [scripts/windows/remove_1_android_sdk_bywin.ps1:26-37](file://scripts/windows/remove_1_android_sdk_bywin.ps1#L26-L37)
- [scripts/windows/remove_3_ruby_bywin.ps1:40-54](file://scripts/windows/remove_3_ruby_bywin.ps1#L40-L54)
- [scripts/windows/install_2_ruby_bywin.ps1:70-103](file://scripts/windows/install_2_ruby_bywin.ps1#L70-L103)
- [scripts/windows/sync_version_bywin.ps1:69-75](file://scripts/windows/sync_version_bywin.ps1#L69-L75)

## 结论

Macro Deck Client App 的 Windows PowerShell 自动化系统展现了现代开发工具链的最佳实践。通过精心设计的模块化架构、完善的错误处理机制和智能化的用户交互体验，这套脚本系统为开发者提供了高效、可靠的开发环境管理解决方案。

**新增-Build选项综合参数说明** 项目最新更新中为Android构建脚本提供了全面的命令行参数文档。build_android_bywin.ps1脚本现在支持多个专业级参数：-Build用于构建release APK/AAB（不发布），-Check用于仅检查构建环境，-Publish用于直接发布已有产物，-Platform指定发布平台（github/gitee），-Help显示详细帮助信息。这些参数的引入显著提升了脚本的可操作性和用户体验。

**支持发布APK/AAB构建** 最新更新的构建脚本实现了完整的发布流程自动化。通过-Publish参数，开发者可以直接将已有的APK和AAB构建产物发布到GitHub或Gitee的Release页面。该功能支持自动生成tag名称（格式：v<versionName>+<versionCode>）、上传构建产物、读取RELEASE_NOTES.md作为发布说明，以及处理认证和权限验证等复杂场景。

**自动versionCode递增功能** 构建脚本现在具备智能的版本号管理能力。在构建过程中，系统会自动从android/app/build.gradle读取当前versionCode值，然后递增1作为新的BUILD_NUMBER环境变量。这一机制确保了每次构建都生成唯一的版本号，避免了版本冲突问题。同时，versionName保持不变，保持语义化版本的一致性。

**改进的用户体验功能** 整个脚本系统进行了全面的用户体验优化。包括增强的帮助系统输出、详细的进度反馈、清晰的错误提示信息、中文本地化的用户界面等。特别是在发布流程中，提供了实时的进度显示、详细的错误诊断信息和友好的修复建议，大大降低了使用门槛。

**多平台发布支持** 最新版本支持两个主要代码托管平台的Release发布功能。对于GitHub平台，需要安装并登录gh CLI工具；对于Gitee平台，需要在本地签名配置文件中设置GITEE_TOKEN环境变量。两种平台都支持完整的发布流程，包括创建Release、上传构建产物和处理错误情况。

这些 PowerShell 脚本提供了从基础环境检查到复杂工具链安装的全方位自动化支持，特别针对 Windows 开发环境进行了深度优化。脚本系统采用模块化设计，通过共享的通用函数库实现代码复用，确保了一致的用户体验和可靠的执行流程。

**新增NTFS junction路径解析功能** 项目最新更新中引入了Resolve-JunctionPath函数，专门解决Windows开发环境中的NTFS junction（挂载点）路径解析问题。当项目目录通过junction访问时（如C:\MyWork → D:\MyWork），PowerShell的Resolve-Path仍返回junction路径，而Node.js/webpack会解析到真实路径，导致TypeScript编译路径不匹配。该函数通过逐级检查路径中的junction并替换为Substitute Name，确保路径解析的一致性，显著提升了开发环境的兼容性和稳定性。

**增强开发环境兼容性** 通过Resolve-JunctionPath函数的引入，系统现在能够智能处理各种复杂的开发环境配置，包括多盘符开发、网络驱动器映射、符号链接等场景。这一改进显著提升了开发环境的兼容性和稳定性，特别是在团队协作和分布式开发环境中。

**改进路径处理机制** 新增的路径解析功能基于标准.NET API实现，无需管理员权限，不依赖fsutil工具。函数会规范化路径（去除尾部反斜杠），逐级向上查找junction，记录最深一级的junction替换，最终返回真实的物理路径。这一机制确保了TypeScript编译器、Webpack和其他工具链能够正确识别项目文件的实际位置，避免了路径不匹配导致的构建问题。

**版本升级** 项目版本从3.0.0升级到3.0.1，这一升级体现在Android、iOS和Web三个平台的版本信息中。版本同步功能确保了三端版本号的一致性，消除了版本不匹配导致的用户体验问题。

**Set-AndroidGradleValue函数** 最新引入的Set-AndroidGradleValue函数提供了精确的Android Gradle文件值修改功能。该函数能够安全地修改build.gradle中的versionCode和versionName字段，支持正则表达式匹配和UTF-8无BOM文件写回，确保版本信息的准确性和一致性。这一功能的引入为版本管理提供了更精细的控制能力。

**增强的版本同步脚本帮助系统** sync_version_bywin.ps1脚本现在提供了完整的参数化版本设置功能，支持通过命令行参数直接设置版本号，同时保持原有的帮助系统和使用示例。该脚本可以单独执行以同步版本号，而无需进行完整的构建流程，显著提升了开发效率。

**版本同步功能** 最新更新的Sync-AppVersion函数和sync_version_bywin.ps1脚本提供了革命性的版本号统一管理功能。**重要更新** 该功能确保Android、iOS和Web三个平台的版本号始终保持一致，避免了版本不匹配导致的用户体验问题。**关键改进** 版本号的唯一权威来源是android/app/build.gradle，系统会自动读取versionCode和versionName并同步到iOS的project.pbxproj和Web的四个environment*.ts文件中，**消除了残留环境变量的影响**。这一功能的引入显著提升了多平台应用的版本管理效率，是整个自动化系统的重要里程碑。

**RubyGems镜像检测系统** 最新更新的Ruby安装脚本引入了革命性的RubyGems镜像检测系统，显著提升了Ruby gems下载的可靠性和速度。该系统现在支持两个国内RubyGems镜像源的动态探测，自动选择最优下载源，并通过Inno Setup参数实现了UTF-8支持和PATH环境变量的自动配置。这些改进使得Ruby安装过程更加稳定可靠，大大减少了因网络问题导致的安装失败。

**PATH同步机制增强** 新增的Sync-PathFromRegistry函数解决了Ruby安装后PATH环境变量不同步的关键问题。由于RubyInstaller的modpath任务会将ruby/bin写入用户PATH（注册表），但当前PowerShell会话的$env:Path是进程启动时的快照不会自动刷新，该函数从注册表重新读取机器级和用户级PATH，合并注入当前PowerShell会话，确保新安装的Ruby和Bundler在当前会话中立即可用，无需重开窗口。

**Bundler版本兼容性检查** 新增的Test-LockfileBundlerMismatch函数确保Gemfile.lock与当前Bundler版本完全兼容，避免版本不匹配导致的构建问题。该函数会自动检测lockfile中的BUNDLED WITH版本，并与当前Bundler版本进行对比，必要时自动对齐版本，确保构建过程的稳定性和可靠性。

**Ruby 4.0+兼容性增强** **新增** 通过在android/Gemfile中添加gem 'fiddle'来解决Ruby 4.0+的Fastlane集成问题。自Ruby 4.0起，fiddle不再作为默认gem包含，但fastlane依赖链需要此gem才能正常工作。这一修复确保了在Ruby 4.0+环境中Fastlane的稳定运行，显著改善了开发者体验。

**RubyGems镜像检测系统优化** **更新** 最新版本的RubyGems镜像检测系统从USTC、清华、Ruby-China改为腾讯云、华为云镜像，并优化了检测算法，增加了AllowAutoRedirect=$false设置以防止HTTP 302重定向导致的误判。该系统现在支持两个国内RubyGems镜像源的动态探测，自动选择最优下载源，显著提升了下载成功率和速度。

**新增Java版本强制验证** **重大更新** 新增的Assert-JavaForAndroid函数提供了精确的JDK版本范围验证，强制要求JDK 17-21版本，确保Android构建环境的兼容性和稳定性。该函数基于Gradle 8.13官方支持范围和Capacitor 7的配置需求，为Android构建提供了严格的质量保障。该函数的引入显著提升了构建过程的可靠性，避免了因Java版本不兼容导致的构建失败。

**命令执行可视化改进** _common.ps1中的Install-WingetPackage函数增强了命令执行显示功能，现在在执行winget安装时会显示完整的命令行，便于调试和审计。配合改进的Invoke-NativeStream函数，提供了更好的进度条显示和错误处理能力。

**用户界面本地化** 所有错误消息和用户界面已本地化为中文，显著提升了中文用户的使用体验。从日志输出到交互提示，都采用了中文界面，使用户能够更好地理解和使用脚本系统。

### 主要优势

1. **高度自动化**: 减少了手动配置的复杂性和出错概率
2. **智能检测**: 自动识别现有环境并提供针对性的解决方案
3. **多源支持**: 国内RubyGems镜像加速下载，提高可靠性
4. **错误恢复**: 完善的错误处理和恢复机制
5. **用户友好**: 统一的交互界面和详细的进度反馈
6. **平台专优化**: 针对不同平台（Windows、Android）的特定优化
7. **下载性能**: 多源并行下载和智能选择算法
8. **环境配置**: 自动UTF-8支持和PATH环境变量配置
9. **PATH同步**: 确保Ruby安装后PATH立即生效
10. **命令可视化**: 改进的命令行显示和错误处理
11. **版本兼容**: 自动处理Bundler版本不匹配问题
12. **镜像检测**: 动态探测RubyGems镜像源，提升下载成功率
13. **Ruby 4.0+支持**: **新增** 通过fiddle gem确保Ruby 4.0+的Fastlane兼容性
14. **中文本地化**: 全面的中文用户界面支持
15. **Java版本强制验证**: **新增** 确保Android构建环境的严格兼容性
16. **Gradle兼容性保障**: **新增** 基于Gradle 8.13官方支持范围的版本验证
17. **版本同步管理**: **新增** 三端版本号统一管理，避免版本不匹配
18. **独立版本同步**: **新增** 支持仅同步版本号而不构建，提升开发效率
19. **参数化版本设置**: **新增** 支持通过命令行参数直接设置版本号
20. **Android Gradle值修改**: **新增** 提供精确的Android Gradle文件值修改功能
21. **Android签名配置管理**: **新增** 提供完整的Android签名配置管理功能
22. **Web构建版本同步**: **新增** 在Web构建前自动同步版本信息
23. **消除环境变量干扰**: **新增** 版本号始终从android/app/build.gradle读取，消除了残留环境变量的影响
24. **NTFS junction路径解析**: **新增** 解决Windows开发环境中的路径兼容性问题
25. **路径解析性能优化**: **新增** 基于.NET API的高效路径解析机制
26. **路径检查机制**: **新增** 逐级检查junction并替换为Substitute Name
27. **综合参数系统**: **新增** 提供完整的命令行参数文档和使用示例
28. **多平台发布支持**: **新增** 支持GitHub和Gitee两个平台的Release发布
29. **自动版本递增**: **新增** 智能的versionCode自动递增机制
30. **发布流程自动化**: **新增** 完整的发布流程，包括产物验证和错误处理

### 技术特色

- **模块化设计**: 通过共享函数库实现代码复用
- **环境隔离**: 支持用户级和系统级环境变量配置
- **性能优化**: 针对 Windows 平台的特殊优化措施
- **安全考虑**: 完整的卸载和清理机制
- **版本兼容**: 智能处理不同框架版本的兼容性问题
- **工具链整合**: 通过Bundler确保Ruby + fastlane版本一致性
- **下载优化**: 多源并行下载和文件大小校验
- **用户界面**: 清晰的进度反馈和状态提示
- **PATH管理**: 自动同步注册表PATH变更
- **命令执行**: 增强的命令行显示和错误处理
- **镜像检测**: 动态探测RubyGems镜像源，提升下载成功率
- **版本检查**: 自动处理Bundler版本不匹配问题
- **Ruby 4.0+兼容性**: **新增** 通过fiddle gem解决Ruby 4.0+集成问题
- **Java版本验证**: **新增** 精确的JDK 17-21版本范围验证
- **Gradle兼容性**: **新增** 基于官方支持范围的版本约束
- **版本同步机制**: **新增** 从android/app/build.gradle读取版本并同步到iOS和Web
- **独立版本同步**: **新增** 支持仅同步版本号而不构建的场景
- **参数化版本设置**: **新增** 支持通过命令行参数直接设置版本号
- **Android Gradle值修改**: **新增** 提供精确的Android Gradle文件值修改功能
- **Android签名配置**: **新增** 提供完整的Android签名配置管理功能
- **Web构建集成**: **新增** 在Web构建前自动同步版本信息
- **环境变量干扰消除**: **新增** 版本号权威来源始终为build.gradle，避免残留环境变量影响
- **NTFS junction处理**: **新增** 通过Resolve-JunctionPath函数解决路径解析问题
- **路径解析优化**: **新增** 基于.NET API的高效路径解析实现
- **路径检查算法**: **新增** 逐级检查junction并替换为Substitute Name的智能算法
- **综合参数系统**: **新增** 提供完整的命令行参数文档和使用示例
- **多平台发布**: **新增** 支持GitHub和Gitee两个平台的Release发布
- **自动版本递增**: **新增** 智能的versionCode自动递增机制
- **发布流程自动化**: **新增** 完整的发布流程，包括产物验证和错误处理

这套 PowerShell 自动化系统不仅提高了开发效率，更为项目的长期维护奠定了坚实的基础，是现代跨平台开发项目的优秀范例。新增的完整脚本生态系统进一步增强了系统的实用性和完整性，为开发者提供了从环境搭建到应用发布的全流程自动化解决方案。特别是Ruby安装脚本的重大改进、RubyGems镜像检测系统的引入、PATH同步机制的增强、Bundler版本兼容性检查的实现、Ruby 4.0+兼容性的新增、**最重要的Java版本强制验证功能**、**最关键的版本同步功能**、**最实用的Set-AndroidGradleValue函数**、**最全面的Android签名配置管理**、**最关键的新NTFS junction路径解析功能**，以及**最新的综合参数系统和发布功能**，为Android应用构建提供了更加稳定可靠的开发环境，是整个自动化系统的重要里程碑。

**Resolve-JunctionPath函数**的引入标志着系统在路径兼容性方面的重大进步。通过将NTFS junction解析为真实物理路径，系统现在能够解决PowerShell Resolve-Path与Node.js/webpack路径解析不一致的问题，确保TypeScript编译器和其他工具链能够正确识别项目文件的实际位置。这一功能的实现体现了系统对细节的关注和对开发者体验的重视，是现代开发工具链不可或缺的重要组成部分。

**增强的版本同步脚本帮助系统**的引入标志着系统在用户交互方面的重大进步。通过参数化版本设置和增强的帮助系统，sync_version_bywin.ps1脚本现在提供了更灵活的使用方式，支持通过命令行参数直接设置版本号，同时保持原有的帮助系统和使用示例。这一功能的实现体现了系统对用户体验的关注和对开发者需求的理解，是现代开发工具链的重要组成部分。

**版本同步功能**的引入标志着系统在多平台版本管理方面的重大进步。**关键更新** 通过Sync-AppVersion函数和sync_version_bywin.ps1脚本，系统现在能够确保Android、iOS和Web三个平台的版本号始终保持一致，避免了版本不匹配导致的用户体验问题。**重要改进** 版本号的唯一权威来源是android/app/build.gradle，系统会自动读取versionCode和versionName并同步到iOS的project.pbxproj和Web的四个environment*.ts文件中，**消除了残留环境变量的影响**。这一功能的实现体现了系统对细节的关注和对开发者体验的重视，是现代开发工具链不可或缺的重要组成部分。

**Android签名配置管理功能**的引入标志着系统在Android开发方面的重大进步。通过Load-AndroidSigningPs1和Print-AndroidSigningHelp函数，系统现在能够提供完整的Android签名配置管理功能，包括本地签名配置加载和签名配置创建指导。这一功能的实现体现了系统对Android开发需求的深入理解和对开发者体验的重视，是现代Android开发工具链的重要组成部分。

**版本升级** 项目版本从3.0.0升级到3.0.1，这一升级体现在Android、iOS和Web三个平台的版本信息中。版本同步功能确保了三端版本号的一致性，消除了版本不匹配导致的用户体验问题。这一升级为用户提供了最新的功能和修复，提升了应用的整体质量和用户体验。

**NTFS junction路径解析功能**的引入标志着系统在Windows开发环境兼容性方面的重大进步。通过Resolve-JunctionPath函数，系统现在能够智能处理各种复杂的开发环境配置，包括多盘符开发、网络驱动器映射、符号链接等场景。这一功能的实现显著提升了开发环境的兼容性和稳定性，特别是在团队协作和分布式开发环境中，是现代Windows开发工具链的重要组成部分。

**新增的综合参数系统**标志着系统在用户交互方面的重大进步。通过提供完整的命令行参数文档和使用示例，build_android_bywin.ps1脚本现在支持多种构建和发布模式，包括-build构建、-publish发布、-check检查等。这种参数化的设计使得脚本更加灵活易用，适合不同的使用场景和自动化需求。

**多平台发布功能**的引入标志着系统在应用分发方面的重大进步。通过支持GitHub和Gitee两个主要代码托管平台的Release发布，系统现在能够实现完整的发布流程自动化。从产物验证到认证处理，从tag管理到说明文件上传，每个环节都经过精心设计，确保发布过程的可靠性和可重复性。

**自动versionCode递增功能**的引入标志着系统在版本管理方面的重大进步。通过智能的版本号管理机制，系统现在能够确保每次构建都生成唯一的版本号，避免了版本冲突问题。这一功能与现有的版本同步机制完美结合，形成了完整的版本管理体系。

这套 PowerShell 自动化系统展现了现代开发工具链的最佳实践，通过精心设计的模块化架构、完善的错误处理机制和智能化的用户交互体验，为开发者提供了高效、可靠的开发环境管理解决方案。新增的版本同步功能、Set-AndroidGradleValue函数、增强的版本同步脚本帮助系统、Android签名配置管理功能、**最关键的NTFS junction路径解析功能**，以及**最新的综合参数系统、多平台发布功能和自动版本递增功能**，进一步完善了整个自动化系统，为多平台应用开发提供了更加完整和可靠的工具链支持。

**综合参数系统**的引入标志着系统在用户交互方面的重大进步。通过提供完整的命令行参数文档和使用示例，build_android_bywin.ps1脚本现在支持多种构建和发布模式，包括-build构建、-publish发布、-check检查等。这种参数化的设计使得脚本更加灵活易用，适合不同的使用场景和自动化需求。

**多平台发布功能**的引入标志着系统在应用分发方面的重大进步。通过支持GitHub和Gitee两个主要代码托管平台的Release发布，系统现在能够实现完整的发布流程自动化。从产物验证到认证处理，从tag管理到说明文件上传，每个环节都经过精心设计，确保发布过程的可靠性和可重复性。

**自动versionCode递增功能**的引入标志着系统在版本管理方面的重大进步。通过智能的版本号管理机制，系统现在能够确保每次构建都生成唯一的版本号，避免了版本冲突问题。这一功能与现有的版本同步机制完美结合，形成了完整的版本管理体系。

**发布流程自动化**的引入标志着系统在应用分发方面的重大进步。通过完整的发布流程自动化，系统现在能够处理从产物验证到平台发布的整个过程。无论是GitHub还是Gitee平台，都能提供一致的发布体验，大大简化了应用的发布流程。

这些新增功能与现有系统的完美结合，使得整个自动化系统更加完善和强大，为开发者提供了从环境搭建到应用发布的完整解决方案。