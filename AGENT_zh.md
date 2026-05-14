# Agent 指令

## 项目背景

API Inquiry 是一个原生 macOS 菜单栏应用，用于查询 DeepSeek API 账号余额。第一版只做余额监控：在菜单栏显示余额，每 5 分钟刷新，支持手动刷新，并将 DeepSeek API Key 存储在 macOS Keychain 中。

实现前先阅读已确认文档：

- 设计 spec：`docs/superpowers/specs/2026-05-14-deepseek-menu-bar-balance-design_zh.md`
- 实现计划：`docs/superpowers/plans/2026-05-14-deepseek-menu-bar-balance_zh.md`
- 文档约定：`docs/superpowers/documentation-conventions_zh.md`

## 语言与文档

- 面向用户的对话通常使用中文。
- 重要规划类文档必须维护英文和中文双版本。
- 英文源文件使用 `<name>.md`。
- 中文版本使用 `<name>_zh.md`。
- 任一版本发生内容修改时，必须同步更新另一版本。
- 对话为中文时，优先请用户审阅中文版本。

## 技术方向

- 平台：macOS 13 Ventura 及以上。
- 应用形态：原生 macOS 菜单栏应用。
- UI：SwiftUI `MenuBarExtra`。
- Core package：Swift Package Manager。
- 网络：`URLSession`，放在可注入 HTTP client 后面。
- 安全存储：macOS Keychain。
- 测试：本地 Swift 可执行 runner `APIInquiryCoreTestsRunner`，只使用假 API Key。

## 安全规则

- 永远不要提交、记录、打印或展示真实 DeepSeek API Key。
- API Key 只在用户输入或更换时可见。
- 保存后，UI 只能显示已配置、更换和删除状态。
- API Key 只能存储在 macOS Keychain，不能存到 UserDefaults、明文文件、测试 fixture、截图或日志。
- 自动化测试必须使用假 key 和 mock 网络响应。

## 范围边界

第一版包含：

- 通过 `GET https://api.deepseek.com/user/balance` 查询 DeepSeek 余额。
- 基于动态渲染的 DeepSeek template 图像加 `¥68.6` 这类紧凑数值的菜单栏标签。
- 极简展开面板：自适应黑/白 DeepSeek logo、余额、状态、最近刷新时间、刷新按钮、控制台链接、设置和退出。
- 为未来 API 供应商预留 provider 抽象。

第一版不包含：

- 月度用量图表。
- DeepSeek 网页控制台抓取或自动化。
- 多供应商 UI。
- 本地 DeepSeek 用量控制台。
- 打包、签名、公证和分发。

## 开发流程

- 不要直接在 `master` 上实现。
- 实现工作使用独立 git worktree。
- 按实现计划逐任务执行。
- 行为变更使用 TDD：先写失败测试，确认失败，再写最小实现，最后确认通过。
- 每个任务完成后提交一次。
- 每个任务之后先做 spec compliance review，再做 code quality review，之后才能进入下一任务。
- 声称完成前必须运行新的验证命令，并报告真实证据。

## 本地命令

实现开始后的预期命令：

```bash
swift run APIInquiryCoreTestsRunner
swift build
Scripts/build-local-app.sh
```

手动验证时启动应用可能需要：

```bash
open .build/APIInquiry.app
```
