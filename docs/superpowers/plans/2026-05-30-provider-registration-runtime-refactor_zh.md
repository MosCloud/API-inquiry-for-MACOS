# Provider Registration Runtime 重构实施计划

> **给 agentic workers：** 必须使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 按任务执行本计划。步骤使用 checkbox（`- [ ]`）跟踪。

**目标：** 完成 `v0.3.6-Refactor` 后续的 Provider 元数据所有权收口，让 `ProviderRegistration` 成为运行时 descriptor 元数据来源。

**架构：** Provider 元数据应从 `BuiltInProviderRegistry` 经过 `ProviderRegistration` 进入 `ProviderRuntime`。`BalanceProvider` 只保留 `id` 和 `fetchSnapshot(apiKey:)`，credential account 与展示元数据都由 `ProviderDescriptor` 提供。

**技术栈：** Swift 5.9、SwiftUI、Combine、自定义 `APIInquiryCoreTestsRunner`。

**实施状态：** 已作为 `v0.3.6-Refactor` 的一个整合后续重构完成。最终验证通过：`swift run APIInquiryCoreTestsRunner`（`PASS: 478 expectations`）、`swift build`、`git diff --check`、provider metadata fallback 生产依赖扫描，以及一次只读 subagent 质量审查且无阻塞问题。

---

## 目标依赖方向

```text
BuiltInProviderRegistry
  -> ProviderRegistration
      -> ProviderDescriptor
      -> BalanceProvider factory

MultiProviderBalanceCoordinator
  -> ProviderRuntime(descriptor, provider, controller)

BalanceRefreshController
  -> provider.fetchSnapshot(apiKey:)
  -> credentialAccount supplied from descriptor

ViewModel / UI
  -> coordinator descriptor/state
```

## 文件范围

- 修改：`Sources/APIInquiryCore/Refresh/MultiProviderBalanceCoordinator.swift`
- 修改：`Sources/APIInquiryCore/Refresh/BalanceRefreshController.swift`
- 修改：`Sources/APIInquiryCore/Providers/BalanceProvider.swift`
- 修改：`Sources/APIInquiryCore/Formatting/ProviderValueFormatter.swift`
- 修改：`Sources/APIInquiryCore/Formatting/ProviderDisplayFormatter.swift`
- 修改：`Sources/APIInquiryCore/ViewModels/MenuBarBalanceViewModel.swift`
- 修改：`Sources/APIInquiryCore/ViewModels/UsageConsoleViewModel.swift`
- 修改：`Sources/APIInquiryApp/APIInquiryApp.swift`
- 修改：`Sources/APIInquiryCoreTestsRunner/BalanceRefreshControllerTests.swift`
- 修改：`Sources/APIInquiryCoreTestsRunner/MultiProviderBalanceCoordinatorTests.swift`
- 修改：`Sources/APIInquiryCoreTestsRunner/MenuBarBalanceViewModelTests.swift`
- 修改：`Sources/APIInquiryCoreTestsRunner/UsageConsoleViewModelTests.swift`
- 修改：`Sources/APIInquiryCoreTestsRunner/ProviderCatalogTests.swift`

## Task 1：Coordinator 改为 registration-first

- [ ] **Step 1：写失败测试**

在 `Sources/APIInquiryCoreTestsRunner/MultiProviderBalanceCoordinatorTests.swift` 新增测试：

```swift
@MainActor
private static func testCoordinatorUsesRegistrationDescriptorInsteadOfGlobalCatalog(using harness: TestHarness) {
    let descriptor = ProviderDescriptor(
        id: .deepseek,
        displayName: "Registration DeepSeek",
        menuPrefix: "REG",
        credentialAccount: "registration-deepseek-key",
        homepageURL: URL(string: "https://example.com/registration")!,
        detailKind: .balance,
        credentialManagement: .appManagedAPIKey,
        accessPurpose: .prepaidBalance,
        menuTitlePrefix: "REG"
    )
    let coordinator = MultiProviderBalanceCoordinator(
        registrations: [
            ProviderRegistration(
                descriptor: descriptor,
                makeProvider: { MockBalanceProvider(id: .deepseek, results: []) }
            )
        ],
        credentialStore: InMemoryCredentialStore(),
        preferences: InMemoryProviderPreferencesStore()
    )

    harness.expectEqual(coordinator.descriptor(for: .deepseek), descriptor, "coordinator descriptor comes from registration")
    harness.expectEqual(coordinator.primaryDescriptor, descriptor, "coordinator primary descriptor comes from registration")
}
```

