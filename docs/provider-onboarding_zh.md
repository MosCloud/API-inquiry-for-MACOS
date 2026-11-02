# 新增一个供应商

这份文档写给**第一次给 App 加供应商的人或 agent**。读完之后你应该能独立完成：数据来源、凭证、界面、品牌素材、测试与验收。

它不解释每家供应商的业务细节（各 provider 文件里有注释），也不重复 SwiftUI 的基础知识。

> 如果你只是想改某家供应商的显示或行为，直接读那个模块的注释，不需要本文。

## 1. 先做三个决定

在写任何代码之前，先回答三个问题。它们决定了后面几乎每一层怎么写，选错了会返工（v0.4.0 的 `planUsage` 双轨就是例子）。

| 决定 | 选项 | 影响 |
|---|---|---|
| **它卖什么** | 预付费余额，或订阅套餐 | 状态文案（`可用` vs `计划可用`）、Console 指标、菜单栏措辞 |
| **它返回什么形状** | 一个金额，或一个窗口的配额，或多个窗口的配额 | 快照类型、面板英雄区、次要行、Console 详情 |
| **凭证在哪里** | 用户手填（Keychain），或存在于本机 CLI 配置 | 凭证装饰器、API 页按钮、「打开配置」入口 |

对应的三个枚举：`ProviderAccessPurpose`、`ProviderSnapshot`、`ProviderCredentialManagement`。

## 2. 数据层：写 provider

供应商实现 `BalanceProvider`：

```swift
public final class ExampleProvider: BalanceProvider {
    public let id: ProviderID = .example

    public func fetchSnapshot(apiKey: String) async throws -> ProviderSnapshot {
        var request = URLRequest(url: quotaURL)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let response = try await httpClient.data(for: request)
        switch response.statusCode {
        case 200: return try decode(from: response.data)
        case 401: throw BalanceProviderError.authenticationFailed
        case 403: throw BalanceProviderError.subscriptionRequired   // 只有当它真的是订阅制
        case 429: throw BalanceProviderError.rateLimited
        default:  throw BalanceProviderError.serverError(statusCode: response.statusCode)
        }
    }
}
```

返回什么：

- **一个金额** → `.balance(...)`。用户看到总额与币种。
- **一个或多个窗口** → `.quotaUsage(QuotaUsageSnapshot(windows: [...]))`。单窗口和多窗口是同一种形状，不要为"只有一个窗口"另立类型。

每个窗口写清 `label`、`kind`、`remainingPercentage`（注意是**剩余**，不是已用）、`resetAt`、`isAvailable`。`kind` 用 `.fiveHour` / `.week` / `.month`，界面上的标签由 `LocalizedStrings` 决定，不要在 provider 里写中文。

解码要宽容：

- 数字可能是 `"68.65"`、`68.65` 或 `Decimal`，统一走一个解析函数；
- 时间可能带小数秒，也可能没有；
- 缺失字段要显式抛错，而不是静默变成 0。

如果服务端会拦默认 User-Agent（例如前面挂了 Cloudflare），加一个稳定的 UA 常量，**不要**把发版号写进去。

## 3. 凭证层

| 模式 | 什么时候用 | 后果 |
|---|---|---|
| `.appManagedAPIKey` | 供应商只给 Key，用户手动粘贴 | Console 可以保存/替换/删除；Keychain 是唯一来源 |
| `.localExternalConfiguration` | 凭证已经在本机 CLI 里（`~/.codex/auth.json`、OpenCode 的 SQLite 等） | 只读读取，**不写**；Console 不提供保存/删除 |

本机配置型供应商用**装饰器**包在 `KeychainCredentialStore` 外面。

### 3.1 接到运行中的 App 上（最容易漏的一步）

装饰器写完只是"存在"，App 不会自己用它。链在 `Sources/APIInquiryApp/App/APIInquiryApp.swift` 的 init 里，把新的一层加进去：

```swift
let store = LocalBoxCredentialStore(
    delegate: OpenCodeCredentialStore(
        delegate: CodexCredentialStore(delegate: KeychainCredentialStore())
    )
)
```

**顺序不重要，但转发很重要**：每个装饰器对**自己不认识**的 provider 必须原样转发给 delegate（照抄 `OpenCodeCredentialStore.configurationURL`）。只回答自己关心的那几个、其余返回 `nil`，就会把它上层/下层供应商的「打开配置」吞掉 —— 编译通过、测试全绿，按钮永远置灰。

