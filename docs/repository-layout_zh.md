# 仓库结构

说明每类文件放在哪，以及新文件应该放哪。结构变化时同步更新本页；中英配对为
`docs/repository-layout.md` / `_zh.md`。

```text
AGENTS.md                  agent 约定
AGENT.md / AGENT_zh.md     跳转 stub，仅为老计划里的链接保留
README.md                  中文说明（正本）；README_en.md 是英文版
Package.swift              SwiftPM 清单：一个 library + 两个 executable
Scripts/                   可执行工具，见 Scripts/README.md
Sources/
  APIInquiryCore/          全部逻辑，不含 UI；子目录按领域划分，测试与之同层
  APIInquiryApp/           SwiftUI + AppKit，按界面分组：
    App/                   入口、生命周期、App 级支撑
    MenuBar/               菜单栏面板
    Console/               本地控制台窗口
    Providers/             供应商 logo、徽标、视觉目录
    Resources/             打包进 app 的图片；保留此路径——generate-app-icon.swift 会读它
  APIInquiryCoreTestsRunner/  自定义测试 runner（无 XCTest target）
docs/
  release-runbook*.md      发布流程，中英配对
  roadmap.md               能力与近期计划
  releases/                每个版本的发布说明
  superpowers/             历史计划与规格（冻结，链接仍指向这里）
  assets/                  README 引用的截图（raw.githubusercontent 固定路径）
.github/workflows/         CI，仅在 release/* tag 上运行
dist/ .build/ .worktrees/  生成物，已忽略
CLAUDE.md docs/agents/ docs/reviews/  本地笔记，按设计不入库
```

## 新文件放哪

- **Core 逻辑** → `Sources/APIInquiryCore/<领域>/`，不要放进 App target。
- **视图** → 按界面归位：`MenuBar/`、`Console/`，App 级共用件放 `App/`。
- **供应商素材** → `Sources/APIInquiryApp/Resources/`，命名 `<id>-logo-header` /
  `<id>-menu-icon-template`，并在 `ProviderVisualCatalog` 补对应条目。
- **脚本** → `Scripts/`，按阶段前缀命名（`build-`/`package-`/`install-`），并在
  `Scripts/README.md` 补一行。
- **文档** → `docs/`。发布流程改 runbook 中英两份；新设计文档放 `docs/superpowers/specs/`。
- **本地笔记** → `CLAUDE.md`、`docs/agents/`、`docs/reviews/`；它们不入库，可能滞后于代码。

## 为什么不再细分或改名

脚本名已自带阶段前缀，再分目录要改约 45 处引用却没有功能收益。`docs/superpowers/`
有约 67 个互链的历史文件，改名会让链接全断。`docs/assets/` 的路径写死在 README 的
`raw.githubusercontent.com` 图片地址里，移动会破坏已发布的页面。