- [ ] **Step 2：运行 RED**

```bash
swift run APIInquiryCoreTestsRunner
```

预期：编译失败，因为 `MultiProviderBalanceCoordinator(registrations:...)` 尚不存在。

- [ ] **Step 3：实现 registration initializer**

更新 `MultiProviderBalanceCoordinator`，主 initializer 接受 `registrations: [ProviderRegistration]`，从 `registration.makeProvider()` 创建 provider，并把 `registration.descriptor` 存入 `ProviderRuntime`。

- [ ] **Step 4：更新 app 入口**

将 `Sources/APIInquiryApp/APIInquiryApp.swift` 改为：

```swift
let registry = BuiltInProviderRegistry.default
let coordinator = MultiProviderBalanceCoordinator(
    registrations: registry.registrations,
    credentialStore: credentialStore,
    preferences: UserDefaultsProviderPreferencesStore(),
    defaultProviderID: registry.defaultProviderID,
    localizedStrings: { LocalizedStrings(language: languageStore.resolvedLanguage) }
)
```

- [ ] **Step 5：运行 GREEN**

```bash
swift run APIInquiryCoreTestsRunner
swift build
```

预期：两个命令都通过。

- [ ] **Step 6：提交**

```bash
git add Sources/APIInquiryCore/Refresh/MultiProviderBalanceCoordinator.swift Sources/APIInquiryApp/APIInquiryApp.swift Sources/APIInquiryCoreTestsRunner/MultiProviderBalanceCoordinatorTests.swift
git commit -m "refactor: initialize coordinator from provider registrations"
```

## Task 2：注入 credential account

- [ ] **Step 1：写失败测试**

在 `Sources/APIInquiryCoreTestsRunner/BalanceRefreshControllerTests.swift` 新增测试，证明 credential lookup 不再来自全局 provider metadata：

```swift
@MainActor
private static func testRefreshUsesInjectedCredentialAccount(using harness: TestHarness) async {
    let provider = MockBalanceProvider(results: [.success(.balance(makeSnapshot(total: "68.65")))])
    let store = InMemoryCredentialStore(credentialsByAccount: ["custom-account": "custom-key"])
    let controller = BalanceRefreshController(
        provider: provider,
        credentialStore: store,
        credentialAccount: "custom-account"
    )

    await controller.refresh()

    harness.expectEqual(provider.lastAPIKey, "custom-key", "refresh uses injected credential account")
}
```

- [ ] **Step 2：运行 RED**

```bash
swift run APIInquiryCoreTestsRunner
```

预期：编译失败，因为 `credentialAccount:` 参数尚不存在。

- [ ] **Step 3：实现 credential account 注入**

在 `BalanceRefreshController` 中增加：

```swift
private let credentialAccount: String
```

并将 initializer 改为显式接收 `credentialAccount`。`refresh()` 中将 `provider.credentialAccount` 替换为 `credentialAccount`。

- [ ] **Step 4：更新 coordinator 创建 controller 的代码**

从 descriptor 传入：

```swift
BalanceRefreshController(
    provider: provider,
    credentialStore: credentialStore,
    credentialAccount: descriptor.credentialAccount,
    initialState: initialStatesByProviderID[provider.id] ?? .notConfigured,
    localizedStrings: localizedStrings
)
```

- [ ] **Step 5：更新测试和兼容调用点**

所有测试中直接调用 `BalanceRefreshController(provider:credentialStore:)` 的位置都应传入 `credentialAccount`。

- [ ] **Step 6：验证并提交**

```bash
swift run APIInquiryCoreTestsRunner
swift build
git add Sources/APIInquiryCore/Refresh/BalanceRefreshController.swift Sources/APIInquiryCore/Refresh/MultiProviderBalanceCoordinator.swift Sources/APIInquiryCoreTestsRunner
git commit -m "refactor: inject provider credential account into refresh controller"
```

## Task 3：移除 BalanceProvider metadata extension

- [ ] **Step 1：删除 metadata convenience 属性**

从 `Sources/APIInquiryCore/Providers/BalanceProvider.swift` 删除：

```swift
var descriptor: ProviderDescriptor
var displayName: String
var menuPrefix: String
var credentialAccount: String
var homepageURL: URL
var supportsConsoleCredentialManagement: Bool
```

