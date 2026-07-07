# API Inquiry Roadmap

Last updated: 2026-07-07

## 中文

### 当前状态

- 最新已发布版本：`v0.3.11`
- 当前主线能力：DeepSeek 余额查询、智谱 GLM Coding Plan 用量查询、Codex/ChatGPT 会话额度查询、Codex 手动重置额度展示与明细页、多供应商菜单栏展示、Console 管理、系统时区自适应时间展示、详情页额度健康色彩提示、克制的 UI 微交互与可访问性补充、质量修复与 CI 基线、DMG 打包发布。
- 下一计划版本：`v0.4.0`，聚焦更多供应商与通用 Provider 能力。

### v0.3.2：中文本地化与语言切换

目标：提供完整汉化版本，并让应用语言既能跟随系统，也能由用户手动切换。

核心功能：

- 默认根据 macOS 系统语言自动适配。
  - 系统语言为中文：显示中文 UI。
  - 系统语言为非中文：显示英文 UI。
- 增加手动语言切换选项：`Auto / 中文 / English`。
- 默认语言选项为 `Auto`，用户手动选择后持久化保存。
- Console 增加语言设置入口，优先放在 Home 页面或轻量 Settings 区域。
- 菜单栏详情页、Console Home、Console API、按钮、状态、错误提示和设置反馈全部支持中英文。
- Provider 品牌名保持原文，例如 `DeepSeek`、`Zhipu GLM Coding Plan`、`OpenAI/Codex`。

实现范围：

- 引入统一本地化资源或轻量 localization layer。
- 抽离当前硬编码 UI 文案，包括菜单栏、Console、API Key 管理、状态、错误和反馈文案。
- 增加语言偏好模型与持久化存储：
  - `AppLanguage.auto`
  - `AppLanguage.zh`
  - `AppLanguage.en`
- `Auto` 模式根据系统 preferred language 选择中文或英文。
- 语言切换后尽量即时生效，不要求用户重启应用。
- 时间格式继续尊重系统 12 小时/24 小时设置。

测试与验收：

- 单测覆盖语言解析与手动覆盖逻辑。
- 单测覆盖关键状态文案：
  - DeepSeek 余额状态
  - 智谱 plan 用量状态
  - Codex 5h/Week 剩余额度状态
  - `Last updated`
  - `Resets`
  - `Plan Next Resets`
- 手动验证中文系统首次启动显示中文、英文系统首次启动显示英文。
- 手动验证切换 `Auto / 中文 / English` 后，菜单栏详情页和 Console 同步更新。
- 语言切换不影响已保存 API Key、Codex 登录态、Provider 添加状态、Primary Provider 和最后一次快照。

不纳入 `v0.3.2`：

- 不新增更多语言。
- 不做 Provider 名称自定义翻译。
- 不改 provider 查询逻辑。
- 不引入本地历史数据存储。
- 不实现历史趋势图表。

### v0.3.7：UI 体验优化（已发布）

目标：保持 API Inquiry 极简、克制、高效、轻科技的整体风格，在不改变核心功能和 Provider 架构的前提下，提升菜单栏与 Console 的顺滑度、扫读效率和可访问性。

核心方向：

- 为刷新、错误出现、状态变化增加克制的反馈动效。
- 修复 UI 中依赖本地化字符串判断状态的脆弱逻辑。
- 统一 warning、success、critical 等状态色在深色/浅色模式下的表达。
- 补充 provider row、quota row、状态 badge、图标按钮的无障碍语义。
- 轻量优化 Console Home 和 Console API 的操作反馈、状态表达和可访问性细节。
- 在 macOS 14+ 使用真实数值驱动的数字变化过渡和设置反馈增强，并保留 macOS 13 fallback。
- 刷新反馈使用 0.8s 前进式旋转循环，刷新结束后自然停止，并尊重 Reduce Motion。

设计边界：

- UI 必须为内容服务；不服务内容的视觉元素应删除或拒绝。
- 不做 dashboard 化、不做重动效、不引入复杂设计系统。
- 不新增供应商，不修改凭据存储或 provider 查询逻辑。
- `MenuBarContentView` 更大范围拆分继续延后，避免在 UI 收尾版本里放大风险。

### v0.3.9：Codex 手动重置额度（已发布）

目标：在不改变菜单栏主刷新链路的前提下，让 Console Home 更完整展示 OpenAI/Codex 账号当前可用的手动重置资源。

核心方向：

- OpenAI/Codex 卡片展示手动重置卡数量和到期信息。
- 手动重置查询优先使用本机 Codex 登录态，使用独立低频缓存，不进入 5 分钟主刷新。
- 指标旁提供独立刷新按钮，并使用查询中、成功、失败的轻量反馈。
- 修复重复刷新后图标速度异常累积的问题。

设计边界：

- 手动重置信息只在 Console Home 展示，不进入 Menubar 展示。
- 不展示 token、cookie、原始响应或完整唯一 ID。

### v0.3.10：手动重置详情与时区自适应（已发布）

