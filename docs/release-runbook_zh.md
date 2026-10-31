# 发布操作手册（Release Runbook）

这里是 API Inquiry 发版的实操笔记，来源于 v0.3.16 那次发布——当时两个打包缺陷导致 DMG 里的 app 丢了图标、安装窗口变成默认样式。英文版见 [release-runbook.md](release-runbook.md)。

## 0. 版本号

- 已发布版本以 tag `release/vX.Y.Z` 标记，Release 标题为 `API Inquiry vX.Y.Z`。
- `v0.3.16` 属于**复用**：`0.3.16`–`0.3.20` 是 2026-10-13 撤回的 Anthropic 版本。当前 `release/v0.3.16` 是 Codex Credits 显示修复，build 21。
- 升级版本号前先确认号码空闲：`git ls-remote --tags origin 'release/vX.Y.Z'`，以及 `gh api repos/MosCloud/API-inquiry-for-MACOS/releases/tags/release/vX.Y.Z`（404 表示可用）。

## 1. 版本号同步清单

以下位置必须完全一致，否则 `ReleaseVersionConsistencyTests` 会失败：

- `Scripts/version.env`：`APP_VERSION`、`BUILD_NUMBER`、`RELEASE_TAG`、`RELEASE_VERSION`、`DMG_BASENAME`、`VOLUME_NAME`
- `Sources/APIInquiryApp/App/AppVersion.swift`（`vX.Y.Z`）
- `Sources/APIInquiryCoreTestsRunner/ReleaseVersionConsistencyTests.swift`（版本、tag、dmg 名、卷名、build 号）
- `README.md`、`README_en.md`（DMG 文件名示例、「最新已发布版本」）
- `docs/roadmap.md`（日期、最新版本、能力摘要，中英双语）
- `AGENTS.md`（当前版本那句）
- 新建 `docs/releases/vX.Y.Z_github.md`，中英双语、只保留非空章节：New Features / App Optimization / Bug Fixes，再加下载校验与已知限制。

## 2. 构建环境

- **打包请用 Xcode 工具链。** 本机 Command Line Tools 的 SDK 无法解析 SwiftUI 宏，没有 Xcode 工具链时 Release 编译会失败。`Scripts/package-mac-app.sh` 会在 `DEVELOPER_DIR` 未设置时自动选用 `/Applications/Xcode.app/Contents/Developer`，找不到 Xcode 时直接报可读错误退出；要换用别的 Xcode 就显式设置 `DEVELOPER_DIR`。
- **SwiftPM 现在的默认构建系统是 Xcode 那套。** 产物落在 `.build/out/Products/<Configuration>/`，`.build/<configuration>` 是指向它的符号链接；资源包变成 macOS bundle（`APIInquiry_APIInquiryApp.bundle/Contents/Resources/*.png|icns`），**不是**老版本那种扁平结构。打包脚本必须递归搜索，不能假设 `maxdepth 1`。
- **让脚本把 SDK 传给链接器。** SwiftPM 的默认构建系统会把 `LC_BUILD_VERSION sdk` 记成部署目标（13.0），这等于让 app 退出 macOS 26 新设计：Console 的「添加供应商」会变成整条旧式弹出按钮（宽灰条 + 蓝箭头），菜单栏面板也退回旧窗口外观。`Scripts/lib/toolchain.sh` 会传 `-Xlinker -platform_version macos 13.0 <当前 SDK>`，两个 app 脚本因此记录真实 SDK（26.x/27.x），与 v0.3.15 一致。两个脚本已自动断言这一点（低于 `sdk 20` 直接失败）；裸 `swift build` 的产物仍需手动用 `otool -l "…/MacOS/APIInquiry" | grep -A4 LC_BUILD_VERSION` 检查（健康：`sdk 26.x`/`27.x`，坏：`sdk 13.0`）。
- **验收或发布构建绝不能带入兼容或测试用的 `SDKROOT`。** 脚本会自行解析当前 SDK，只有 `API_INQUIRY_APP_SDKROOT` 可以有意覆盖。可用 `xcrun vtool -show-build` 直接检查可执行文件本身（应显示当前 macOS SDK），而不是只看 bundle 的签名。
- **SwiftPM 自带沙箱**，在受限的 agent 沙箱里会失败并报 `sandbox-exec: sandbox_apply: Operation not permitted`。用 `--disable-sandbox`，或直接给完整文件权限。`hdiutil`（创建/挂载 DMG）同样需要完整权限。
- **Keychain 用例**（保存/替换/删除凭据）在钥匙串不可达时会以 `unexpectedStatus(100001)` 失败。这是环境限制而非回归：要拿到 `PASS: N expectations`，必须在沙箱外跑；否则预期正好这三条红。
- 仓库位于 `Desktop`，FileProvider/Finder 会在文件写入后几秒补上元数据。任何在该路径上签名的产物，严格验签前都要先 `xattr -cr`。因此本地运行会把签好的 app 放在 `/private/tmp`，`.build/APIInquiry.app` 只作为入口符号链接；签名当场通过、过一会儿却失败，必须等到 DMG 里的 app 通过严格验签才算解决。