（这条以前是坑：Codex 曾对非 Codex 直接返回 `nil`，于是顺序变成了隐性规则，见 #83。）

### 3.2 能力用协议，不用 `as?`

装饰器一旦包了一层，`as? CodexCredentialStore` 就永远是 `false`，功能静默消失（#13 的「打开配置」按钮就这样丢过）。当前有两个能力协议，需要按需实现并逐层转发：

- `LocalConfigurationProviding` → 「打开配置」按钮指向哪个文件；
- `CodexCredentialProviding` → Codex 会话文件损坏时的提示。**新装饰器不转发它，Codex 的提示就没了。**

### 3.3 两条行为约定

1. **只读**。不写回 CLI 的文件或数据库，不复制凭证到别处；删除 Key 后界面仍显示"已配置"是预期行为，真正的凭证还在 CLI 那边。
2. **「打开配置」指向哪里**：文件不存在时返回 `nil`（按钮置灰并给提示），存在时返回文件本身。Codex 和 OpenCode 还会退到"文件所在目录"，如果你要沿用，写进测试，不要靠猜。

### 3.4 写一条转发测试

转发是行为，不是配置，所以给它一条测试：用 `InMemoryCredentialStore` 垫底，把你的装饰器包上去，断言**一个它不拥有的 provider** 仍能拿到 delegate 的答案；再断言它自己负责的 provider 返回自己的答案。

App 侧的链本身没有自动化测试（测试 runner 不编译 App），所以改完链之后，再到 Console API 页实际点一次「打开配置」。

### 3.5 当存下来的凭证是加密的

有些桌面 App 已经不再明文存 token 了。WorkBuddy 5.6.0+ 写的是：

```json
"accessToken": { "$wbEncrypted": 1, "envelope": "<base64 的 {suite,keyId,nonce,authTag,ciphertext}>" }
```

只认字符串的读取器会**完全看不到凭证**，于是把用户报成「未登录」——然后让用户重新登录，而这个动作根本解决不了问题。这跟「CLI 把 token 存在文件里」是**两类问题**，需要普通装饰器没有的三样东西。

**密钥不是用户机密。** 它是编译进 App 的构建常量，由此有两条推论：

- **不要**把它抄一份冻在这个仓库里；厂商每发一版它就可能变。
- **不要**让用户输入任何东西。没有东西让他们输。

去问写下这个文件的那个 App。Electron App 通常把值藏在它自己的原生绑定后面，把它的二进制以 Node 模式跑起来就能拿到：

```bash
ELECTRON_RUN_AS_NODE=1 "/Applications/<App>.app/Contents/MacOS/<binary>" \
  -e "process.stdout.write(process._linkedBinding('<binding>').loggerGet())"
```

`WorkBuddyCredentialStore` 就是这么做的，它学到的三条规则：

1. **严格照厂商的方式派生密钥。** WorkBuddy 哈希的是载荷里 base64 **字符串**，不是解码后的字节。哈希解码后的字节会得到另一个密钥，然后每个字段都过不了 AES-GCM 的 tag，且没有任何线索指向原因。
2. **解密前先校验。** 信封里写了它是哪把密钥封的（`keyId`）；比对它，不匹配就明确失败，而不是返回垃圾。
3. **AAD 必须逐字节一致。** WorkBuddy 的附加认证数据是一串带长度前缀的记录（`WB-AAD\0`、scheme、格式 id、suite、keyId、framing 码、两个零字节）。字节顺序错了和密钥错了是**无法区分**的：两种情况 GCM 都只是 tag 校验失败。

**密钥缓存在内存里，绝不落盘**，并且以信封的 `keyId` 为缓存键——这样厂商升级轮换了密钥，下一次读取会自动重取，而不是一直失败到重启。在 WorkBuddy 上问一次 App 要 60–90 ms（Electron 冷启动实测），所以每次刷新都重跑也不是不能接受，但纯属浪费。

**把「没登录」和「已登录但读不出来」分开。** 从外面看两者一模一样——零个可用凭证——但给出的建议正好相反，而那句通用的「重新登录一次」恰恰是第二种情况下**唯一帮不上忙**的动作。给读不出来这种情况一个带解决方案的独立错误（「需要安装桌面 App」），并暴露重新登录是否可能有用：

```swift
public var isSignInProblem: Bool   // 所有加密凭证的情况都是 false
```

