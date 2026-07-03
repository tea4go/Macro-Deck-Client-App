## 1. 系统概述
该仓库（Macro Deck 跨平台客户端）**未集成**专用的日志框架（如 `winston`、`pino`、`ngx-logger` 或 Sentry 等）。日志记录完全依赖于 JavaScript/TypeScript 原生的 `console` API（`console.log`, `console.error`, `console.info`）。

这种模式在 Ionic/Angular 开发中常见于早期或中小型项目，其特点是：
- **零配置**：无需初始化日志服务。
- **环境依赖**：日志输出直接绑定到运行环境的控制台（浏览器 DevTools、Android Logcat、iOS Xcode Console）。
- **非结构化**：缺乏统一的日志级别管理、上下文追踪或远程上报机制。

## 2. 核心实现与分布
日志调用散落在各个 Service 层，主要用于开发阶段的调试和关键路径的状态打印。

### 关键文件与用途
| 文件路径 | 日志方法 | 用途描述 |
| :--- | :--- | :--- |
| `src/app/services/connection/connection.service.ts` | `console.log` | 打印从本地存储读取并排序后的连接配置列表，用于调试数据持久化逻辑。 |
| `src/app/services/websocket/websocket.service.ts` | `console.info` / `console.log` | 记录 WebSocket 关闭事件代码（`Closed with code ...`）和主动关闭请求（`Close requested`），用于追踪网络连接生命周期。 |
| `src/app/services/loading/loading.service.ts` | `console.error` | 捕获并打印关闭加载弹窗时可能发生的异常，防止 UI 状态不同步导致的静默失败。 |
| `src/main.ts` | `console.log` | 捕获 Angular 应用引导启动（Bootstrap）过程中的致命错误。 |
| `src/app/services/screen-orientation/...` | `console.log` | 当屏幕方向锁定功能不可用时提供反馈。 |

## 3. 架构约定与局限性
### 3.1 缺乏统一抽象
目前不存在统一的 `LoggerService`。这意味着：
- **无法全局控制日志级别**：在生产环境中，`console.log` 依然会输出，可能泄露敏感信息（如连接配置）或影响性能。
- **无法统一格式化**：日志输出格式取决于各开发人员的习惯，缺乏时间戳、模块标识等标准字段。

### 3.2 平台差异性
由于基于 Capacitor/Ionic：
- **Web/PWA**：日志输出至浏览器控制台。
- **Android**：日志通过 WebView 桥接至 Android 系统的 `Logcat`。
- **iOS**：日志输出至 Xcode 的 Debug Area。
开发者需针对不同平台使用不同的工具查看日志，且原生平台的日志过滤较为困难。

## 4. 开发者指南
### 4.1 当前实践
- **调试优先**：目前在 `connection.service.ts` 等核心服务中保留了大量的 `console.log` 用于验证数据流。
- **错误捕获**：在 `try-catch` 块中使用 `console.error` 记录异常堆栈。

### 4.2 建议规范
1. **生产环境清理**：在提交代码前，应移除所有非必要的 `console.log` 调试语句。
2. **敏感信息脱敏**：严禁在日志中明文打印 `token`、`password` 或完整的 `Connection` 对象（目前 `connection.service.ts` 存在此风险）。
3. **未来演进方向**：
   - 引入 `ngx-logger` 或自定义 `LoggerService` 以支持日志级别（DEBUG, INFO, WARN, ERROR）控制。
   - 集成错误监控平台（如 Sentry）以捕获生产环境的运行时错误。
   - 使用 `environment.production` 标志在构建时自动剥离调试日志。