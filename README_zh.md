# API Inquiry

[English](README_en.md)

API Inquiry 是一个原生 macOS 菜单栏应用，用于查看 API 供应商状态并管理供应商 API Key。它支持 DeepSeek 余额查询、智谱 GLM Coding Plan 用量查询和 Codex/ChatGPT 会话额度查询，会将供应商 API Key 保存到 macOS Keychain，每 5 分钟刷新已配置供应商，在菜单栏显示 Primary Provider，并提供一个轻量本地控制台用于供应商管理。

## 运行要求

- macOS 13 或更高版本
- Swift 5.9+ / Xcode Command Line Tools
- 用于真实余额查询的 DeepSeek API Key，或用于 plan 用量查询的智谱 GLM Coding Plan API Key
- 如需查询 Codex 额度，本机需要已通过 Codex 登录，生成 `$CODEX_HOME/auth.json` 或 `~/.codex/auth.json`

## 安全说明

- API Key 只通过 `KeychainCredentialStore` 存储在 macOS Keychain 中。
- Codex provider 优先只读本机 Codex auth 文件，不修改、不删除，也不会复制到 UserDefaults；Keychain 仅作为手工 fallback。
- 保存后不会再明文展示已保存的 key。API Key 的配置、更换和删除都在本地控制台中完成。
- 测试只使用假 key，不需要真实 DeepSeek、智谱或 Codex 账号。
- 不要把真实 API Key、Codex access token、session token 或 account id 写进源码、文档、日志、截图或 shell history。

## 测试

本项目使用本地可执行测试 runner，因为当前开发机只有 Command Line Tools，没有完整 XCTest 运行环境。

```bash
swift run APIInquiryCoreTestsRunner
```

预期结果：

```text
PASS: 250 expectations
```

## 构建

编译所有 package target：

```bash
swift build
```

重新生成随 app 打包的 macOS 应用图标：

```bash
swift Scripts/generate-app-icon.swift
```

构建本地 macOS app bundle：

```bash
Scripts/build-local-app.sh
```

构建并启动本地 macOS app bundle，用于快速验证：

```bash
Scripts/run-local-app.sh
```

开发过程态优先使用该脚本进行快速本地验证。完整 .app release 打包和 DMG 生成只在 release candidate 验证阶段执行。

脚本会生成：

```text
.build/APIInquiry.app
```

应用会在启动时设置 accessory activation policy，因此既能以菜单栏工具形式运行，也能在安装 DMG 中保持可见。
构建脚本会自动重新生成并打包自定义 `AppIcon.icns`。

打包 release macOS app bundle：

```bash
Scripts/package-mac-app.sh
```

脚本会生成并进行 ad-hoc 签名：

```text
dist/API Inquiry.app
```

打包 GitHub Release 用 DMG：

```bash
Scripts/package-dmg.sh
```

脚本会生成：

```text
dist/API-Inquiry-v0.3.1.dmg
dist/API-Inquiry-v0.3.1.dmg.sha256
```

完成发布验证和上传后，删除本机开发态 app bundle，避免 Launchpad 将非正式副本索引成重复图标：

```bash
Scripts/clean-development-apps.sh
```

## 通过 GitHub DMG 安装

本项目采用免费的 GitHub Releases 发布策略。DMG 中的 app 已进行 ad-hoc 签名，但没有 Apple notarization 公证。

1. 从 GitHub Releases 下载 `API-Inquiry-v0.3.1.dmg` 和 `API-Inquiry-v0.3.1.dmg.sha256`。
2. 校验下载文件：

   ```bash
   shasum -a 256 -c API-Inquiry-v0.3.1.dmg.sha256
   ```

3. 打开 DMG。
4. 将 `API Inquiry.app` 拖入 `Applications`。
5. 从 Applications 启动 API Inquiry。

如果 macOS 首次启动时提示无法验证开发者：

1. 右键点击 `API Inquiry.app`。
2. 选择 `Open`。
3. 在系统提示中再次确认 `Open`。

也可以进入 `System Settings > Privacy & Security`，允许该应用打开。

## 本地运行

```bash
Scripts/run-local-app.sh
```

直接打开已有的本地 app bundle：

```bash
open .build/APIInquiry.app
```

运行打包后的 release app：

```bash
open "dist/API Inquiry.app"
```

将打包后的 app 安装到当前用户的 Applications 目录：