**给子进程加护栏。** 不给 stdin、设硬超时、只读 stdout；卡住的子进程绝不能阻塞刷新。macOS 上要靠读 bundle 自己的 `CFBundleExecutable` 来定位二进制（Electron App 的二进制就叫 `Electron`），执行前先校验 `CFBundleIdentifier`，否则你会启动一个毫不相干的 Electron App：WorkBuddy 的安装里 `<bundle>/Contents/MacOS/WorkBuddy` 这个路径**根本不存在**。

最后，**按数量级归一化时间戳单位，不要假设。** 桌面端文档把 `expiresAt` 写成**毫秒**；同一字段在插件侧副本里是**秒**：

```swift
return raw > 1_000_000_000_000 ? raw : raw * 1000
```

## 4. 描述符与注册表

所有接线集中在 `BuiltInProviderRegistry.default`。一个条目的样子：

```swift
ProviderRegistration(
    descriptor: ProviderDescriptor(
        id: .example,
        displayName: "Example",                 // Console 卡片标题
        menuPrefix: "EX",                       // 菜单栏图标旁的短前缀
        credentialAccount: "example-api-key",   // Keychain 账号，必须唯一
        homepageURL: URL(string: "https://example.com/usage")!,
        detailKind: .quotaUsage,                // .balance 或 .quotaUsage
        credentialManagement: .appManagedAPIKey,
        accessPurpose: .planQuota,
        menuTitlePrefix: "EX"                   // nil 表示标题不带前缀（Codex 就是这样）
    ),
    makeProvider: { ExampleProvider() }
)
```

`menuPrefix` 与 `menuTitlePrefix` 是两个用途，允许取值不同：前者画在菜单栏图标区域，后者拼在标题里。Codex 用 `"GPT"` + `nil`，是故意的。

## 5. 界面：大多数时候不需要改视图

这是 v0.4.0 那批重构换来的：

| 你填的 | 界面自动变成 |
|---|---|
| `accessPurpose` | 状态措辞：`.planQuota` → 计划可用/计划已用尽；`.prepaidBalance` → 可用/余额不足 |
| 快照形态 | 数字格式、英雄区金额、副行（标签 / 数值 / 尾列） |
| `detailKind` | Console 指标列（总余额 vs 详情） |

只有三处需要人眼看：

1. 菜单栏面板——作为主供应商时的英雄区，作为副供应商时的三列行；
2. Console Home——指标卡片；
3. Console API——凭证状态、按钮、打开配置。

**永远不要在视图里写 `if id == .xxx`。** 某个供应商需要不同行为时，把答案放进 `APIProviderSummary` / `ProviderDetailRow` / `ProviderSnapshotPresentation`，让视图读字段。

两个容易漏的细节：

- provider 里写**短的英文标签**（`"5h"`、`"Week"`）；界面上显示的中文/英文标签由 `LocalizedStrings` 从 `kind` 推导。**永远不要在 provider 里写中文。**
- 品牌素材不会自己接上：`ProviderVisualCatalog` 里的加载器和 switch 要你自己加，否则即使文件都放对了，App 也会一直画文字兜底。

### 5.1 先试着套进已有的形态，别急着造新的

新供应商的数据很少刚好对上某个快照字段，第一反应往往是加一个 `ProviderDetailKind` 和配套渲染。**先别急。** 先把数据映射到已有载荷上，看看界面是不是已经读对了。

WorkBuddy 卖的是**积分**，既不是钱也不是百分比。这套映射**一行视图都没改**就落地了：

| `BalanceSnapshot` | WorkBuddy |
|---|---|
| `totalBalance` | 所有包的剩余之和 |
| `grantedBalance` | 平台奖励包 → Console 自己就画出「赠送余额」 |
| `toppedUpBalance` | 套餐基础积分 |
| `currency` | `"CREDITS"` |

新增一个 `detailKind` 的代价是：一个渲染分支、一个格式化器、一整套状态文案，外加各自的测试。复用 `.balance` 只花了一个格式化分支。只有已有形态真的承载不了语义时才另起炉灶——Codex 的手动重置积分就是那个真实例子（它是并行的子系统，不是 `BalanceProvider`）。

**单位不是货币时，写进 `currency` 并在格式化层处理**，不要把单位塞进数值字符串。`"CREDITS"` 让 `ProviderValueFormatter` 把符号换成本地化单位（`¥68.65 CNY` vs `2899.64 积分`），而所有已有的排版规则照常工作。