保留 `fetchBalance(apiKey:)`。

- [ ] **Step 2：删除 provider-based formatter overload**

如果没有调用方，删除 `ProviderValueFormatter` 和 `ProviderDisplayFormatter` 中的 `primaryDisplayParts(provider:state:strings:)`。

- [ ] **Step 3：修复编译错误**

所有编译错误都应改成从 coordinator/runtime 获取 `ProviderDescriptor`，不要重新引入全局 catalog 查询。

- [ ] **Step 4：验证并提交**

```bash
swift run APIInquiryCoreTestsRunner
swift build
git add Sources/APIInquiryCore/Providers/BalanceProvider.swift Sources/APIInquiryCore/Formatting
git commit -m "refactor: keep balance providers metadata-free"
```

## Task 4：清理 ViewModel 旧 initializer

- [ ] **Step 1：删除或废弃 provider/controller initializer**

优先删除：

```swift
MenuBarBalanceViewModel(provider:credentialStore:controller:...)
UsageConsoleViewModel(provider:credentialStore:controller:...)
```

如果改动过大，则先标记 deprecated，并改成显式 `ProviderRegistration` 路径。

- [ ] **Step 2：测试改用 coordinator helper**

测试 helper 应构造：

```swift
MultiProviderBalanceCoordinator(
    registrations: [
        ProviderRegistration(
            descriptor: ProviderCatalog.default.descriptor(for: provider.id)!,
            makeProvider: { provider }
        )
    ],
    credentialStore: credentialStore,
    preferences: InMemoryProviderPreferencesStore(
        addedProviderIDs: [provider.id],
        primaryProviderID: provider.id
    ),
    defaultProviderID: provider.id,
    controllersByProviderID: [provider.id: controller]
)
```

- [ ] **Step 3：删除死代码**

如果 `rg "hasConfiguredCredential"` 只找到声明，删除 `UsageConsoleViewModel.hasConfiguredCredential(in:account:)`。

- [ ] **Step 4：验证并提交**

```bash
swift run APIInquiryCoreTestsRunner
swift build
git add Sources/APIInquiryCore/ViewModels Sources/APIInquiryCoreTestsRunner
git commit -m "refactor: remove legacy provider view model entrypoints"
```

## Task 5：简化测试 Mock

- [ ] **Step 1：简化 `MockBalanceProvider`**

在 `Sources/APIInquiryCoreTestsRunner/BalanceRefreshControllerTests.swift` 中将 `MockBalanceProvider` 简化为只保留协议需要的字段和测试 fetch 行为：

```swift
final class MockBalanceProvider: BalanceProvider {
    let id: ProviderID
    private var results: [Result<ProviderSnapshot, Error>]
    private(set) var fetchCount = 0
    private(set) var lastAPIKey: String?

    init(id: ProviderID = .deepseek, results: [Result<ProviderSnapshot, Error>]) {
        self.id = id
        self.results = results
    }

    func fetchSnapshot(apiKey: String) async throws -> ProviderSnapshot {
        fetchCount += 1
        lastAPIKey = apiKey

        guard !results.isEmpty else {
            throw BalanceProviderError.missingBalanceInfo
        }
        return try results.removeFirst().get()
    }
}
```

- [ ] **Step 2：更新旧 metadata 参数测试**

之前向 mock 传入 displayName、menuPrefix、credentialAccount、homepageURL 的测试，改用 descriptor/registration 构造 metadata。

- [ ] **Step 3：验证并提交**

```bash
swift run APIInquiryCoreTestsRunner
swift build
git add Sources/APIInquiryCoreTestsRunner
git commit -m "test: remove metadata from mock providers"
```

## 最终验证

- [ ] 运行：

```bash
swift run APIInquiryCoreTestsRunner
swift build
rg -n "ProviderCatalog\\.default|provider\\.descriptor|provider\\.credentialAccount|singleProvider|singleController|hasConfiguredCredential|displayName: \"DeepSeek\"|menuPrefix: \"DS\"" Sources/APIInquiryCore Sources/APIInquiryApp Sources/APIInquiryCoreTestsRunner
```

- [ ] 检查剩余 `ProviderCatalog.default` 命中，只接受 catalog 测试、catalog 构造、明确记录的兼容路径。
- [ ] 确认 app 可启动，当前 UI 行为不变。
- [ ] 请求最终代码质量审查。
- [ ] 提交最终 cleanup。
