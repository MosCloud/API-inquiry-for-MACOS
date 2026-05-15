# macOS 打包与登录启动实现计划

> **给 agentic workers：** 必须使用子技能：使用 superpowers:executing-plans 按任务逐项执行本计划。步骤使用复选框 (`- [ ]`) 语法追踪。

**目标：** 将 API Inquiry 从开发态 `.build` app 升级为可长期使用的本地 macOS app 包，并为后续安装与登录启动打下稳定路径基础。

**架构：** 新增 release 打包脚本，构建 `APIInquiryApp`，组装标准 `dist/API Inquiry.app` bundle，将图片资源复制到 `Contents/Resources`，校验 `Info.plist`，并使用 ad-hoc 签名。现有 `.build/APIInquiry.app` 开发构建脚本继续保留，用于快速本地调试。

**技术栈：** Swift Package Manager、Bash、macOS app bundle 结构、`plutil`、ad-hoc `codesign`。

---

## 任务

### 任务 1：正式本地 App 打包

**文件：**
- 创建：`Scripts/package-mac-app.sh`
- 修改：`.gitignore`
- 修改：`README.md`
- 修改：`README_zh.md`

- [x] 先做红灯检查，确认 `Scripts/package-mac-app.sh` 和 `dist/API Inquiry.app` 当前不存在。
- [x] 创建 `Scripts/package-mac-app.sh`，从 release SwiftPM 构建生成 `dist/API Inquiry.app`。
- [x] 将 `Scripts/package-mac-app.sh` 标记为可执行。
- [x] 运行 `bash -n Scripts/package-mac-app.sh`。
- [x] 运行 `Scripts/package-mac-app.sh`。
- [x] 修复 strict 签名失败：正式 app 根目录只保留 `Contents/`，图片从 `Contents/Resources` 加载。
- [x] 验证 `dist/API Inquiry.app/Contents/Info.plist` 合法。
- [x] 验证 app binary 位于 `dist/API Inquiry.app/Contents/MacOS/APIInquiry`。
- [x] 验证 DeepSeek PNG 资源位于 `dist/API Inquiry.app/Contents/Resources`。
- [x] 使用 `codesign --verify --deep "dist/API Inquiry.app"` 验证 ad-hoc 签名。
- [x] 更新英文和中文 README 使用说明。
- [x] 运行 `swift run APIInquiryCoreTestsRunner` 和 `swift build`。
- [x] 提交并推送打包变更。

### 任务 2：安装后的 App 路径

**文件：**
- 创建：`Scripts/install-mac-app.sh`
- 创建：`Scripts/restart-installed-app.sh`
- 修改：`README.md`
- 修改：`README_zh.md`

- [x] 创建 `Scripts/install-mac-app.sh`，用于构建、打包、复制并验证 `~/Applications/API Inquiry.app`。
- [x] 创建 `Scripts/restart-installed-app.sh`，用于停止正在运行的 `APIInquiry` 进程并启动安装后的 app。
- [x] 将 `dist/API Inquiry.app` 安装到 `~/Applications/API Inquiry.app`。
- [x] 从 `~/Applications/API Inquiry.app` 重启应用。
- [x] 验证运行进程路径位于 `~/Applications` 下。

### 任务 3：登录启动

**文件：**
- 创建：`Sources/APIInquiryApp/LaunchAtLoginController.swift`
- 修改：`Sources/APIInquiryApp/MenuBarContentView.swift`
- 修改：`README.md`
- 修改：`README_zh.md`

- [ ] 增加 `SMAppService.mainApp` wrapper，负责状态读取、注册和取消注册。
- [ ] 在详情面板中增加紧凑的 `Launch at Login` 开关。
- [ ] 基于已安装 app 包验证开关行为。
