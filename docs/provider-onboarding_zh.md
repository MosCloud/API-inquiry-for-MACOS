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

本机配置型供应商用**装饰器**包在 `KeychainCredentialStore` 外面：

```swift
let store = OpenCodeCredentialStore(delegate: CodexCredentialStore(delegate: KeychainCredentialStore()))
```

两条硬性规则：

1. **只读**。不写回 CLI 的文件或数据库，不复制凭证到别处。
2. **能力用协议表达，不要用 `as?` 判定具体类型。** 装饰器一旦包了一层，`as? CodexCredentialStore` 就永远是 `false`，功能会静默消失（#13 的「打开配置」按钮就这样丢过）。需要额外能力时抽协议（如 `LocalConfigurationProviding`），每个装饰器转发给下一层。

用户删掉 Keychain 里的 Key 之后界面仍显示"已配置"，是预期行为：真正的凭证还在 CLI 那边。

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

这是 v0.4.0 重构的成果，也是这份文档最想省掉的工作量：

| 你只需要填 | 界面自动变成 |
|---|---|
| `accessPurpose` | 状态文案：`.planQuota` → 计划可用/计划已用尽；`.prepaidBalance` → 可用/余额不足 |
| 快照形状 | 数字格式、主区大数字、次要行三列（标签/数值/时间） |
| `detailKind` | Console 指标列（总余额 vs 详情） |

需要人工确认的只有三处：

1. 菜单栏面板：作为 Primary 时的英雄区，作为次要时的三列行；
2. Console 首页：指标框；
3. Console API 页：凭证状态、按钮、「打开配置」。

**不要在视图里写 `if id == .xxx`。** 需要按供应商分支时，把答案放进 `APIProviderSummary` / `ProviderDetailRow` / `ProviderSnapshotPresentation`，让视图读字段。

## 6. 品牌素材

1. **优先用官方 SVG**（品牌页或仓库的 `brand/` 目录），不要用系统字体拼字标；
2. 合成一张 header 锁版（图标 + 字标），命名 `<id>-logo-header.svg`（可选 `.png` 回退）；
3. 在 `ProviderLogoMetrics.template(for:)` 里补一条测量值：
   - `canvasWidth/Height`：素材原始画布；
   - `wordmarkHeight`：字标的完整墨迹高度；
   - `xHeight`：小写字母高度。**尺寸锚定在 x-height，不是外框** —— 全小写、全大写、方块字的 ascender/descender 差很多，按外框对齐会让四家视觉大小不一；
   - `visualScale`：只补偿"同样 x-height 下看起来更大"的字体。判断依据是三个问题：笔画是否明显更粗？是否全大写？是否是方块/像素字？满足越多，补偿值越小（低于 1）。
4. 菜单栏图标单独一套：`<id>-menu-icon-template.png`（模板图，跟随系统着色）；
5. 回退链是 SVG → PNG → 文字模板。**不要**回退到 `Bundle.module`：SwiftPM 的访问器在资源缺失时会 `fatalError`，打包后的 app 直接闪退。

写清素材出处与许可证（例如：MIT / © 2025 opencode）。

## 7. 测试与验收

先明确谁在替你检查，避免把精力花在已经有人管的地方：

| 检查方式 | 覆盖什么 | 漏了会怎样 |
|---|---|---|
| 编译器 | `ProviderID` 上的穷举 switch：`ProviderLogoMetrics.template(for:)`、`ProviderVisualCatalog` 的三处、`FixtureMode.sampleSnapshot(for:)` | 编译失败 |
| 测试 | `ProviderOnboardingTests`：描述符字段、凭证账号唯一、锁版模板、fixture 样本、窗口标签 | 测试变红 |
| 只能靠人 | 注册表字段的**内容**、能力协议是否被装饰器转发、本地化文案是否通顺、README 与发布说明 | 静默不生效 |

必须补的测试：

- 解码：正常 / 缺字段 / 数字是字符串 / 时间带小数秒；
- 错误映射：401 / 403 / 429 / 5xx；
- 凭证：读取优先级、缺失与损坏；
- 窗口标签与重置时间格式（中英文各一条）；
- 锁版度量：`ProviderLogoMetrics.template(for:)` 有值。

然后：

```bash
Scripts/verify.sh        # 测试 + 编 App，缺一不可
```

再截三张实机图：菜单栏面板、Console 首页、Console API 页。

最后跑一次 `ProviderOnboardingTests` —— 它会遍历 `ProviderID.allCases`，检查描述符字段、凭证账号唯一性、锁版模板、fixture 样本、窗口标签。**漏了会红。**

## 8. 已知陷阱

| 症状 | 原因 | 处理 |
|---|---|---|
| 打包后的 app 一打开就闪退 | 资源缺失时用 `Bundle.module` 取图，SwiftPM 会 `fatalError` | 资源放进 target，加载失败退到文字模板 |
| 「打开配置」按钮突然消失 | 装饰器没实现/转发能力协议，`as?` 探测失败 | 抽协议并逐层转发 |
| 四家供应商 logo 大小不一 | 靠手调 frame，没有统一锚点 | 用 `ProviderLogoMetrics` 的 x-height 推导 |
| 打出来的 DMG 里没有 logo | 打包脚本漏复制新扩展名 | 资源复制要递归，且缺 `AppIcon.icns` 时中止 |
| 验证时弹钥匙串授权 | 重新编译改变了 ad-hoc 签名 | 让用户点「始终允许」，这是预期行为 |

## 附录 A：OpenCode 接入案例

按时间顺序，五组"错误示范 → 正确做法"。这是本文档最有价值的部分，因为它全部真实发生过。

1. **字标**：先用 SF Pro 拼了 `opencode` 文字 → 换成官方 SVG 像素字标。拼出来的字标在任何字号下都不像。
2. **尺寸**：靠肉眼调 frame，四家大小不一致 → 改为测量 x-height 锚定，OpenCode 再加 `visualScale` 补偿方块字的视觉重量。
3. **凭证**：Console 里用 `as? CodexCredentialStore` 判断能力 → 包一层装饰器后判断永远失败，「打开配置」静默消失 → 抽 `LocalConfigurationProviding`，每个装饰器转发。
4. **配置入口**：视图里写 `if id == .codex` 才显示按钮 → 改成由 store 回答"这个供应商的本地配置文件在哪"，缺失时置灰并给提示（#13）。
5. **快照形状**：单窗口用 `PlanUsageSnapshot`、多窗口用 `QuotaUsageSnapshot`，两套类型让每个 switch 写两遍、面板出现两种行样式 → 统一成 `.quotaUsage`，单窗口就是只有一个元素的窗口数组（#64、#65）。

顺带一个教训：#9 / #80 的"三列对齐"其实也是形状不统一的下游后果 —— 数据层统一之后，界面层才有机会统一。

## 附录 B：速查清单

```
[ ] 三个决定：卖什么 / 返回什么形状 / 凭证在哪
[ ] provider 文件 + 错误映射 + 宽容解码
[ ] 凭证：appManaged 或 装饰器 + 能力协议
[ ] ProviderID case + 注册表条目（8 个字段）
[ ] 品牌素材：官方 SVG、<id>-logo-header、<id>-menu-icon-template
[ ] ProviderLogoMetrics 测量值（canvas / wordmark / x-height / visualScale）
[ ] fixture 样本（编译器会提醒）
[ ] 测试：解码 / 错误 / 凭证 / 标签 / 锁版
[ ] Scripts/verify.sh + 三张实机截图
[ ] README 与发布说明
```
