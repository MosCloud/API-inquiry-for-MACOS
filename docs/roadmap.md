# API Inquiry Roadmap

Last updated: 2026-05-29

## 中文

### 当前状态

- 最新已发布版本：`v0.3.6`
- 当前主线能力：DeepSeek 余额查询、智谱 GLM Coding Plan 用量查询、Codex/ChatGPT 会话额度查询、多供应商菜单栏展示、Console 管理、详情页额度健康色彩提示、DMG 打包发布。
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

- Latest released version: `v0.3.6`
- Current mainline capabilities: DeepSeek balance checks, Zhipu GLM Coding Plan usage checks, Codex/ChatGPT session quota checks, multi-provider menu bar display, Console management, detail-panel quota health colors, and DMG release packaging.
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