### 5.2 面板会做什么、不会做什么

下面是当前代码里的硬约束，不是风格偏好：

- **英雄区只给配额窗口。** `MenuBarBalanceViewModel.primaryQuotaWindowRow` 取 5 小时窗口（没有则取第一个）。余额类供应商永远进不了英雄区，它一直是一条副行。
- **余额行是固定三列**，按屏幕上实际内容拟合。宽度有夹取：标签 `24…46`、数值 `26…72`、尾列 `24…44`（`SecondaryRowColumns`）。值太长会省略，而不是缩小字号。
- **尾列放一个简短的限定词**，形态随意：货币代码（`CNY`）、单位（`积分`）、或日期（`11/05`）。控制在 5 个字符以内。
- **尾列放日期时，旁边必须有说明。** 光秃秃一个 `11/05` 贴着数字会被读成分数。要么该行的标签已经说明了日期含义，要么这个日期该放进 Console 并带上前缀。

### 5.3 两个日期含义不同，就必须是两个字段

供应商同时报了刷新时间和到期时间时，端到端都要分开：

```swift
public let expiringAt: Date?     // 这么多会在这里【丢掉】
public let refreshingAt: Date?   // 这么多会在这里【补回】
```

合并成一个「日期」会让面板把一半的余额说错。各自放在它真正描述的那个数字下面——WorkBuddy 的 Console 把「下次刷新」放在总积分下、「最近到期」放在赠送积分下——并且用文字前缀，不要用 `/` 拼接，还是那个分数的理由。

### 5.4 永远不要用 `minimumScaleFactor` 当截断兜底

它会悄悄把字缩小，而不是把挤压暴露出来。v0.4.0 里它让余额行的金额比周围都小一号，而所有测试依然是绿的。让长标签让步（或省略），数字保持原尺寸。

## 6. 品牌素材

供应商锁标是以 **template image** 渲染的，所以最终上屏的只有 alpha 通道。下面所有规则都由这一个事实推出来。

### 6.1 格式：现有五个供应商实际用的是什么

| 供应商 | Header 锁标 | 菜单栏图标 |
|---|---|---|
| DeepSeek | PNG | PNG |
| Zhipu | PNG | PNG |
| Codex（ChatGPT） | PNG | PNG |
| OpenCode | SVG | PNG |
| WorkBuddy | PNG | PNG |

**PNG 是常态，SVG 是例外。** 源本身是矢量时优先用矢量（它按目标尺寸精确光栅化，而不是被重采样），但 PNG 完全可以接受，五个里有四个都是。真正要紧的是 alpha 通道里**装的是什么**，不是扩展名。

### 6.2 唯一要紧的规则：墨要不透明，背景要透明

所有锁标都走 `.renderingMode(.template)`。template 图只带 **alpha**：颜色被丢弃，macOS 重新给不透明的部分染色。

所以素材必须做成**镂空**：字形或标记是不透明的，所有应该读作背景的地方是透明的。接进去之前先量一下：

```bash
# 画布上有多大比例是不透明的？
python3 - <<'PY'
from PIL import Image
im = Image.open("<asset>.png").convert("RGBA")
a = im.split()[-1]
px = a.load()
full = sum(1 for y in range(im.height) for x in range(im.width) if px[x, y] == 255)
print(f"不透明: {full / (im.width * im.height):.1%}")
PY
```

健康的素材大约落在 **20–45% 不透明**：

| 供应商 | 不透明 | 透明 |
|---|---|---|
| Zhipu | 12.2% | 81.1% |
| OpenAI | 18.9% | 78.9% |
| DeepSeek | 24.6% | 69.0% |
| OpenCode | 25.4% | 67.5% |
| WorkBuddy（重建后） | 41.8% | 57.4% |

**实心彩色位图**——也就是 App 营销物料最常见的那种形态——不透明度 45% 以上，图形是用**颜色画在里面**的。把它当 template 渲染出来就是一块白板：标记变成没有细节的方块，字标糊成一片。WorkBuddy 就是这么翻车的，见附录 D。

**官方素材是实心位图时**，接进去之前先重建成镂空：把品牌色的块当作墨，把浅色的镂空部分（标记内部、字腔）变成透明。**不要手工反转成白底黑字的剪影**——那会颠倒正负形，标记看起来就不是同一个标记了。

### 6.3 去哪里找素材