目标：在 v0.3.9 的手动重置摘要基础上，补齐详情查看能力，修复发布前评审中优先级最高的问题，并让应用内时间展示跟随当前系统时区。

核心方向：

- Console Home 的 OpenAI/Codex 手动重置摘要可打开详情页，展示所有可用重置卡。
- 手动重置详情中的发放时间和过期时间按当前系统时区显示。
- 应用内刷新时间、重置时间和额度时间统一使用系统时区与 12/24 小时制偏好。
- Console Home 删除“更新于”指标列，为额度与手动重置详情留出更稳定的空间。
- 修复手动重置刷新中的旧结果回写、凭证变化缓存复用、未配置入口暴露和 Codex quota 毫秒字符串解析问题。

设计边界：

- 手动重置详情仍不展示 token、cookie、原始响应或完整唯一 ID。
- 不改变菜单栏主刷新链路；手动重置信息继续独立缓存、独立刷新。

### v0.3.11：质量修复与发布基线（已发布）

目标：在进入 `v0.4.0` Provider 扩展前，先修复评审中确认的高收益质量问题，降低后续扩展风险。

核心方向：

- 增加 GitHub Actions 基线，自动运行 `swift run APIInquiryCoreTestsRunner` 和 `swift build`。
- 将额度窗口的 `"5h"` / `"Week"` 从逻辑判断键收敛为语义枚举，显示文案继续由本地化层负责。
- 将 Codex 手动重置缓存的凭证变化检测从 `String.hashValue` 改为稳定 fingerprint。
- 当本机 Codex `auth.json` 已存在但格式异常或缺少 access token 时，提供非敏感诊断提示。
- 统一 Console API 页反馈通道，避免同一 Provider 下两条反馈叠显。
- 将 Console SwiftUI 内容尺寸与 AppKit 窗口尺寸收敛到单一 token 来源。
- 修复关键浅色模式描边和分隔线对比度。
- 抽取菜单栏刷新与手动重置刷新共用的刷新反馈状态。

设计边界：

- 不新增 Provider。
- 不做完整 Codex auxiliary-feed 架构。
- 不做 `ProviderSnapshot` 展示 adapter 重写。
- 不完整拆分 `MenuBarContentView`。
- 不引入 Sparkle 自动更新、Homebrew Cask 或低余额通知。

### v0.4.0：更多供应商与通用 Provider 能力

- 增加更多内置供应商。
- 抽象更完整的 `balance`、`plan usage`、`quota` 类型。
- 支持供应商排序、隐藏、启用/停用。
- 为未来自定义 endpoint 或 plugin provider 做结构准备。

### v0.5.0：分发体验优化

- 自动更新机制。
- 更完善的首次安装、升级和卸载体验。

### v1.0.0：稳定主版本

- 多供应商、语言切换、菜单栏体验、打包分发都稳定。
- 文档、release、tag 和分支流程固定。
- API Key 管理、安全策略、失败恢复和测试覆盖达到长期维护标准。

## English

### Current Status

- Latest released version: `v0.3.11`
- Current mainline capabilities: DeepSeek balance checks, Zhipu GLM Coding Plan usage checks, Codex/ChatGPT session quota checks, Codex manual reset credit display and details, multi-provider menu bar display, Console management, system-time-zone-aware time display, detail-panel quota health colors, restrained UI microinteractions and accessibility polish, quality fixes with a CI baseline, and DMG release packaging.
- Next planned version: `v0.4.0`, focused on more providers and generic provider capabilities.

### v0.3.2: Chinese Localization and Language Switching

Goal: provide a fully localized Chinese UI while allowing the app language to either follow the system language or be manually selected by the user.

Core features:

- Automatically adapt to the macOS system language by default.
  - Chinese system language: show Chinese UI.
  - Non-Chinese system language: show English UI.
- Add a manual language switcher: `Auto / 中文 / English`.
- Keep `Auto` as the default language option and persist manual user choices.
- Add the language setting in Console, preferably on Home or in a lightweight Settings area.
- Localize the menu details panel, Console Home, Console API, buttons, statuses, errors, and settings feedback.
- Keep provider brand names unchanged, such as `DeepSeek`, `Zhipu GLM Coding Plan`, and `OpenAI/Codex`.

Implementation scope:

- Introduce shared localization resources or a lightweight localization layer.
- Extract current hardcoded UI copy, including menu bar, Console, API key management, status, error, and feedback text.
- Add a language preference model and persistent storage:
  - `AppLanguage.auto`
  - `AppLanguage.zh`
  - `AppLanguage.en`
- In `Auto` mode, resolve Chinese or English from the system preferred language.
- Apply language changes immediately where possible, without requiring an app restart.
- Continue respecting the system 12-hour/24-hour time setting.

Testing and acceptance:

- Unit-test language resolution and manual override behavior.
- Unit-test key localized status text:
  - DeepSeek balance status
  - Zhipu plan usage status
  - Codex 5h/Week remaining quota status
  - `Last updated`
  - `Resets`
  - `Plan Next Resets`