## 3. 打包流水线

`Scripts/package-mac-app.sh`

1. 生成 app 图标、构建 `release` 产物、清理 staging app、写 `Info.plist`、ad-hoc 签名、验签。
2. 从 SwiftPM 资源包**任意层级**复制 `*.png` / `*.icns` 到 `Contents/Resources`；若 `AppIcon.icns` 没到位直接失败退出。
3. 用 `ditto` 把 staging app 复制到 `dist/`，先 `xattr -cr` 清掉 FileProvider 元数据，再验签一次。

`Scripts/package-dmg.sh`

1. 先调用上面的脚本产出 app。
2. 在 `/private/tmp` 建可写 HFS+ 镜像、挂载、拷入 app 与 `Applications` 软链、隐藏 `.background/dmg-background.png`。
3. 驱动 Finder：**激活 Finder → 打开窗口 → 等窗口真正出现 → 设置视图选项（背景图、152pt 图标、不自动排列、窗口 `{160,160,920,580}`、图标位置 `{210,180}` / `{550,180}`）→ `update` 强制刷新。**
4. 轮询 staging 卷的 `.DS_Store`，直到出现 `dmg-background.png` 别名，超时即失败；之后才关窗、`sync`、卸载。
5. 转成 UDZO、`hdiutil verify`、再只读挂载最终 DMG，断言：app 存在且未隐藏、可执行文件存在、bundle id、版本、build、`Applications` 软链、`.DS_Store` 含背景别名。最后写 `.sha256`。

第 3、4 步为什么重要：Finder 只有在**自己是前台应用**且窗口**真的打开着**时才会应用并把视图选项写进 `.DS_Store`。从后台脚本化时它会静默丢弃，卷里只留一个 6KB 的 `.DS_Store` 空壳（只有 `Bud1`），DMG 打开就是默认窗口：没有背景、没有箭头、图标乱排。**绝对不要把背景设置包进 `try`。**

## 4. 验收清单

验收对象是**最终 DMG 里挂载出来的 app**，不是 `dist` 里那份（后者会持续被 Finder 补元数据）。

```bash
M=$(mktemp -d /private/tmp/relcheck.XXXXXX)
hdiutil attach -nobrowse -readonly -mountpoint "$M" dist/API-Inquiry-vX.Y.Z.dmg
ls -l "$M/.DS_Store"                      # 约 10KB；6KB 说明窗口布局丢了
strings -a "$M/.DS_Store" | grep dmg-background.png
ls "$M/API Inquiry.app/Contents/Resources" # 8 个文件：AppIcon.icns/.png + 6 个 provider logo
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$M/API Inquiry.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$M/API Inquiry.app/Contents/Info.plist"
codesign --verify --deep --strict -v "$M/API Inquiry.app"
hdiutil detach "$M"
(cd dist && shasum -a 256 -c API-Inquiry-vX.Y.Z.dmg.sha256)
```

健康产物的参考值（`v0.3.15`）：`.DS_Store` 10244 字节、窗口边界 `{{160, 527}, {760, 420}}`、背景别名指向 `.background/dmg-background.png`。

