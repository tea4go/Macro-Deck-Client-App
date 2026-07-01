# Windows PowerShell自动化

<cite>
**本文档引用的文件**
- [_common.ps1](file://scripts/windows/_common.ps1)
- [build_android_bywin.ps1](file://scripts/windows/build_android_bywin.ps1)
- [install_1_base_tools_bywin.ps1](file://scripts/windows/install_1_base_tools_bywin.ps1)
- [install_2_ruby_bywin.ps1](file://scripts/windows/install_2_ruby_bywin.ps1)
- [install_3_fastlane_bywin.ps1](file://scripts/windows/install_3_fastlane_bywin.ps1)
- [install_4_android_sdk_bywin.ps1](file://scripts/windows/install_4_android_sdk_bywin.ps1)
- [remove_1_android_sdk_bywin.ps1](file://scripts/windows/remove_1_android_sdk_bywin.ps1)
- [remove_3_ruby_bywin.ps1](file://scripts/windows/remove_3_ruby_bywin.ps1)
- [sync_version_bywin.ps1](file://scripts/windows/sync_version_bywin.ps1)
- [Gemfile.lock](file://Gemfile.lock)
- [android/Gemfile](file://android/Gemfile)
- [android/Gemfile.lock](file://android/Gemfile.lock)
- [android/fastlane/Fastfile](file://android/fastlane/Fastfile)
- [android/fastlane/Pluginfile](file://android/fastlane/Pluginfile)
- [scripts/README.md](file://scripts/README.md)
</cite>

## 更新摘要
**变更内容**
- 新增Sync-AppVersion PowerShell函数和版本同步脚本，提供三端版本号统一管理功能
- 在Android构建流程中集成版本同步，确保Android、iOS和Web版本一致性
- 增强版本同步机制，支持从android/app/build.gradle读取版本信息并同步到iOS和Web
- 新增独立的版本同步脚本sync_version_bywin.ps1，支持仅同步版本号而不构建
- 改进了Java版本检测和错误处理机制，提供更精确的版本范围验证
- 在构建脚本中集成了新的Java版本验证，确保Android构建环境的准确性
- 增强了错误处理和环境检测功能，提供更详细的版本兼容性信息
- 更新RubyGems镜像检测系统：改进了镜像候选列表，从USTC、清华、Ruby-China改为腾讯云、华为云镜像，并优化了检测算法，增加了AllowAutoRedirect=$false设置以防止HTTP 302重定向导致的误判
- 增强PATH同步机制，通过Sync-PathFromRegistry函数解决Ruby安装后PATH环境变量不同步问题
- 新增Bundler版本兼容性检查（Test-LockfileBundlerMismatch函数），确保Gemfile.lock与当前Bundler版本对齐
- **更新** Gemfile.lock从Bundler 2.4.10更新到4.0.10，提升版本兼容性
- 所有错误消息和用户界面已本地化为中文，提升用户体验

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

**重大现代化升级** 该系统现已包含八个专门的PowerShell构建脚本，涵盖从基础工具安装到复杂应用构建的全流程自动化。新增的脚本体系包括基础工具管理、Ruby + fastlane工具链管理、Android SDK安装、**版本同步管理**以及完整的构建脚本，形成了完整的开发环境自动化解决方案。

**版本同步功能** **新增** 最新更新的Sync-AppVersion函数和sync_version_bywin.ps1脚本提供了革命性的版本号统一管理功能。该功能确保Android、iOS和Web三个平台的版本号始终保持一致，避免了版本不匹配导致的用户体验问题。版本号的唯一权威来源是android/app/build.gradle，系统会自动读取versionCode和versionName并同步到iOS的project.pbxproj和Web的四个environment*.ts文件中。

**RubyGems镜像检测系统** 最新更新的Ruby安装脚本（install_2_ruby_bywin.ps1）引入了革命性的RubyGems镜像检测系统，显著提升了Ruby gems下载的可靠性和速度。该系统现在支持两个国内RubyGems镜像源的动态探测，自动选择最优下载源，并通过Inno Setup参数实现了UTF-8支持和PATH环境变量的自动配置。

**PATH同步机制增强** 新增的Sync-PathFromRegistry函数解决了Ruby安装后PATH环境变量不同步的关键问题。由于RubyInstaller的modpath任务会将ruby/bin写入用户PATH（注册表），但当前PowerShell会话的$env:Path是进程启动时的快照不会自动刷新，该函数从注册表重新读取机器级和用户级PATH，合并注入当前PowerShell会话，确保新安装的Ruby和Bundler在当前会话中立即可用。

**Bundler版本兼容性检查** 新增的Test-LockfileBundlerMismatch函数确保Gemfile.lock与当前Bundler版本完全兼容，避免版本不匹配导致的构建问题。该函数会自动检测lockfile中的BUNDLED WITH版本，并与当前Bundler版本进行对比，必要时自动对齐版本。

**Ruby 4.0+兼容性增强** **新增** 通过在android/Gemfile中添加gem 'fiddle'来解决Ruby 4.0+的Fastlane集成问题。自Ruby 4.0起，fiddle不再作为默认gem包含，但fastlane依赖链需要此gem才能正常工作。这一修复确保了在Ruby 4.0+环境中Fastlane的稳定运行。

**RubyGems镜像检测系统优化** **更新** 最新版本的RubyGems镜像检测系统从USTC、清华、Ruby-China改为腾讯云、华为云镜像，并优化了检测算法，增加了AllowAutoRedirect=$false设置以防止HTTP 302重定向导致的误判。该系统现在支持两个国内RubyGems镜像源的动态探测，自动选择最优下载源，显著提升了下载成功率和速度。

**新增Java版本强制验证** **重大更新** 新增的Assert-JavaForAndroid函数提供了精确的JDK版本范围验证，强制要求JDK 17-21版本，确保Android构建环境的兼容性和稳定性。该函数基于Gradle 8.13官方支持范围和Capacitor 7的配置需求，为Android构建提供了严格的质量保障。

这些 PowerShell 脚本提供了从基础环境检查到复杂工具链安装的全方位自动化支持，特别针对 Windows 开发环境进行了深度优化。脚本系统采用模块化设计，通过共享的通用函数库实现代码复用，确保了一致的用户体验和可靠的执行流程。

## 项目结构

项目中的 Windows PowerShell 自动化脚本主要位于 `scripts/windows/` 目录下，现已发展为包含八个核心脚本的完整生态系统：

```mermaid
graph TB
subgraph "Windows PowerShell自动化脚本系统"
Common[_common.ps1<br/>通用函数库<br/>新增Java版本验证函数<br/>新增Sync-AppVersion版本同步函数]
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
BuildAndroid[build_android_bywin.ps1<br/>Android应用构建<br/>新增Java版本验证<br/>新增版本同步集成]
end
subgraph "版本同步脚本"
SyncVersion[sync_version_bywin.ps1<br/>版本号同步脚本<br/>独立版本同步功能]
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
Common --> SyncVersion
Common --> RemoveSDK
Common --> RemoveRuby
end
```

**图表来源**
- [scripts/windows/_common.ps1:1-1258](file://scripts/windows/_common.ps1#L1-L1258)
- [scripts/windows/install_1_base_tools_bywin.ps1:1-930](file://scripts/windows/install_1_base_tools_bywin.ps1#L1-L930)
- [scripts/windows/install_2_ruby_bywin.ps1:1-173](file://scripts/windows/install_2_ruby_bywin.ps1#L1-L173)
- [scripts/windows/install_3_fastlane_bywin.ps1:1-218](file://scripts/windows/install_3_fastlane_bywin.ps1#L1-L218)
- [scripts/windows/install_4_android_sdk_bywin.ps1:1-249](file://scripts/windows/install_4_android_sdk_bywin.ps1#L1-L249)
- [scripts/windows/build_android_bywin.ps1:1-157](file://scripts/windows/build_android_bywin.ps1#L1-L157)
- [scripts/windows/sync_version_bywin.ps1:1-22](file://scripts/windows/sync_version_bywin.ps1#L1-L22)

**章节来源**
- [scripts/windows/_common.ps1:1-1258](file://scripts/windows/_common.ps1#L1-L1258)
- [scripts/windows/install_1_base_tools_bywin.ps1:1-930](file://scripts/windows/install_1_base_tools_bywin.ps1#L1-L930)
- [scripts/windows/install_2_ruby_bywin.ps1:1-173](file://scripts/windows/install_2_ruby_bywin.ps1#L1-L173)
- [scripts/windows/install_3_fastlane_bywin.ps1:1-218](file://scripts/windows/install_3_fastlane_bywin.ps1#L1-L218)
- [scripts/windows/install_4_android_sdk_bywin.ps1:1-249](file://scripts/windows/install_4_android_sdk_bywin.ps1#L1-L249)
- [scripts/windows/build_android_bywin.ps1:1-157](file://scripts/windows/build_android_bywin.ps1#L1-L157)
- [scripts/windows/sync_version_bywin.ps1:1-22](file://scripts/windows/sync_version_bywin.ps1#L1-L22)

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

#### **新增** Java版本验证功能
**重大更新** 新增了精确的Java版本验证函数，确保Android构建环境的兼容性：

- **Java版本检测** (`Get-JavaMajorVersion`): 检测当前安装的Java主版本号
- **Java 17+验证** (`Assert-Java17`): 强制要求Java 17+版本
- **Android专用Java验证** (`Assert-JavaForAndroid`): 强制JDK 17-21版本范围，确保Gradle 8.13兼容性

#### **新增** 版本同步功能
**重大更新** 新增了完整的版本同步机制，确保三端版本一致性：

- **版本同步函数** (`Sync-AppVersion`): 从android/app/build.gradle读取版本信息并同步到iOS和Web
- **iOS版本同步** (`CURRENT_PROJECT_VERSION`, `MARKETING_VERSION`): 更新Xcode工程的版本信息
- **Web版本同步** (`environment*.ts`): 更新四个环境配置文件的版本信息
- **版本读取函数** (`Read-AndroidGradleValue`): 从Gradle文件读取版本字段

**章节来源**
- [scripts/windows/_common.ps1:11-120](file://scripts/windows/_common.ps1#L11-L120)
- [scripts/windows/_common.ps1:123-213](file://scripts/windows/_common.ps1#L123-L213)
- [scripts/windows/_common.ps1:242-341](file://scripts/windows/_common.ps1#L242-L341)
- [scripts/windows/_common.ps1:945-972](file://scripts/windows/_common.ps1#L945-L972)
- [scripts/windows/_common.ps1:284-329](file://scripts/windows/_common.ps1#L284-L329)
- [scripts/windows/_common.ps1:880-1258](file://scripts/windows/_common.ps1#L880-L1258)

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
- [android/Gemfile:1-8](file://android/Gemfile#L1-L8)

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

### Android应用构建脚本 (build_android_bywin.ps1)

**更新** 该脚本提供了完整的 Android 应用构建支持，集成了Ionic + Capacitor + fastlane工具链。

#### 核心功能
- **签名环境验证**: 检查BUILD_NUMBER、VERSION_NUMBER、KEYSTORE_FILE_PASSWORD等变量
- **Ionic构建**: 使用production配置构建Web资源
- **Capacitor同步**: 执行cap sync android同步平台
- **fastlane集成**: 通过bundle exec fastlane build生成APK/AAB
- **版本同步**: 构建完成后自动同步版本号到iOS和Web

#### **新增** Java版本验证集成
**重大更新** 在Android构建脚本中集成了新的Java版本验证功能：

```powershell
$ready = $true
if (-not (Assert-JavaForAndroid)) { $ready = $false }
if (-not (Require-AndroidReleaseEnv)) { $ready = $false }
if (-not (Require-Command 'npx')) { $ready = $false }
if (-not (Require-Fastlane)) { $ready = $false }
```

该验证确保Android构建环境使用JDK 17-21版本，符合Gradle 8.13官方支持范围和Capacitor 7的配置需求。

#### **新增** 版本同步集成
**重大更新** 在Android构建完成后自动执行版本同步：

```powershell
# fastlane 已把（自增后的）versionCode/versionName 写回 build.gradle，
# 以它为源同步到 iOS 与 Web，保持三端版本一致。
Sync-AppVersion
```

该功能确保Android、iOS和Web三个平台的版本号始终保持一致，避免了版本不匹配导致的用户体验问题。

#### 特殊优化
- **本地签名配置**: 支持scripts/local/android-signing.ps1
- **环境变量管理**: 自动从build.gradle读取版本信息
- **命令执行封装**: 统一的命令执行和错误处理

**章节来源**
- [scripts/windows/build_android_bywin.ps1:45-76](file://scripts/windows/build_android_bywin.ps1#L45-L76)
- [scripts/windows/build_android_bywin.ps1:119](file://scripts/windows/build_android_bywin.ps1#L119)
- [scripts/windows/build_android_bywin.ps1:141-229](file://scripts/windows/build_android_bywin.ps1#L141-L229)

### **新增** 版本同步脚本 (sync_version_bywin.ps1)

**重大更新** 该脚本提供了独立的版本号同步功能，专门用于在不进行完整构建的情况下同步三端版本号。

#### 核心功能特性
- **独立版本同步**: 仅同步版本号，不执行构建流程
- **版本源权威性**: 以android/app/build.gradle为唯一版本权威源
- **三端同步**: 同步到iOS和Web平台的版本信息
- **解耦构建**: 与构建流程解耦，适合"只想对齐版本号"的场景

#### 版本同步机制
- **iOS同步**: 更新project.pbxproj的CURRENT_PROJECT_VERSION和MARKETING_VERSION
- **Web同步**: 更新四个environment*.ts文件的version和versionCode
- **UTF-8无BOM写回**: 确保文件编码一致性

#### 使用场景
- **版本对齐**: 当需要快速同步三端版本号而不需要完整构建时
- **预发布检查**: 在正式构建前验证版本号一致性
- **CI/CD集成**: 在持续集成流程中单独执行版本同步步骤

**章节来源**
- [scripts/windows/sync_version_bywin.ps1:1-22](file://scripts/windows/sync_version_bywin.ps1#L1-L22)

## 架构概览

整个 PowerShell 自动化系统采用分层架构设计，确保了高内聚、低耦合的特性：

```mermaid
graph TB
subgraph "用户接口层"
CLI[命令行界面]
Menu[交互菜单]
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
end
subgraph "基础设施层"
Common[通用函数库<br/>新增Java版本验证<br/>新增Sync-AppVersion版本同步]
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
End
CLI --> EnvCheck
CLI --> Install
CLI --> Uninstall
CLI --> Build
CLI --> BaseTools
CLI --> RubyFastlane
CLI --> AndroidSetup
CLI --> VersionSync
EnvCheck --> Common
Install --> Common
Uninstall --> Common
Build --> Common
BaseTools --> Common
RubyFastlane --> Common
AndroidSetup --> Common
VersionSync --> Common
Common --> Helpers
Common --> Download
Common --> Registry
Common --> Mirror
Common --> Bundler
Common --> PATH
Common --> Ruby40Compatibility
Common --> JavaValidation
Common --> VersionSyncFunction
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
RubyFastlane --> Ruby
RubyFastlane --> Fastlane
AndroidSetup --> AndroidSDK
VersionSync --> VersionSyncFunction
```

**图表来源**
- [scripts/windows/_common.ps1:1-1258](file://scripts/windows/_common.ps1#L1-L1258)
- [scripts/windows/install_1_base_tools_bywin.ps1:1-930](file://scripts/windows/install_1_base_tools_bywin.ps1#L1-L930)
- [scripts/windows/install_2_ruby_bywin.ps1:1-173](file://scripts/windows/install_2_ruby_bywin.ps1#L1-L173)
- [scripts/windows/install_3_fastlane_bywin.ps1:1-218](file://scripts/windows/install_3_fastlane_bywin.ps1#L1-L218)
- [scripts/windows/install_4_android_sdk_bywin.ps1:1-249](file://scripts/windows/install_4_android_sdk_bywin.ps1#L1-L249)
- [scripts/windows/build_android_bywin.ps1:1-157](file://scripts/windows/build_android_bywin.ps1#L1-L157)
- [scripts/windows/sync_version_bywin.ps1:1-22](file://scripts/windows/sync_version_bywin.ps1#L1-L22)

## 详细组件分析

### Ruby + Fastlane安装流程详细分析

```mermaid
sequenceDiagram
participant User as 用户
participant RubyScript as Ruby安装脚本
participant FastlaneScript as Fastlane安装脚本
participant Common as 通用函数
participant RubyInstaller as RubyInstaller
participant Bundler as Bundler
participant RubyGems as RubyGems镜像
User->>RubyScript : 执行install_2_ruby_bywin.ps1
RubyScript->>Common : 检测Ruby版本
RubyScript->>RubyInstaller : 多源下载RubyInstaller-DevKit
RubyInstaller->>Common : 并行测速选择最优源
RubyInstaller-->>RubyScript : 返回安装结果
RubyScript->>Common : 调用Sync-PathFromRegistry
RubyScript->>Common : 检测Bundler
RubyScript->>Bundler : 安装Bundler
Bundler-->>RubyScript : 返回安装结果
RubyScript->>RubyGems : Select-GemMirror动态探测
RubyGems-->>RubyScript : 返回可用镜像
RubyScript->>User : 显示Ruby + Bundler状态
User->>FastlaneScript : 执行install_3_fastlane_bywin.ps1
FastlaneScript->>Common : 查找Gemfile
FastlaneScript->>Common : 调用Sync-PathFromRegistry
FastlaneScript->>RubyGems : Select-GemMirror动态探测
RubyGems-->>FastlaneScript : 返回可用镜像
FastlaneScript->>Bundler : Test-LockfileBundlerMismatch检查
Bundler-->>FastlaneScript : 返回版本兼容性
FastlaneScript->>Bundler : bundle install
Bundler-->>FastlaneScript : 返回安装结果
FastlaneScript->>User : 显示Fastlane状态
```

**图表来源**
- [scripts/windows/install_2_ruby_bywin.ps1:46-78](file://scripts/windows/install_2_ruby_bywin.ps1#L46-L78)
- [scripts/windows/install_3_fastlane_bywin.ps1:32-63](file://scripts/windows/install_3_fastlane_bywin.ps1#L32-L63)

### Android构建流程详细分析

```mermaid
sequenceDiagram
participant User as 用户
participant BuildScript as Android构建脚本
participant Common as 通用函数
participant JavaValidation as Java版本验证
participant VersionSync as 版本同步函数
participant Ionic as Ionic CLI
participant Capacitor as Capacitor CLI
participant Fastlane as fastlane
User->>BuildScript : 执行build_android_bywin.ps1
BuildScript->>Common : 加载签名配置
BuildScript->>Common : 验证环境变量
BuildScript->>JavaValidation : Assert-JavaForAndroid验证
JavaValidation->>Common : Get-JavaMajorVersion检测
JavaValidation-->>BuildScript : 返回JDK 17-21验证结果
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
BuildScript->>User : 显示APK/AAB路径
```

**图表来源**
- [scripts/windows/build_android_bywin.ps1:104-157](file://scripts/windows/build_android_bywin.ps1#L104-L157)

### 版本同步流程详细分析

```mermaid
sequenceDiagram
participant User as 用户
participant SyncScript as 版本同步脚本
participant Common as 通用函数
participant GradleReader as Gradle文件读取
participant IOSync as iOS版本同步
participant WebSync as Web版本同步
User->>SyncScript : 执行sync_version_bywin.ps1
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
- [scripts/windows/sync_version_bywin.ps1:18-22](file://scripts/windows/sync_version_bywin.ps1#L18-L22)
- [scripts/windows/_common.ps1:1162-1206](file://scripts/windows/_common.ps1#L1162-L1206)

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
ConfigureMirror --> InstallTerminal[安装Windows终端]
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
- [scripts/windows/remove_3_ruby_bywin.ps1:24-54](file://scripts/windows/remove_3_ruby_bywin.ps1#L24-L54)

**章节来源**
- [scripts/windows/build_android_bywin.ps1:1-157](file://scripts/windows/build_android_bywin.ps1#L1-L157)
- [scripts/windows/install_4_android_sdk_bywin.ps1:1-249](file://scripts/windows/install_4_android_sdk_bywin.ps1#L1-L249)
- [scripts/windows/remove_1_android_sdk_bywin.ps1:1-162](file://scripts/windows/remove_1_android_sdk_bywin.ps1#L1-L162)
- [scripts/windows/remove_3_ruby_bywin.ps1:1-118](file://scripts/windows/remove_3_ruby_bywin.ps1#L1-L118)
- [scripts/windows/sync_version_bywin.ps1:1-22](file://scripts/windows/sync_version_bywin.ps1#L1-L22)

## 依赖关系分析

### 脚本间依赖关系

```mermaid
graph LR
subgraph "共享依赖"
Common[_common.ps1<br/>新增Java版本验证函数<br/>新增Sync-AppVersion版本同步函数]
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
BuildAndroid[build_android_bywin.ps1]
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
Common --> SyncVersion
Common --> RemoveSDK
Common --> RemoveRuby
InstallRuby --> InstallFastlane
InstallFastlane --> BuildAndroid
InstallSDK --> BuildAndroid
BuildAndroid --> SyncVersion
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

#### **新增** Java运行时环境
**重大更新** 新增了严格的Java版本要求：

- **JDK 17-21**: Android构建的严格版本范围
- **Gradle 8.13兼容性**: 符合官方支持范围
- **Capacitor 7兼容性**: 支持sourceCompatibility VERSION_21

#### **新增** 版本同步功能
**重大更新** 新增了完整的版本同步机制：

- **版本权威源**: android/app/build.gradle
- **iOS同步目标**: ios/App/App.xcodeproj/project.pbxproj
- **Web同步目标**: src/environments/*.ts四个文件
- **同步字段**: CURRENT_PROJECT_VERSION/MARKETING_VERSION和version/versionCode

**章节来源**
- [scripts/windows/build_android_bywin.ps1:35-66](file://scripts/windows/build_android_bywin.ps1#L35-L66)
- [scripts/windows/install_2_ruby_bywin.ps1:43-83](file://scripts/windows/install_2_ruby_bywin.ps1#L43-L83)
- [scripts/windows/install_4_android_sdk_bywin.ps1:39-43](file://scripts/windows/install_4_android_sdk_bywin.ps1#L39-L43)
- [android/Gemfile:3-4](file://android/Gemfile#L3-L4)
- [scripts/windows/_common.ps1:1162-1206](file://scripts/windows/_common.ps1#L1162-L1206)

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

#### **新增** Java版本验证性能优化
**重大更新** 新增的Java版本验证功能具有以下性能特点：

- **快速版本检测**: Get-JavaMajorVersion函数仅执行一次java -version调用
- **智能缓存**: 避免重复的版本查询操作
- **精确范围验证**: Assert-JavaForAndroid提供即时的版本范围检查
- **详细错误信息**: 提供具体的版本不兼容原因和解决方案
- **渐进式验证**: 在构建流程中尽早发现Java版本问题，避免后续步骤失败

#### **新增** 版本同步性能优化
**重大更新** 新增的版本同步功能具有以下性能特点：

- **增量同步**: 仅在版本发生变化时执行同步操作
- **文件缓存**: 避免重复读取相同的Gradle文件
- **并行处理**: 同时处理iOS和Web的版本同步
- **错误恢复**: 单个文件同步失败不影响其他文件的处理
- **UTF-8无BOM**: 避免编码转换开销，提升文件写入速度

**章节来源**
- [scripts/windows/build_android_bywin.ps1:97-124](file://scripts/windows/build_android_bywin.ps1#L97-L124)
- [scripts/windows/_common.ps1:607-728](file://scripts/windows/_common.ps1#L607-L728)
- [scripts/windows/_common.ps1:981-1020](file://scripts/windows/_common.ps1#L981-L1020)
- [scripts/windows/install_2_ruby_bywin.ps1:70-103](file://scripts/windows/install_2_ruby_bywin.ps1#L70-L103)
- [scripts/windows/install_2_ruby_bywin.ps1:32-40](file://scripts/windows/install_2_ruby_bywin.ps1#L32-L40)
- [scripts/windows/install_3_fastlane_bywin.ps1:50-75](file://scripts/windows/install_3_fastlane_bywin.ps1#L50-L75)
- [scripts/windows/install_3_fastlane_bywin.ps1:88-105](file://scripts/windows/install_3_fastlane_bywin.ps1#L88-L105)
- [android/Gemfile:4](file://android/Gemfile#L4)
- [scripts/windows/_common.ps1:1162-1206](file://scripts/windows/_common.ps1#L1162-L1206)

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
- [scripts/windows/install_1_base_tools_bywin.ps1:728-731](file://scripts/windows/install_1_base_tools_bywin.ps1#L728-L731)
- [scripts/windows/remove_1_android_sdk_bywin.ps1:26-37](file://scripts/windows/remove_1_android_sdk_bywin.ps1#L26-L37)
- [scripts/windows/remove_3_ruby_bywin.ps1:40-54](file://scripts/windows/remove_3_ruby_bywin.ps1#L40-L54)
- [scripts/windows/install_2_ruby_bywin.ps1:70-103](file://scripts/windows/install_2_ruby_bywin.ps1#L70-L103)
- [scripts/windows/sync_version_bywin.ps1:18-22](file://scripts/windows/sync_version_bywin.ps1#L18-L22)

## 结论

Macro Deck Client App 的 Windows PowerShell 自动化系统展现了现代开发工具链的最佳实践。通过精心设计的模块化架构、完善的错误处理机制和智能化的用户交互体验，这套脚本系统为开发者提供了高效、可靠的开发环境管理解决方案。

**重大现代化升级** 新增的八个专门PowerShell构建脚本进一步完善了整个自动化系统，形成了从基础工具安装到复杂应用构建的完整解决方案。包括基础工具管理脚本、Ruby + fastlane工具链安装脚本、Android SDK安装脚本、**版本同步脚本**以及完整的构建脚本，为Windows平台提供了从Android应用到Web应用的一站式自动化解决方案。

**版本同步功能** **新增** 最新更新的Sync-AppVersion函数和sync_version_bywin.ps1脚本提供了革命性的版本号统一管理功能。该功能确保Android、iOS和Web三个平台的版本号始终保持一致，避免了版本不匹配导致的用户体验问题。版本号的唯一权威来源是android/app/build.gradle，系统会自动读取versionCode和versionName并同步到iOS的project.pbxproj和Web的四个environment*.ts文件中。这一功能的引入显著提升了多平台应用的版本管理效率，是整个自动化系统的重要里程碑。

**RubyGems镜像检测系统** 最新更新的Ruby安装脚本引入了革命性的RubyGems镜像检测系统，显著提升了Ruby gems下载的可靠性和速度。该系统现在支持两个国内RubyGems镜像源的动态探测，自动选择最优下载源，并通过Inno Setup参数实现了UTF-8支持和PATH环境变量的自动配置。这些改进使得Ruby安装过程更加稳定可靠，大大减少了因网络问题导致的安装失败。

**PATH同步机制增强** 新增的Sync-PathFromRegistry函数解决了Ruby安装后PATH环境变量不同步的关键问题。由于RubyInstaller的modpath任务会将ruby/bin写入用户PATH（注册表），但当前PowerShell会话的$env:Path是进程启动时的快照不会自动刷新，该函数从注册表重新读取机器级和用户级PATH，合并注入当前PowerShell会话，确保新安装的Ruby和Bundler在当前会话中立即可用，无需重开窗口。

**Bundler版本兼容性检查** 新增的Test-LockfileBundlerMismatch函数确保Gemfile.lock与当前Bundler版本完全兼容，避免版本不匹配导致的构建问题。该函数会自动检测lockfile中的BUNDLED WITH版本，并与当前Bundler版本进行对比，必要时自动对齐版本，确保构建过程的稳定性和可靠性。

**Ruby 4.0+兼容性增强** **新增** 通过在android/Gemfile中添加gem 'fiddle'来解决Ruby 4.0+的Fastlane集成问题。自Ruby 4.0起，fiddle不再作为默认gem包含，但fastlane依赖链需要此gem才能正常工作。这一修复确保了在Ruby 4.0+环境中Fastlane的稳定运行，显著改善了开发者体验。

**RubyGems镜像检测系统优化** **更新** 最新版本的RubyGems镜像检测系统从USTC、清华、Ruby-China改为腾讯云、华为云镜像，并优化了检测算法，增加了AllowAutoRedirect=$false设置以防止HTTP 302重定向导致的误判。该系统现在支持两个国内RubyGems镜像源的动态探测，自动选择最优下载源，显著提升了下载成功率和速度。

**新增Java版本强制验证** **重大更新** 新增的Assert-JavaForAndroid函数提供了精确的JDK版本范围验证，强制要求JDK 17-21版本，确保Android构建环境的兼容性和稳定性。该函数基于Gradle 8.13官方支持范围和Capacitor 7的配置需求，为Android构建提供了严格的质量保障。这一功能的引入显著提升了构建过程的可靠性，避免了因Java版本不兼容导致的构建失败。

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

这套 PowerShell 自动化系统不仅提高了开发效率，更为项目的长期维护奠定了坚实的基础，是现代跨平台开发项目的优秀范例。新增的完整脚本生态系统进一步增强了系统的实用性和完整性，为开发者提供了从环境搭建到应用发布的全流程自动化解决方案。特别是Ruby安装脚本的重大改进、RubyGems镜像检测系统的引入、PATH同步机制的增强、Bundler版本兼容性检查的实现、Ruby 4.0+兼容性的新增、**最重要的Java版本强制验证功能**以及**最关键的版本同步功能**，为Android应用构建提供了更加稳定可靠的开发环境，是整个自动化系统的重要里程碑。

**版本同步功能**的引入标志着系统在多平台版本管理方面的重大进步。通过Sync-AppVersion函数和sync_version_bywin.ps1脚本，系统现在能够确保Android、iOS和Web三个平台的版本号始终保持一致，避免了版本不匹配导致的用户体验问题。这一功能的实现体现了系统对细节的关注和对开发者体验的重视，是现代开发工具链不可或缺的重要组成部分。

**Java版本强制验证功能**的引入标志着系统在质量控制方面的重大进步。通过Assert-JavaForAndroid函数，系统现在能够确保Android构建环境使用符合Gradle 8.13官方支持范围的JDK版本（17-21），这不仅避免了构建失败，还为开发者提供了明确的版本指导和故障排除信息。这一功能的实现体现了系统对细节的关注和对开发者体验的重视，是现代开发工具链不可或缺的重要组成部分。

**版本同步功能**的引入标志着系统在多平台版本管理方面的重大进步。通过Sync-AppVersion函数和sync_version_bywin.ps1脚本，系统现在能够确保Android、iOS和Web三个平台的版本号始终保持一致，避免了版本不匹配导致的用户体验问题。这一功能的实现体现了系统对细节的关注和对开发者体验的重视，是现代开发工具链不可或缺的重要组成部分。

这套 PowerShell 自动化系统展现了现代开发工具链的最佳实践，通过精心设计的模块化架构、完善的错误处理机制和智能化的用户交互体验，为开发者提供了高效、可靠的开发环境管理解决方案。新增的版本同步功能进一步完善了整个自动化系统，为多平台应用开发提供了更加完整和可靠的工具链支持。