- Manually verify Chinese UI on first launch with a Chinese system language and English UI with a non-Chinese system language.
- Manually verify that switching `Auto / 中文 / English` updates both the menu details panel and Console.
- Confirm language switching does not affect saved API keys, Codex login state, added providers, Primary Provider, or the last snapshots.

Out of scope for `v0.3.2`:

- No additional languages.
- No custom translation for provider names.
- No provider query logic changes.
- No local history data storage.
- No historical trend charts.

### v0.3.7: UI Experience Polish (Released)

Goal: keep API Inquiry minimal, restrained, efficient, and lightly technical while improving the menu bar and Console smoothness, scanability, and accessibility without changing core features or provider architecture.

Core directions:

- Add restrained feedback motion for refresh, error appearance, and state changes.
- Remove fragile UI logic that depends on localized string comparison.
- Unify warning, success, and critical state colors for dark and light modes.
- Add accessibility semantics for provider rows, quota rows, status badges, and icon buttons.
- Lightly improve Console Home and Console API operation feedback, state expression, and accessibility details.
- Use real numeric values for macOS 14+ numeric transitions and settings feedback enhancements while preserving the macOS 13 fallback.
- Make refresh feedback a 0.8s forward-only rotation loop that stops when refresh ends and respects Reduce Motion.

Design boundaries:

- UI must serve the content; visual elements that do not serve content should be removed or rejected.
- No dashboard-style Console, heavy motion, or complex design system.
- No new providers, credential storage changes, or provider query changes.
- Larger `MenuBarContentView` splitting stays deferred to avoid expanding release risk.

### v0.3.9: Codex Manual Reset Credits (Released)

Goal: show the current OpenAI/Codex manual reset resources in Console Home without changing the menu bar's main refresh chain.

Core directions:

- Show manual reset-card count and expiration details on the OpenAI/Codex card.
- Prefer local Codex login state for manual reset checks, use a separate low-frequency cache, and keep it out of the 5-minute main refresh.
- Provide an independent refresh button next to the metric with lightweight in-progress, success, and failure feedback.
- Fix refresh icons accumulating rotation speed across repeated refreshes.

Design boundaries:

- Manual reset information appears only in Console Home, not in the menu bar.
- Do not display tokens, cookies, raw responses, or full unique IDs.

### v0.3.10: Manual Reset Details and Time Zone Adaptation (Released)

Goal: extend the v0.3.9 manual reset summary with a detail view, fix the highest-priority release review issues, and make in-app time display follow the current system time zone.

Core directions:

- Open the full manual reset card list from the OpenAI/Codex summary in Console Home.
- Show manual reset granted and expiration times in the current system time zone.
- Make refresh, reset, and quota times consistently follow system time zone and 12-hour/24-hour preferences.
- Remove the last-updated metric column from Console Home so quota and manual reset details have more stable space.
- Fix stale manual reset refresh writes, credential-scoped cache reuse, unconfigured Codex detail entry exposure, and Codex quota millisecond-string reset parsing.

Design boundaries:

- Manual reset details still do not display tokens, cookies, raw responses, or full unique IDs.
- Do not change the menu bar's main refresh chain; manual reset information remains independently cached and refreshed.

### v0.3.11: Quality Fixes and Release Baseline (Released)

Goal: fix the highest-leverage quality issues confirmed by review before entering the `v0.4.0` provider expansion, reducing risk for later extensibility work.

Core directions:

- Add a GitHub Actions baseline that runs `swift run APIInquiryCoreTestsRunner` and `swift build`.
- Move quota-window `"5h"` / `"Week"` logic from display labels to semantic enum values, keeping copy in the localization layer.
- Replace `String.hashValue` credential-change tracking in Codex manual-reset cache with a stable fingerprint.
- Provide a non-sensitive diagnostic warning when local Codex `auth.json` exists but is malformed or missing an access token.
- Unify Console API feedback so one provider cannot show stacked feedback messages.
- Use a single token source for the Console SwiftUI content size and AppKit window size.
- Fix key light-mode stroke and separator contrast issues.
- Extract shared refresh feedback state for menu refresh and manual-reset refresh.

Design boundaries:

- No new providers.
- No full Codex auxiliary-feed architecture.
- No `ProviderSnapshot` display-adapter rewrite.
- No full `MenuBarContentView` split.
- No Sparkle automatic updates, Homebrew Cask, or low-balance notifications.

### v0.4.0: More Providers and Generic Provider Capabilities

- Add more built-in providers.
- Further generalize `balance`, `plan usage`, and `quota` detail types.
- Support provider ordering, hiding, enabling, and disabling.
- Prepare the structure for future custom endpoints or plugin providers.

### v0.5.0: Distribution Experience Polish

- Automatic updates.
- Better first-install, upgrade, and uninstall flows.

### v1.0.0: Stable Major Version

- Multi-provider support, language switching, menu bar experience, and release packaging are stable.
- Documentation, release, tag, and branch workflows are fixed.
- API key management, security policy, failure recovery, and test coverage are ready for long-term maintenance.