- 原生外观一致性无法用源码 diff 证明：必须看构建产物里的真实菜单栏面板（截图或可访问性状态）。不许用自定义圆角或背景掩盖 linked-SDK 回归。
- 打开一次打包后的 app，确认 Settings 显示的版本是 `vX.Y.Z`；没看到就不算发布完成。

## 5. 发布

```bash
git tag -a release/vX.Y.Z -m "API Inquiry vX.Y.Z"
git push origin main
git push origin release/vX.Y.Z
gh release create release/vX.Y.Z \
  dist/API-Inquiry-vX.Y.Z.dmg dist/API-Inquiry-vX.Y.Z.dmg.sha256 \
  --title "API Inquiry vX.Y.Z" --notes-file docs/releases/vX.Y.Z_github.md \
  --latest --verify-tag
gh release view release/vX.Y.Z --json tagName,isDraft,isPrerelease,assets
```

Release 必须非草稿、非预发布，且只带两个资产；上传后建议下载回来验一次校验和：

```bash
gh release download release/vX.Y.Z --pattern "API-Inquiry-vX.Y.Z.dmg*"
shasum -a 256 -c API-Inquiry-vX.Y.Z.dmg.sha256
```

如果在发布后几分钟内就发现产物坏了、且只改了打包逻辑，用 `gh release upload --clobber` 就地替换两个资产是可接受的，但要在说明里讲清校验和已变化。

发布说明写给用户看，不是变更日志：按 New Features / App Optimization / Bug Fixes 分组，没有内容的分组直接省略；不要出现内部类型名、文件路径、测试数量、框架名或重构措辞。优先写用户能感知的说法（"刷新更稳了""状态更好读"），而不是实现细节。

## 6. 收尾

```bash
Scripts/clean-development-apps.sh          # 删除开发态 app，保留 DMG
git worktree remove .worktrees/<name> && git worktree prune
git branch -D <merged-branch>
hdiutil info                               # 确认没有遗留挂载的镜像
```

## 7. 故障对照表

| 现象 | 根因 | 处置 |
|---|---|---|
| Finder 里 app 图标是灰色占位图，Console logo 退化成纯文字 | `Contents/Resources` 为空——资源复制只匹配老的扁平 bundle 布局 | `package-mac-app.sh` 递归查找；`AppIcon.icns` 缺失即失败 |
| 安装窗口没有背景/箭头、图标默认排列，`.DS_Store` 约 6148 字节 | 后台脚本化 Finder 丢弃视图选项；且在写入前就关窗 | 先激活 Finder、等窗口出现、轮询 `.DS_Store` 出现背景别名后再关窗 |
| Console 的「添加供应商」变成整条旧式弹出按钮、面板失去玻璃外观 | 没有使用链接器 SDK 覆盖，二进制记录的 `sdk 13.0` 让 app 退出 macOS 26 设计 | 用 `Scripts/package-mac-app.sh` 重新构建并校验记录的 SDK |
| `codesign --verify` 报 "resource fork, Finder information, or similar detritus" | Desktop 副本被 FileProvider 打上 Finder 元数据 | 验签前 `xattr -cr`；验收以挂载的 DMG 为准 |
| Release 编译出现不可能的语义错误（`@State` 赋值报 `'self' is immutable`） | CLT 的 SDK 与 `/usr/bin/swift` 不匹配 | 用 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` 构建 |
| `sandbox-exec: sandbox_apply: Operation not permitted` | SwiftPM 内层沙箱被外层沙箱拦截 | `swift build/run --disable-sandbox`，或给完整文件权限 |
| `hdiutil create` 报 "operation not permitted" | 沙箱禁止创建磁盘映像 | 用完整文件权限执行打包 |
| 3 条 Keychain 期望失败 `unexpectedStatus(100001)` | 沙箱内无钥匙串访问 | 在沙箱外跑；CI 是最终闸门 |
| 桌面上留着测试卷的幽灵图标 | 先删了挂载点目录再卸载镜像 | 先看 `hdiutil info` 有无遗留镜像，`killall Finder` 重绘桌面 |