按优先级：

1. 公司的品牌页或媒体素材页。
2. 仓库自己的 `brand/` 目录。
3. **已安装的桌面 App 内部**——见 6.4。
4. 确实没有官方素材：画一个不依赖字体的 SVG，并在注释里说明（`"合成素材，无第三方权利"`）。**永远不要**把系统字体排出来的字标当作公司 logo。

把来源和许可记录在加载器旁边（例如 `MIT / © 2025 opencode` 或 `Extracted from WorkBuddy.app 5.9.3, © workbuddy.cn`）。

### 6.4 从已安装的 Electron App 里提取

Electron App 把渲染层资源打包在 `Contents/Resources/app.asar` 里，那是**归档文件不是目录**——`ls` 看不见里面：

```bash
npx --yes @electron/asar extract "/Applications/<App>.app/Contents/Resources/app.asar" /tmp/<app>-asar
find /tmp/<app>-asar -iname "*.svg" -o -iname "*.png" | grep -iE "logo|brand|wordmark"
```

两个坑，WorkBuddy 那次都踩到了：

- **同目录下有别家产品的素材。** WorkBuddy 的 bundle 里还有 `header-icon-*.svg`——那是 **CodeBuddy** 的锁标，同门品牌，文件名模式几乎一样。选定之前把每个候选都渲染出来看一眼：`qlmanage -t -s 800 -o /tmp/preview <file>.svg`。
- **别以为以品牌名命名的文件就是锁标。** 渲染层 bundle 里的 `logo-<brand>.svg` 往往是方形应用图标；横向锁标通常是某个 `*-logo-*.png`，尺寸是显示尺寸的 2–3 倍。

这样提取出来的是厂商的商标，用途是标识 App 读取的那个服务。在加载器声明处写明这一点，并把归属加进 `THIRD-PARTY.md`。

### 6.5 量它

在 `ProviderLogoMetrics.template(for:)` 里加一条测量：

- `canvasWidth/Height`：素材自己的画布；
- `wordmarkHeight`：字标的完整墨迹高度；
- `xHeight`：小写字母的高度。**锚定 x-height，不要锚定包围盒**——小写、全大写、像素字体的上下伸出部分差别很大，锚包围盒会让各家看起来尺寸不一。**双行**字标取单行的 cap height，不是两行的总和；
- `visualScale`：字标视觉重量的补偿。代码算的是 `size = target * visualScale / xHeight`，所以**值越大渲染越大**。同样 x-height 下字面显得小或轻就调大（Codex 用 1.08），显得重或大就调小。

测量方法是找墨迹包围盒和逐行的行距。**要排除标记**——它贯穿整幅高度，会把行结构掩盖掉：

```bash
python3 - <<'PY'
from PIL import Image
im = Image.open("<asset>.png").convert("RGBA")
px = im.load(); W, H = im.size
# 1) 标记在左侧，与字标之间有一个明显的竖直空隙
cols = [x for x in range(W) if any(px[x, y][3] > 20 for y in range(0, H, 2))]
gx = [(cols[i-1], cols[i]) for i in range(1, len(cols)) if cols[i] - cols[i-1] > 20]
text_x0 = gx[0][1] if gx else 0
# 2) 只统计字标区域里的墨迹行
rows = [y for y in range(H)
        if any(min(px[x, y][:3]) < 200 and px[x, y][3] > 20 for x in range(text_x0, W, 2))]
gaps = [(rows[i-1], rows[i]) for i in range(1, len(rows)) if rows[i] - rows[i-1] > 1]
print("墨迹行:", rows[0], "..", rows[-1], "| 行间隙:", gaps)
PY
```

WorkBuddy 会打印 `墨迹行: 76 .. 482 | 行间隙: [(264, 293)]`——是个**双行**锁标。所以
x-height 锚点取单行的 cap height（189 px），不是 407 px 的总高。

### 6.6 菜单栏图标

`<id>-menu-icon-template.png`，template 图，macOS 可以给它染色。

**按视觉重量定尺寸，不要照抄数字。** 实心圆角徽章在同样大小的框里覆盖的墨远比裸露字形多，照抄别人的尺寸就会显得大一号。当前尺寸：

| 供应商 | 尺寸 | 理由 |
|---|---|---|
| DeepSeek | 20×20 | 裸露字形 |
| Zhipu | 20×18 | 徽章，但很细 |
| Codex | 16×16 | 裸露字形 |
| OpenCode | 16×16 | 裸露字形 |
| WorkBuddy | 16×16 | 实心徽章——20×20 显得过大 |

