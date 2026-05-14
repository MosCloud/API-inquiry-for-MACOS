# API Inquiry

API Inquiry 是一个原生 macOS 菜单栏应用，用于查询 DeepSeek API 账号余额。第一版刻意保持极简：只保存一个 DeepSeek API Key 到 macOS Keychain，每 5 分钟自动刷新官方余额 API，支持手动刷新，并在菜单栏显示当前余额。

## 运行要求

- macOS 13 或更高版本
- Swift 5.9+ / Xcode Command Line Tools
- 用于真实余额查询的 DeepSeek API Key

## 安全说明

- API Key 只通过 `KeychainCredentialStore` 存储在 macOS Keychain 中。
- 保存后不会再明文展示已保存的 key。界面默认只显示 `Configured`；只有展开 API Key 行后，才显示输入框、`Replace` 和 `Delete` 控件。
- 测试只使用假 key，不需要真实 DeepSeek 账号。
- 不要把真实 API Key 写进源码、文档、日志、截图或 shell history。

## 测试

本项目使用本地可执行测试 runner，因为当前开发机只有 Command Line Tools，没有完整 XCTest 运行环境。

```bash
swift run APIInquiryCoreTestsRunner
```

预期结果：

```text
PASS: 54 expectations
```

## 构建

编译所有 package target：

```bash
swift build
```

构建本地 macOS app bundle：

```bash
Scripts/build-local-app.sh
```

脚本会生成：

```text
.build/APIInquiry.app
```

生成的 `Info.plist` 设置了 `LSUIElement=true`，因此应用会以菜单栏 accessory app 形式运行。

## 本地运行

```bash
open .build/APIInquiry.app
```

手动检查项：

- 首次启动且没有 key 时显示 setup 状态。
- 保存 key 后清空输入框，并将 key 存入 Keychain。
- key 已配置后，API Key 行默认折叠，展开后才显示更换和删除控件。
- 菜单栏使用动态 DeepSeek template 标签加紧凑余额格式，例如 `¥68.6`。
- 展开面板 logo 会自动适配浅色和深色外观。
- 面板使用完整余额格式，例如 `¥68.65 CNY`。
- 手动刷新与自动刷新使用同一条刷新路径。
- 删除 key 后回到 setup 状态。

## 范围

本版本包含：

- DeepSeek 余额 API 集成
- 安全 Keychain 存储
- 每 5 分钟自动刷新和手动刷新
- 极简原生 `MenuBarExtra` UI
- 本地 `.app` bundle 生成

延后处理：

- 详细用量图表
- 本地 DeepSeek 用量控制台
- 多供应商 UI