```bash
Scripts/install-mac-app.sh
```

重启安装后的 app：

```bash
Scripts/restart-installed-app.sh
```

安装后的 app 路径为：

```text
~/Applications/API Inquiry.app
```

手动检查项：

- 首次启动且没有 key 时显示 setup 状态。
- 没有配置 key 时，菜单栏面板会引导打开本地控制台。
- 从控制台保存 key 后清空输入框，并将 key 存入 Keychain。
- key 已配置后，控制台只显示 `Configured`，不会展示已保存 key。
- 菜单栏使用动态 DeepSeek template 标签加紧凑余额格式，例如 `¥68.6`。
- 菜单栏图标大于金额文字，贴近常见 macOS 状态栏项目比例；金额使用 regular 字重，让标签保持轻盈。
- 展开面板 logo 会自动适配浅色和深色外观。
- 面板使用完整余额格式，例如 `¥68.65 CNY`，顶部 logo 进一步缩小，数字部分使用 medium 字重占据视觉主导，货币符号和货币代码以更小的 regular 字重显示。
- 安装后的 app 使用来自 `AppIcon.icns` 的自定义苹果风格图标。
- 详情面板右上角以一致的图标按钮展示 `Console` 和刷新。
- 底部显示两个等宽操作模块：`AutoStart` 和 `Quit`。
- 控制台 Home 页面展示供应商 API Key 状态、生效状态和余额。
- 控制台 API 页面管理已配置供应商的 API Key。
- Console 中的供应商名称会打开对应 API 页面；DeepSeek 打开 `https://platform.deepseek.com/usage`。
- `AutoStart` 操作用于切换开机自启，启用后模块颜色会变化。
- 最近更新时间会跟随系统的 12 小时制或 24 小时制设置。
- 手动刷新与自动刷新使用同一条刷新路径。
- 从控制台删除 key 后回到 setup 状态。
- 菜单栏只显示 Primary Provider 详情：DeepSeek 显示紧凑余额，例如 `¥68.6`；智谱 GLM Coding Plan 显示用量，例如 `5h 17%`。
- Codex 作为 Primary Provider 时，菜单栏显示 ChatGPT/GPT 标识加 `5h xx%` 剩余额度。
- Codex 详情页展示 5h 和 Week 两个剩余额度窗口，并在 Console Home 展示当前 plan。
- Codex 优先自动读取本机 Codex 登录态；无需在 Console 手工输入 OpenAI Platform API key。
- 展开面板顶部突出展示 Primary Provider，其余供应商以紧凑行展示。
- 展开面板中的刷新按钮会刷新所有已添加供应商。
- 智谱 GLM Coding Plan 会在展开面板显示 `Resets`，并在 Console Home 显示 `Plan Next Resets`。
- Console 可添加智谱 GLM Coding Plan 和 Codex，并将某个供应商设为菜单栏 Primary Provider。
- 从控制台删除某个供应商 key 不影响其他供应商 key 和快照。

## 范围

本版本包含：

- DeepSeek 余额 API 集成
- 智谱 GLM Coding Plan 用量集成
- Codex/ChatGPT 会话额度查询，包含 5h 和 Week 剩余额度
- Codex 当前 plan 展示
- 内置多供应商目录
- 每供应商独立的安全 Keychain 存储
- 每 5 分钟自动刷新和手动刷新
- 面向 Primary Provider 的极简原生 `MenuBarExtra` 状态 UI
- 本地 API Inquiry 控制台窗口
- 本地 API 供应商控制台，包含 Home 和 API 页面
- 供应商状态总览，包括 API Key、生效状态、余额和 plan 用量状态
- 面向 coding-plan 供应商的 plan 重置时间展示
- 本地 `.app` bundle 生成
- 自定义 macOS 应用图标生成与打包
- 详情面板中的开机自启控制
- 不使用 Apple 公证的免费 GitHub DMG 打包

延后处理：

- 历史用量导入和图表
- 任意自定义供应商
- Developer ID 签名和 Apple notarization 公证

## 路线图

- 最新已发布版本：`v0.3.1`
- 下一计划版本：`v0.3.2`，提供中文本地化、系统语言自动适配，以及 `Auto / 中文 / English` 手动语言切换。
- 后续方向：历史用量与趋势、更多供应商、正式签名公证和自动更新。

详细计划见 [docs/roadmap.md](docs/roadmap.md)。