### 6.7 接线

在 `ProviderVisualCatalog` 里为新 id 加三个 switch 和一个加载器：header 锁标、菜单栏图标尺寸、菜单栏图标。照 OpenCode 的顺序：`loadVector` → `loadPNG` → `textTemplateImage`。**绝对不要**兜底到 `Bundle.module`：SwiftPM 的访问器在资源缺失时会 `fatalError`，打包后的 App 一启动就崩。

打包脚本已经递归复制 `*.png` / `*.icns` / `*.svg`；只有当你要用**别的扩展名**时才需要动它。

## 7. 测试与验收

先明确谁在替你检查，避免把精力花在已经有人管的地方：

| 检查方式 | 覆盖什么 | 漏了会怎样 |
|---|---|---|
| 编译器 | `ProviderID` 上的穷举 switch：`ProviderLogoMetrics.template(for:)`、`ProviderVisualCatalog` 的三处、`FixtureMode.sampleSnapshot(for:)` | 编译失败 |
| 测试 | `ProviderOnboardingTests`：描述符字段、凭证账号唯一、锁版模板数值、fixture 样本、窗口标签 | 测试变红 |
| 只能靠人 | 注册表字段的**内容**、素材文件是否真的存在、`ProviderVisualCatalog` 的 loader、能力协议是否被转发、App 装饰器链、README 与发布说明 | 静默不生效（界面退回文字模板 / 按钮消失） |

`ProviderOnboardingTests` **不是全覆盖**：它检查的是"配置数据完整"，不检查素材文件是否存在、视图有没有接上。绿了只代表前半程没问题。

必须补的测试：

- 解码：正常 / 缺字段 / 数字是字符串 / 时间带小数秒；
- 错误映射：401 / 403 / 429 / 5xx；
- 凭证：读取优先级、缺失与损坏；
- 窗口标签与重置时间格式（中英文各一条）；
- 锁版度量：`ProviderLogoMetrics.template(for:)` 有值。

别忘了三件容易被忽略的事：

1. **把新测试登记到** `Sources/APIInquiryCoreTestsRunner/main.swift` —— 不登记就不会执行，而且不会有任何提示；
2. **两个既有测试会变红，但它们不是你的错**：`ProviderCatalogTests` 写死了供应商顺序、凭证账号字典，`FixtureModeTests` 写死了数量。能换成 `ProviderID.allCases` / `allCases.count` 的就换，下次不用再改；
3. **本地配置型供应商补一条链转发测试**（见 §3.4），这是唯一能挡住"装饰器顺序错误"的手段。

### 和厂商自己的界面核对

测试全绿不代表数字是对的。它只代表数字符合**你写的断言**——而如果你对接口的理解错了，
测试就朝同一个方向错。

真实的教训：WorkBuddy 的接口返回 **HTTP 200**、`code: 0`，给出一个看起来完全合理的
**2,389 积分**，而不是 **2,856**。套餐时间窗写错了，月度套餐被静默过滤掉。所有测试都过，
`verify.sh` 也过，Console 显示的是一个可信的数字。最后是靠打开 WorkBuddy 自己的
「套餐与积分」页面逐项对比才发现的。

所以接线跑通之后：

1. **找到厂商自己的界面**，上面显示同一个数字（他们的控制台、仪表盘，或 CLI 自己的
   状态命令）。
2. **逐字段比对**，不要只比总数——总数可能对，但少了一项又重复算了另一项。
3. **不一致时，信任厂商的界面。** 在证明自己正确之前，先怀疑自己的解码。
4. **把这次不一致钉成回归测试。** 只断言总数抓不到这个 bug；测试必须断言**请求本身**
   或**组成项**，而不只是和。

一个你无法独立验证数据的供应商，还不算验收通过——你只是证明了它能返回可解析的 JSON。

### 验收时注意 fixtures 的陷阱

`--fixtures` 场景会把凭证层换成 `InMemoryCredentialStore`，并给每个账号塞 `"fixture-key"`。所以本地配置型供应商在 fixtures 下**永远显示已配置**，用它验证不了"文件缺失 = 未配置"。验证本地凭证要用真实副本，或写单测注入临时文件。

然后：

```bash
Scripts/verify.sh        # 测试 + 编 App，缺一不可
```

