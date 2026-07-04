---
kind: build_system
name: 基于 GitHub Actions 与 Fastlane 的跨平台自动化构建与分发系统
category: build_system
scope:
    - '**'
source_files:
    - .github/workflows/ci.yml
    - .github/workflows/reusable-base-build.yml
    - .github/workflows/reusable-android-build.yml
    - .github/workflows/reusable-ios-build.yml
    - android/fastlane/Fastfile
    - ios/App/fastlane/Fastfile
    - Dockerfile
    - package.json
---

## 1. 核心构建体系
该项目采用 **Ionic/Angular** 作为 Web 核心，通过 **Capacitor** 桥接至原生平台（Android/iOS）。构建流程高度依赖 **GitHub Actions** 进行 CI/CD 编排，并利用 **Fastlane** 处理各平台的签名、打包及发布任务。

### 技术栈概览
- **Web 框架**: Angular 19, Ionic 8
- **原生桥接**: Capacitor 7
- **CI/CD**: GitHub Actions (模块化 Reusable Workflows)
- **自动化脚本**: Fastlane (Ruby)
- **包管理**: npm/yarn (Node.js), Gradle (Android), CocoaPods (iOS)
- **容器化**: Docker (用于生成纯 Web 客户端产物)

## 2. 关键文件与目录结构

### CI/CD 流水线 (`.github/workflows/`)
- `ci.yml`: 主入口文件。定义了从版本判定到多平台构建、再到最终分发的完整依赖图。
- `reusable-determine-version.yml`: 负责根据 Git Tag 或 Commit SHA 确定版本号。
- `reusable-base-build.yml`: 在 Ubuntu 环境下执行 `ionic build`，并同步生成 Android 和 iOS 的原生工程配置，将 `www`、`node_modules` 及原生目录作为中间产物上传。
- `reusable-android-build.yml` / `reusable-ios-build.yml`: 分别在 macOS 环境下下载基础产物，调用 Fastlane 完成原生编译与签名。
- `reusable-*-deployment.yml`: 负责将构建好的 AAB/IPA 包发布至 Google Play Store 或 Apple TestFlight。

### 平台自动化 (`fastlane/`)
- `android/fastlane/Fastfile`: 定义了 `build` (增量版本号、Gradle 签名打包) 和 `release` (上传至 Play Store) 逻辑。
- `ios/App/fastlane/Fastfile`: 定义了 `build` (CocoaPods 安装、证书匹配 Match、IPA 导出) 和 `release` (上传至 TestFlight) 逻辑。

### 构建配置根目录
- `package.json`: 定义 Node.js 依赖及基础脚本。
- `capacitor.config.ts`: Capacitor 桥接配置。
- `Dockerfile`: 提供轻量级的 Web 客户端构建环境，产出静态资源。

## 3. 架构设计与约定

### 模块化工作流设计
项目采用了 **Reusable Workflows** 模式，将构建过程解耦为：
1. **版本判定**: 优先使用 Git Tag（去除 'v' 前缀），非 Tag 触发则回退至默认版本 `3.0.0`。
2. **基础构建 (Base Build)**: 统一处理 Web 层编译，避免在 Android/iOS 任务中重复执行 `npm install` 和 `ionic build`，显著缩短流水线时间。
3. **并行原生构建**: Android 和 iOS 构建互不干扰，均基于 Base Build 的产物进行增量开发。
4. **条件分发**: 仅在检测到 Git Tag 时触发应用商店部署及 GitHub Release 附件上传。

### 版本与构建号管理
- **版本号 (Version Name)**: 由 CI 环境变量 `VERSION_NUMBER` 注入。
- **构建号 (Build Number/Code)**: 采用动态计算策略 `github.run_number + 3000`，确保每次 CI 运行的构建号唯一且递增，满足应用商店的上传要求。

### 安全与签名
- **Android**: 通过 Base64 编码的 Keystore 文件及 Secrets 注入实现签名。
- **iOS**: 利用 `match` 工具配合 SSH Key 从私有仓库拉取证书与 Provisioning Profiles，结合 App Store Connect API Key 实现无交互式签名。

## 4. 开发者规范

1. **发布流程**: 必须通过创建 Git Tag 来触发正式版本的构建与发布。普通 Push 仅触发构建验证。
2. **环境依赖**: 本地开发需安装 Node.js (v22+)、Ionic CLI、Capacitor CLI 以及对应平台的原生开发工具链 (Android Studio/Xcode)。
3. **配置同步**: 修改 Web 代码后，若涉及原生插件变更，需手动或通过 CI 执行 `cap sync` 以更新原生工程。
4. **密钥管理**: 严禁将 Keystore、API Key 或 Match 密码硬编码在代码中，所有敏感信息均通过 GitHub Secrets 传递。