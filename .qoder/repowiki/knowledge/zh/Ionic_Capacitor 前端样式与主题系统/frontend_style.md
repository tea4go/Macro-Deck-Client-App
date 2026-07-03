## 1. 技术栈与核心方法
- **框架基础**: 基于 **Ionic Framework (v8)** 和 **Angular (v19)** 构建，使用 **Capacitor** 作为原生桥接层。
- **样式语言**: 采用 **SCSS** 进行样式开发，遵循 Ionic 的组件化样式结构（每个 Page/Component 拥有独立的 `.scss` 文件）。
- **CSS 方法论**: 
  - **全局样式**: 通过 `src/global.scss` 引入 Ionic 的核心 CSS 工具类（如 padding, flex-utils, typography 等）。
  - **设计令牌 (Design Tokens)**: 深度依赖 **Ionic CSS Variables** 系统。所有颜色、背景、边框等视觉属性均通过 CSS 变量（如 `--ion-color-primary`, `--ion-background-color`）定义，而非硬编码颜色值。
  - **组件库**: 主要使用 Ionic 内置 UI 组件，辅以 **Bootstrap (v5)** 的部分工具类（在 `package.json` 中引入，用于部分布局或辅助样式）。

## 2. 主题与深色模式架构
- **双主题支持**: 实现了完整的 **Light/Dark** 双主题切换机制。
- **实现方式**:
  - **变量定义**: 在 `src/theme/variables.scss` 中定义了 `:root`（浅色默认）和 `body.dark`（深色模式）两套完整的 CSS 变量集。
  - **平台适配**: 针对 iOS (`.ios`) 和 Material Design (`.md`) 分别定义了深色模式下的特定背景色和组件样式（如 Toolbar, Tab Bar, Card 的背景色）。
  - **动态切换服务**: `ThemeService` (`src/app/services/theme/theme.service.ts`) 负责管理主题状态：
    - 支持三种模式：`System` (跟随系统), `Dark` (强制深色), `Light` (强制浅色)。
    - 通过监听 `window.matchMedia("(prefers-color-scheme: dark)")` 实现系统主题变化时的自动响应。
    - 通过切换 `document.body` 上的 `dark` class 来激活深色主题变量。

## 3. 关键文件与目录
- **核心主题配置**:
  - `src/theme/variables.scss`: 定义全局颜色 palette (primary, secondary, success, danger 等) 及深色模式覆盖。
  - `src/global.scss`: 引入 Ionic 基础样式，定义全局辅助类（如二维码扫描时的透明背景处理）。
- **主题逻辑**:
  - `src/app/services/theme/theme.service.ts`: 主题切换业务逻辑。
  - `src/app/enums/appearance-type.ts`: 定义主题类型枚举。
- **组件样式示例**:
  - `src/app/widget-content-components/button-widget/button-widget.component.scss`: 按钮微件的层级样式（background, icon, foreground），使用 `transform` 和 `transition` 实现按压反馈动画。
  - `src/app/pages/deck/widget-grid/widget-grid.component.scss`: 网格布局样式，强调绝对定位与弹性布局结合。

## 4. 开发规范与约定
- **样式隔离**: 优先使用组件级别的 SCSS 文件，避免全局污染。利用 Angular 的 ViewEncapsulation（默认 Emulated）确保样式局部性。
- **响应式与适配**:
  - 使用 Ionic 的栅格系统和 Flexbox 工具类处理布局。
  - 针对移动端特性，使用 `touch-action: none` 等属性优化触摸体验。
  - 使用 `transform: translateZ(0)` 和 `backface-visibility: hidden` 开启硬件加速，提升动画性能。
- **动画规范**:
  - 统一使用 `ease-out` 或 `linear` 过渡效果，时长控制在 `0.1s` - `0.4s` 之间，确保交互流畅且不突兀。
  - 关键交互（如按钮按压）使用 `scale` 变换提供视觉反馈。
- **图标与资源**:
  - 使用 `@mdi/font` (Material Design Icons) 和 `ionicons` 作为主要图标源。
  - 启动页和图标资源统一存放在 `resources/` 目录，并通过 Capacitor/Ionic CLI 同步至原生工程。
- **深色模式开发**:
  - 严禁在组件样式中硬编码颜色值（如 `#ffffff`）。必须使用 CSS 变量（如 `var(--ion-text-color)`）以确保在主题切换时自动适配。
  - 新增页面或组件时，需验证在 `body.dark` 类存在时的视觉表现。