再截三张实机图：菜单栏面板、Console 首页、Console API 页。

文档层面记得同步两处供应商清单：`README.md` / `README_en.md`，以及 `AGENTS.md` 开头那句带供应商列表的描述。

最后跑一次 `ProviderOnboardingTests` —— 它会遍历 `ProviderID.allCases`，检查描述符字段、凭证账号唯一性、锁版模板、fixture 样本、窗口标签。**漏了会红。**

## 8. 已知陷阱

| 症状 | 原因 | 处理 |
|---|---|---|
| 打包后的 app 一打开就闪退 | 资源缺失时用 `Bundle.module` 取图，SwiftPM 会 `fatalError` | 资源放进 target，加载失败退到文字模板 |
| 「打开配置」按钮突然消失 | 装饰器没实现/转发能力协议，`as?` 探测失败 | 抽协议并逐层转发 |
| 四家供应商 logo 大小不一 | 靠手调 frame，没有统一锚点 | 用 `ProviderLogoMetrics` 的 x-height 推导 |
| 打出来的 DMG 里没有 logo | 打包脚本漏复制新扩展名 | 脚本已递归复制 `png/icns/svg`；新增别的扩展名时才改脚本，缺 `AppIcon.icns` 会中止 |
| 新供应商的「打开配置」永远置灰 | 某个装饰器对自己不认识的 provider 返回 `nil` 而不是转发 | 每一层都转发（§3.1），并用测试锁住 |
| 验证时弹钥匙串授权 | 重新编译改变了 ad-hoc 签名 | 让用户点「始终允许」，这是预期行为 |
| 用户明明登录了，供应商却显示「未配置」 | 存下来的 token 是加密包装，只认字符串的读取器什么也拿不到（§3.5） | 打开字段；并给读不出来的情况独立错误 |
| 每次解密都过不了 AES-GCM tag | 密钥派生用的拼写不对（解码字节 vs base64 字符串），或 AAD 差一个字节（§3.5） | 逐字照抄厂商的派生方式；tag 失败不会告诉你错在哪 |
| Console 显示 0，但厂商自己的面板有余额 | HTTP 200 里带了非零的业务 `code`，或查询时间窗悄悄排除了套餐 | 把非零的 envelope code 当错误；用回归测试钉住时间窗 |
| 品牌锁标渲染成一块空白白板 | 官方素材是实心彩色位图；template 只留 alpha，整块都是墨 | 重建成镂空（§6.2） |
| 菜单栏图标看起来比旁边的大 | 它是实心徽章，同样大小的框里盖住的墨多得多 | 按视觉重量定尺寸，别照抄数字（§6.6） |

## 附录 A：OpenCode 接入案例

按时间顺序，五组"错误示范 → 正确做法"。这是本文档最有价值的部分，因为它全部真实发生过。

1. **字标**：先用 SF Pro 拼了 `opencode` 文字 → 换成官方 SVG 像素字标。拼出来的字标在任何字号下都不像。
2. **尺寸**：靠肉眼调 frame，四家大小不一致 → 改为测量 x-height 锚定，OpenCode 再加 `visualScale` 补偿方块字的视觉重量。
3. **凭证**：Console 里用 `as? CodexCredentialStore` 判断能力 → 包一层装饰器后判断永远失败，「打开配置」静默消失 → 抽 `LocalConfigurationProviding`，每个装饰器转发。
4. **配置入口**：视图里写 `if id == .codex` 才显示按钮 → 改成由 store 回答"这个供应商的本地配置文件在哪"，缺失时置灰并给提示（#13）。
5. **快照形状**：单窗口用 `PlanUsageSnapshot`、多窗口用 `QuotaUsageSnapshot`，两套类型让每个 switch 写两遍、面板出现两种行样式 → 统一成 `.quotaUsage`，单窗口就是只有一个元素的窗口数组（#64、#65）。

顺带一个教训：#9 / #80 的"三列对齐"其实也是形状不统一的下游后果 —— 数据层统一之后，界面层才有机会统一。

## 附录 B：这份文档是怎么验证的

它被盲测过两次：一个没有上下文的 agent 只拿这份文档，去加一个虚构供应商 —— 一次用用户手填的 Key，一次用 CLI 文件里的凭证。两次的实现都通过了 `Scripts/verify.sh`，也两次暴露了作者看不见的缺口：测试登记步骤、两个写死供应商清单的既有测试、装饰器接线顺序、以及 fixtures 对本地凭证的假象。这些现在都写进上文了。

