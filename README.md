# API Inquiry

[English](README_en.md) · [简体中文](README.md)

一个原生 macOS 菜单栏应用，用来看清你手上几个 AI 编码服务还剩多少额度。它待在你的菜单栏里，每 5 分钟刷新一次，需要改配置时才打开一个轻量控制台。

支持 **DeepSeek**、**智谱 GLM Coding Plan**、**Codex**、**OpenCode** 和 **WorkBuddy**。

## 功能

- **菜单栏常驻**：显示你选定的 Primary Provider，点开是全部供应商的概览。
- **五家供应商**：余额、套餐用量、配额窗口各有各的展示方式，不是硬塞进一个模板。
- **凭证各归各家**：App 自己管的密钥进 macOS 密钥串；Codex、OpenCode、WorkBuddy 的登录态由各自的 CLI 或桌面端持有，App 只读不写。
- **中英双语**：默认跟随系统语言，也可以在 Console 里手动切换。
- **五家之外不加东西**：不做数据分析面板，不做历史曲线。

## 支持的供应商

| 供应商 | 展示内容 | 凭证来源 |
|---|---|---|
| **DeepSeek** | 账户余额，赠送与充值分开 | macOS 密钥串 |
| **智谱 GLM Coding Plan** | 套餐用量与重置时间 | macOS 密钥串 |
| **Codex** | 会话额度（5 小时 / 每周） | 本机 Codex 登录态，只读 |
| **OpenCode** | 用量窗口（5 小时 / 每周 / 每月） | 本机 OpenCode 数据库，只读 |
| **WorkBuddy** | 剩余积分，含下次刷新与最近到期 | 本机 WorkBuddy 桌面端登录态，只读 |

WorkBuddy 目前只支持国内版（`www.codebuddy.cn`），国际版尚未接入。

## 安装

从 [GitHub Releases](https://github.com/MosCloud/API-inquiry-for-MACOS/releases) 下载最新的 DMG 和校验文件。

```bash
shasum -a 256 -c API-Inquiry-vX.Y.Z.dmg.sha256
```

打开 DMG，把 `API Inquiry.app` 拖进「应用程序」，然后从那里启动。

**首次打开可能被拦下**：本项目没有 Apple 公证。右键点击 App 选「打开」，或到「系统设置 → 隐私与安全性」里允许。

**首次启动会请求密钥串访问**：这是读取你自己保存的 API 密钥，点「始终允许」即可。之后每次重新构建本地副本都会再问一次，因为 ad-hoc 签名变了。

## 使用

### 菜单栏

点开面板，顶部是 Primary Provider，下面按行列出其他已添加的供应商。刷新按钮会一次性刷新全部。

### 控制台

| 页面 | 管什么 |
|---|---|
| **Home** | 选谁上菜单栏（Primary Provider），看各家状态 |
| **API** | 填密钥、看凭证状态、打开本地配置文件 |
| **设置** | 开机自启、语言、版本信息 |

**Codex、OpenCode、WorkBuddy 没有「填密钥」这一步**：它们的凭证属于各自的 CLI 或桌面端，App 只负责读取。想换账号，去对应的工具里换。

## 开发

### 环境要求

- macOS 13 或更高版本
- **Xcode**（不只是 Command Line Tools）——编译 `APIInquiryApp` 需要它解析 SwiftUI 宏
- 纯 Core 工作和跑测试用 Command Line Tools 就够

### 构建

```bash
Scripts/build-local-app.sh      # 构建 .build/APIInquiry.app
Scripts/run-local-app.sh        # 构建并启动
```

这两个脚本会自己挑 Xcode 的 developer directory，不需要手动设 `DEVELOPER_DIR`。

如果你要直接跑 `swift build`，得自己带上前缀，否则会看到一堆 `SwiftUIMacros not found`：

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
```

### 测试

本项目**没有使用 XCTest**，也不是因为机器缺什么——`Package.swift` 里根本没有 `testTarget`。测试是一个普通的可执行 runner：

```bash
swift run APIInquiryCoreTestsRunner
```

成功的输出形如：

```text
PASS: N expectations
```

`N` 会随测试增减变化，以实际输出为准。runner 是全有或全无的，任何一条失败都会以非零码退出。

### 一次验证全部

```bash
Scripts/verify.sh
```

测试加 app 构建，是提交 PR 前的门槛。

### 并排跑一个开发副本

```bash
Scripts/run-dev-app.sh
```

它会在 `/private/tmp` 下准备一份独立的 `APIInquiryDevelopment` 副本并启动，不碰你正在用的那个。副本有自己的偏好设置域，但共用同一个密钥串服务。

想用假数据看界面（不触网、不弹钥匙串）：

```bash
Scripts/run-dev-app.sh --fixtures multi
```

退出副本：`pkill -x APIInquiryDevelopment`

### 发版

```bash
Scripts/package-mac-app.sh    # → dist/API Inquiry.app
Scripts/package-dmg.sh        # → dist/API-Inquiry-vX.Y.Z.dmg + .sha256
```

版本号在 `Scripts/version.env` 里统一维护。完整清单和常见故障见 [docs/release-runbook_zh.md](docs/release-runbook_zh.md)。

## 文档

| 文档 | 内容 |
|---|---|
| [docs/repository-layout_zh.md](docs/repository-layout_zh.md) | 文件该放哪 |
| [docs/provider-onboarding_zh.md](docs/provider-onboarding_zh.md) | 怎么加一个新供应商 |
| [docs/release-runbook_zh.md](docs/release-runbook_zh.md) | 发版流程与故障排查 |
| [docs/release-writing_zh.md](docs/release-writing_zh.md) | 发布说明与 CHANGELOG 怎么写 |
| [CHANGELOG_zh.md](CHANGELOG_zh.md) | 完整版本变更记录 |
| [AGENTS.md](AGENTS.md) | 本仓库的协作约定（给 agent 看的） |

## 已知限制

- 没有 Apple 公证，首次打开需要手动允许。
- Codex、OpenCode、WorkBuddy 的用量依赖各自工具的登录状态；它们过期就得去那边重新登录。
- WorkBuddy 只支持国内版。
- 只能从内置的五家供应商里选，不支持自定义供应商。

## 许可证

[MIT](LICENSE)。

第三方品牌素材与商标声明见 [THIRD-PARTY.md](THIRD-PARTY.md)。DeepSeek、智谱、OpenAI、OpenCode、WorkBuddy 的名称与标识属于各自权利人，本项目仅用于标识所连接的供应商，不代表任何隶属或背书关系。

## 致谢

感谢这些工具和项目：Swift 与 SwiftUI、[OpenCode](https://github.com/anomalyco/opencode)（其公开的品牌素材为 MIT），以及每一个愿意在菜单栏里给额度留一格的人。
