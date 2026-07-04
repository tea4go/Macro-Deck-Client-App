---
kind: configuration_system
name: Macro Deck 客户端配置系统
category: configuration_system
scope:
    - '**'
source_files:
    - src/environments/environment.ts
    - src/environments/environment.prod.ts
    - src/environments/environment.web.ts
    - src/environments/environment.web.prod.ts
    - capacitor.config.ts
    - angular.json
    - src/app/services/settings/settings.service.ts
    - android/variables.gradle
    - android/app/build.gradle
    - ionic.config.json
---

## 1. 核心系统与架构
Macro Deck 客户端采用**分层配置策略**，将运行时环境、原生壳层参数与用户偏好设置分离管理：
- **构建时环境配置 (Build-time)**：基于 Angular 的 `environment` 文件替换机制，区分 Web/原生及开发/生产环境。
- **原生桥接配置 (Native Bridge)**：通过 `capacitor.config.ts` 统一定义跨平台（Android/iOS）的原生行为与资源路径。
- **运行时持久化配置 (Runtime Persistence)**：利用 `@ionic/storage` 实现用户偏好（如主题、连接设置）的本地持久化存储。
- **原生工程配置 (Native Build)**：Android 端采用 Gradle 变量集中管理 SDK 版本与依赖库版本。

## 2. 关键配置文件
| 文件路径 | 作用描述 |
| :--- | :--- |
| `src/environments/environment*.ts` | 定义应用运行模式标识（`production`, `webVersion`）及版本号。 |
| `capacitor.config.ts` | Capacitor 框架核心配置，控制 App ID、Web 资源目录及原生 Scheme。 |
| `angular.json` | 定义构建流水线中的 `fileReplacements` 逻辑，实现不同环境的自动切换。 |
| `src/app/services/settings/settings.service.ts` | 封装所有用户级配置的读写逻辑，提供默认值兜底。 |
| `android/variables.gradle` | 集中声明 Android 编译 SDK 版本及第三方库版本号。 |
| `ionic.config.json` | Ionic CLI 元数据，声明项目类型及集成框架（Capacitor/Cordova）。 |

## 3. 架构细节与约定
### 3.1 环境隔离机制
项目在 `src/environments/` 下维护了四套环境配置：
- `environment.ts`: 原生应用开发环境。
- `environment.prod.ts`: 原生应用生产环境。
- `environment.web.ts`: Web 版本开发环境。
- `environment.web.prod.ts`: Web 版本生产环境。
在 `angular.json` 中，通过 `build.configurations` 下的 `fileReplacements` 属性，根据构建目标（如 `production` 或 `web_production`）自动替换主环境文件。

### 3.2 用户偏好存储规范
`SettingsService` 是访问运行时配置的唯一入口。其设计遵循以下约定：
- **键名常量化管理**：所有 Storage Key 均定义为模块级常量（如 `wakeLockKey`, `appearanceKey`）。
- **默认值内聚**：每个 Getter 方法内部通过 `??` 运算符提供硬编码的默认值（例如：主题默认为 `Dark`，USB 端口默认为 `8191`）。
- **异步操作**：由于底层使用 IndexedDB/SQLite，所有读写操作均为 `async/await` 模式。

### 3.3 原生配置同步
- **Android**: 版本号 (`versionName`) 在 `android/app/build.gradle` 中硬编码为 "3.0.0"，需与 TS 环境文件中的 `version` 保持手动同步。
- **Capacitor**: `webDir` 设置为 `'www'`，确保 Angular 构建产物能被原生壳正确加载。

## 4. 开发者指南
1. **新增配置项**：若需增加用户可修改的设置，必须在 `SettingsService` 中成对添加 `set/get` 方法，并在 `get` 方法中明确指定默认值。
2. **环境差异处理**：在代码中判断当前是否为 Web 版本时，应统一使用 `environment.webVersion` 布尔值，避免硬编码判断 `window` 对象。
3. **版本同步**：发布新版本时，需同时更新 `src/environments/*.ts` 中的 `version` 字段以及 `android/app/build.gradle` 和 iOS `Info.plist` 中的版本信息。
4. **敏感信息**：目前配置系统中未发现针对 API 密钥等敏感信息的加密处理，若有此类需求，应避免直接存入 `environment.ts` 或明文 Storage。