如果你大幅修改这份文档，建议重复同样的实验：让一个 agent 拿着它去加一个虚构供应商，看它在哪里绊住。自己读一遍代替不了这个测试。

## 附录 C：速查清单

```
[ ] 三个决定：卖什么 / 返回什么 / 凭证在哪
[ ] provider 文件 + 错误映射 + 防御式解码
[ ] 凭证：App 管理，或装饰器 + 两个能力协议 + 接进 APIInquiryApp 的链（不认识的要转发）
[ ] 凭证加密？打开字段、校验 keyId、密钥只在内存缓存，并把「没登录」和「读不出来」分开（§3.5）
[ ] ProviderID case + 注册表条目（描述符：9 个必填 + 1 个可选）
[ ] 先试过套用已有快照形态，再考虑新增 detailKind（§5.1）
[ ] 品牌素材：镂空 alpha（20-45% 不透明，不是实心位图）、<id>-logo-header、<id>-menu-icon-template
[ ] ProviderLogoMetrics 测量（画布 / 字标高度 / x-height / visualScale）
[ ] 菜单栏图标按视觉重量定尺寸，不照抄数字（§6.6）
[ ] Fixture 样例（编译器会提醒你）
[ ] 测试：解码 / 错误 / 凭证 / 标签 / logo 测量
[ ] 含义不同的两个日期保持为两个字段（§5.3）
[ ] Scripts/verify.sh + 三张截图
[ ] README 与发布说明
```

## 附录 D：WorkBuddy 接入案例

按这份指南接入的第二个真实供应商（v0.4.1，#94），也是第一个凭证加密的。按发生顺序记录代价。

**1. 凭证不能当字符串读。** `auth.accessToken` 是
`{$wbEncrypted: 1, envelope: …}`。只认字符串的读取器会把已登录的用户报成未登录。→ §3.5

**2. 密钥是构建常量，不是机密。** 通过 `ELECTRON_RUN_AS_NODE` 问已安装的 App 要，耗时 60–90 ms，且不需要用户做任何事。把这个常量冻在仓库里，会在 WorkBuddy 下一次发版时失效。→ §3.5

**3. AAD 那份记录试了三次。** `WB-AAD\0` + 格式 id + scheme + suite + keyId + framing 字节 + 两个零，除了单字节之外都带长度前缀。顺序错和密钥错产生的是同一种失败，没有任何可以缩小范围的地方：逐字照抄厂商的构造。→ §3.5

**4. 一个看起来合理的查询时间窗会悄悄丢数据。** `PackageEndTimeRangeEnd` 必须是客户端自己那个约 100 年的上界（`3185136e6` 毫秒）。写成 36.9 天的窗口**照样返回 200**，但漏掉了月度套餐：36 个包 / 2,389 积分，而不是 37 个 / 2,856。任何地方都没有报错。用一条解析请求体的回归测试把时间窗钉住。→ §7

**5. 官方锁标是实心位图。** 不透明度 45.4%，图形是用颜色画在里面的——其他每个供应商的素材都是 67–81% 透明的镂空。当 template 渲染出来就是一块白板，Console 标签当时显示的就是这个。从它重建了镂空版（57.4% 透明）；先试过手工反转成白底黑字剪影，结果看起来像另一个标记。→ §6.2

**6. 20×20 下徽章大了一号。** 实心徽章比同样框里的裸露字形盖的墨多；16×16 在视觉上才和其他家齐平。→ §6.6

**7. 积分不是钱，「余额」这个词对它是错的。** `currency: "CREDITS"` 加一个格式化分支就把单位弄对了；Console 的标题需要自己的词条（「总积分」/「赠送积分」对「总余额」/「赠送余额」），并且挂在 summary 上而不是在视图里推导。→ §5.1

**8. 两个日期，两个含义。** 套餐基础积分在周期结束时**刷新**；平台奖励积分**到期就没了**。合成一个字段会让面板把话说错。拆成 `refreshingAt` 和 `expiringAt`，各自渲染在它真正描述的那个数字下面。→ §5.3

**完全没动的地方**（因为复用了形态而不是新造）：`ProviderDescriptor`、`ProviderSnapshot`、Console 卡片布局、菜单栏英雄区、`BalanceRefreshController`。整套界面都是从填满一个 `BalanceSnapshot` 里长出来的。
