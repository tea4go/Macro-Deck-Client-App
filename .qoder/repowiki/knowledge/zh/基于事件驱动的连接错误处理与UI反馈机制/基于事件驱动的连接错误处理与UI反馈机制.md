---
kind: error_handling
name: 基于事件驱动的连接错误处理与UI反馈机制
category: error_handling
scope:
    - '**'
source_files:
    - src/app/services/websocket/websocket.service.ts
    - src/app/pages/home/home.page.ts
    - src/app/pages/connection-lost/connection-lost.page.ts
    - src/app/pages/home/modals/connection-failed/connection-failed.component.ts
    - src/app/pages/home/modals/insecure-connection/insecure-connection.component.ts
    - src/app/pages/home/modals/add-connection/add-connection.component.ts
---

该仓库采用**事件驱动（EventEmitter）**和**状态导航**相结合的方式处理错误，主要集中在网络连接、安全认证和用户输入验证场景。没有全局统一的错误拦截中间件或复杂的错误类型层级，而是通过服务层抛出事件，由页面组件订阅并触发相应的 UI 反馈（模态框、页面跳转或倒计时重试）。

### 1. 核心架构与模式
*   **事件发射器 (EventEmitter)**：`WebsocketService` 是错误处理的核心枢纽，它定义了 `connectionFailed`、`connectionLost` 和 `closed` 等事件。当底层 WebSocket 连接发生异常时，服务层捕获原始错误并将其转换为语义化的事件发射出去。
*   **状态驱动的导航恢复**：根据连接所处的生命周期阶段（正在连接 vs 已连接后断开），系统采取不同的恢复策略：
    *   **连接中失败**：触发 `connectionFailed` 事件，首页 (`HomePage`) 订阅该事件并弹出 `ConnectionFailedComponent` 模态框展示详细错误信息。
    *   **运行中断开**：触发导航至专用的 `ConnectionLostPage`。该页面内置了自动重试逻辑（10秒倒计时），尝试重新建立连接。
*   **特定错误类型的分支处理**：在 `WebsocketService` 的 `error` 回调中，通过 `instanceof DOMException` 检查错误名称。例如，捕获 `SecurityError` 时会专门弹出 `InsecureConnectionComponent` 提示用户 SSL 证书问题。

### 2. 关键文件与职责
*   **`src/app/services/websocket/websocket.service.ts`**：
    *   负责监听 WebSocket 的 `error` 和 `close` 事件。
    *   `handleError()` 方法根据 `CloseEvent.code` 和当前连接状态 (`isConnected`) 决定是导航到丢失页面还是发射失败事件。
    *   处理 `DOMException` 中的安全错误。
*   **`src/app/pages/home/home.page.ts`**：
    *   订阅 `websocketService.connectionFailed`，调用 `showConnectionFailedModal()` 展示错误详情。
    *   处理用户输入验证错误（通过 `AlertController`）。
*   **`src/app/pages/connection-lost/connection-lost.page.ts`**：
    *   实现断线后的自动重试机制 (`startRetry`)，包含倒计时逻辑和手动取消功能。
*   **`src/app/pages/home/modals/add-connection/add-connection.component.ts`**：
    *   处理表单验证错误，通过 `showErrorAlert()` 使用原生 Alert 组件提示用户缺失必填项（如 Host 或 Port）。

### 3. 开发者约定
*   **错误传播**：服务层不应直接操作 UI，而应通过 `EventEmitter` 暴露错误状态。页面组件负责订阅这些事件并决定如何呈现（弹窗、Toast 或页面跳转）。
*   **连接状态区分**：在处理连接关闭时，必须严格区分“主动关闭”、“正常关闭 (Code 1000)”和“异常断开”。只有非主动且非正常的断开才应触发错误恢复流程。
*   **资源清理**：所有订阅了错误事件的组件必须在生命周期钩子（如 `ionViewDidLeave` 或 `ngOnDestroy`）中取消订阅，防止内存泄漏和重复触发。
*   **用户反馈**：对于可恢复的错误（如网络波动），提供自动重试选项；对于不可恢复或配置错误（如 SSL 信任问题、输入格式错误），提供明确的阻断式提示并要求用户干预。