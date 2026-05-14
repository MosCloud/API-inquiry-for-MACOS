# DeepSeek 菜单栏余额监控实现计划

> **给 agentic workers：** 必须使用子技能：推荐使用 superpowers:subagent-driven-development，也可以使用 superpowers:executing-plans，按任务逐项执行本计划。步骤使用复选框 (`- [ ]`) 语法追踪。

**目标：** 构建一个原生 macOS 13+ 菜单栏应用，安全保存 DeepSeek API Key，每 5 分钟刷新一次 DeepSeek 官方余额 API，并在菜单栏显示当前余额。

**架构：** 使用 Swift Package，拆成可测试的 `APIInquiryCore` library 和很薄的 `APIInquiryApp` SwiftUI executable。Core 负责供应商抽象、DeepSeek 解码、Keychain 存储、刷新编排和格式化；App target 负责 `MenuBarExtra` UI 和 macOS 行为。

**技术栈：** Swift 5.9+、SwiftUI、AppKit、URLSession、Security/Keychain、Swift Package Manager、本地 Swift 可执行测试 runner。

---

## 测试环境修订

这台机器安装了 CommandLineTools，但没有完整 Xcode。根因检查显示：`xcrun --find xctest` 失败，系统没有安装 `XCTest.framework`，Swift 的 `Testing` 模块也不可用。因此本项目使用本地可执行测试 runner，而不是 XCTest。

下面所有任务章节都已更新为基于 runner 的流程。

实现任务使用以下规则：

- 测试 runner target：`APIInquiryCoreTestsRunner`。
- 测试 runner 文件放在 `Sources/APIInquiryCoreTestsRunner/`。
- 行为测试写成函数，并从 `Sources/APIInquiryCoreTestsRunner/main.swift` 调用。
- 使用本地 `TestHarness` 辅助方法，不使用 XCTest 断言。
- 使用 `swift run APIInquiryCoreTestsRunner` 运行测试。
- 继续使用 `swift build` 做编译验证。

## 文件结构

- 创建 `Package.swift`：定义 core library 和本地测试 runner executable；当 UI 入口存在后再加入 app executable target。
- 创建 `Sources/APIInquiryCore/Models/BalanceModels.swift`：供应商 id、余额快照、余额状态和展示模式模型。
- 创建 `Sources/APIInquiryCore/Providers/BalanceProvider.swift`：供应商协议和供应商错误定义。
- 创建 `Sources/APIInquiryCore/Networking/HTTPClient.swift`：可注入 HTTP client 抽象和 URLSession 实现。
- 创建 `Sources/APIInquiryCore/Providers/DeepSeekBalanceProvider.swift`：DeepSeek `/user/balance` 请求、响应解码、CNY 优先和错误映射。
- 创建 `Sources/APIInquiryCore/Security/CredentialStore.swift`：凭据存储协议和 Keychain 实现。
- 创建 `Sources/APIInquiryCore/Refresh/BalanceRefreshController.swift`：启动、手动和定时刷新协调器。
- 创建 `Sources/APIInquiryCore/ViewModels/MenuBarBalanceViewModel.swift`：菜单栏标题格式化、设置状态、设置操作和 UI 状态。
- 创建 `Sources/APIInquiryApp/APIInquiryApp.swift`：SwiftUI `MenuBarExtra` 应用入口。
- 创建 `Sources/APIInquiryApp/MenuBarContentView.swift`：极简展开面板和 API Key 设置 UI。
- 创建 `Scripts/build-local-app.sh`：带 `LSUIElement=true` 的本地 `.app` bundle 构建脚本。
- 创建 `Sources/APIInquiryCoreTestsRunner/TestHarness.swift`：用于本地验证的轻量断言 harness。
- 创建 `Sources/APIInquiryCoreTestsRunner/TestHarnessTests.swift`：自检 runner 在没有执行任何断言时会失败。
- 创建 `Sources/APIInquiryCoreTestsRunner/main.swift`：运行全部 core 行为测试的 async 入口。
- 创建 `Sources/APIInquiryCoreTestsRunner/DeepSeekBalanceProviderTests.swift`：供应商解码和错误测试。
- 创建 `Sources/APIInquiryCoreTestsRunner/BalanceRefreshControllerTests.swift`：刷新状态和上次快照测试。
- 创建 `Sources/APIInquiryCoreTestsRunner/MenuBarBalanceViewModelTests.swift`：标题、面板文本和 key 可见性测试。
- 创建 `Sources/APIInquiryCoreTestsRunner/KeychainCredentialStoreTests.swift`：使用隔离 service name 测试保存、读取、替换和删除。

---

### 任务 1：Package 骨架与核心模型

**文件：**
- 创建：`Package.swift`
- 创建：`Sources/APIInquiryCore/Models/BalanceModels.swift`
- 创建：`Sources/APIInquiryCore/Providers/BalanceProvider.swift`
- 创建：`Sources/APIInquiryCore/Networking/HTTPClient.swift`
- 测试：`swift build` 编译初始 core target；测试 runner 创建后，通过 `APIInquiryCoreTestsRunner` 运行行为测试。

- [ ] **步骤 1：创建 `Package.swift`**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "APIInquiry",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "APIInquiryCore",
            targets: ["APIInquiryCore"]
        ),
        .executable(
            name: "APIInquiryCoreTestsRunner",
            targets: ["APIInquiryCoreTestsRunner"]
        )
    ],
    targets: [
        .target(
            name: "APIInquiryCore"
        ),
        .executableTarget(
            name: "APIInquiryCoreTestsRunner",
            dependencies: ["APIInquiryCore"]
        )
    ]
)
```

- [ ] **步骤 2：创建核心余额模型**

创建 `Sources/APIInquiryCore/Models/BalanceModels.swift`：

```swift
import Foundation

public enum ProviderID: String, Equatable {
    case deepseek
}

public enum MenuBarDisplayMode: Equatable {
    case text
    case iconAndText
}

public struct BalanceSnapshot: Equatable {
    public let providerID: ProviderID
    public let totalBalance: Decimal
    public let currency: String
    public let isAvailable: Bool
    public let grantedBalance: Decimal?
    public let toppedUpBalance: Decimal?
    public let fetchedAt: Date

    public init(
        providerID: ProviderID,
        totalBalance: Decimal,
        currency: String,
        isAvailable: Bool,
        grantedBalance: Decimal?,
        toppedUpBalance: Decimal?,
        fetchedAt: Date
    ) {
        self.providerID = providerID
        self.totalBalance = totalBalance
        self.currency = currency
        self.isAvailable = isAvailable
        self.grantedBalance = grantedBalance
        self.toppedUpBalance = toppedUpBalance
        self.fetchedAt = fetchedAt
    }
}

public enum BalanceState: Equatable {
    case notConfigured
    case loading(last: BalanceSnapshot?)
    case loaded(BalanceSnapshot)
    case failed(message: String, last: BalanceSnapshot?)

    public var lastSnapshot: BalanceSnapshot? {
        switch self {
        case .notConfigured:
            return nil
        case .loading(let last):
            return last
        case .loaded(let snapshot):
            return snapshot
        case .failed(_, let last):
            return last
        }
    }
}
```

- [ ] **步骤 3：创建供应商协议和用户可读错误**

创建 `Sources/APIInquiryCore/Providers/BalanceProvider.swift`：

```swift
import Foundation

public protocol BalanceProvider {
    var id: ProviderID { get }
    var displayName: String { get }
    var menuPrefix: String { get }
    var credentialAccount: String { get }

    func fetchBalance(apiKey: String) async throws -> BalanceSnapshot
}

public enum BalanceProviderError: Error, Equatable, LocalizedError {
    case invalidURL
    case authenticationFailed
    case rateLimited
    case serverError(statusCode: Int)
    case missingBalanceInfo
    case invalidBalanceAmount(String)
    case decodingFailed

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Balance API URL is invalid."
        case .authenticationFailed:
            return "API key may be invalid. Replace or delete it in settings."
        case .rateLimited:
            return "Balance API rate limit reached. Try again shortly."
        case .serverError(let statusCode):
            return "Balance API returned HTTP \(statusCode). Try again shortly."
        case .missingBalanceInfo:
            return "Balance API did not return balance information."
        case .invalidBalanceAmount:
            return "Balance API returned an invalid balance amount."
        case .decodingFailed:
            return "Balance API response could not be decoded."
        }
    }
}
```

- [ ] **步骤 4：创建可注入 HTTP client**

创建 `Sources/APIInquiryCore/Networking/HTTPClient.swift`：

```swift
import Foundation

public struct HTTPResponse: Equatable {
    public let data: Data
    public let statusCode: Int

    public init(data: Data, statusCode: Int) {
        self.data = data
        self.statusCode = statusCode
    }
}

public protocol HTTPClient {
    func data(for request: URLRequest) async throws -> HTTPResponse
}

public enum HTTPClientError: Error, Equatable, LocalizedError {
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server response was invalid."
        }
    }
}

public final class URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> HTTPResponse {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPClientError.invalidResponse
        }
        return HTTPResponse(data: data, statusCode: httpResponse.statusCode)
    }
}
```

- [ ] **步骤 5：运行 package 解析和编译检查**

运行：

```bash
swift build
```

预期：PASS。

- [ ] **步骤 6：提交 package 骨架**

```bash
git add Package.swift Sources/APIInquiryCore
git commit -m "chore: add swift package skeleton and balance models"
```

---

### 任务 2：DeepSeek 余额供应商

**文件：**
- 创建：`Sources/APIInquiryCore/Providers/DeepSeekBalanceProvider.swift`
- 创建：`Sources/APIInquiryCoreTestsRunner/DeepSeekBalanceProviderTests.swift`
- 创建：`Sources/APIInquiryCoreTestsRunner/TestHarnessTests.swift`
- 修改：`Sources/APIInquiryCoreTestsRunner/TestHarness.swift`
- 必要时修改：`Sources/APIInquiryCoreTestsRunner/main.swift`，注册新的测试套件

- [ ] **步骤 1：在本地 runner 中编写失败的 provider 测试**

创建 `Sources/APIInquiryCoreTestsRunner/DeepSeekBalanceProviderTests.swift`，使用已有的 `TestHarness`，不要使用 XCTest。使用假 API Key 和 `MockHTTPClient` 覆盖以下行为：

- 多币种返回时优先选择 CNY。
- 没有 CNY 时回退到第一个返回币种。
- HTTP 401 映射为 `.authenticationFailed`。
- HTTP 429 映射为 `.rateLimited`。
- 非法 `total_balance` 映射为 `.invalidBalanceAmount(...)`，包括完全非数字字符串、`1.23abc` 这类尾随脏字符，以及 `1,234.56` 这类分组分隔符。
- 本地 `TestHarness` 在没有执行任何断言时必须失败，而不是报告 `PASS: 0 expectations`。

如果测试套件还没有被调用，需要从 `Sources/APIInquiryCoreTestsRunner/main.swift` 注册。

- [ ] **步骤 2：运行测试并确认红灯状态**

运行：

```bash
swift run APIInquiryCoreTestsRunner
```

预期：FAIL，因为 `DeepSeekBalanceProvider` 还不存在。

- [ ] **步骤 3：实现 DeepSeek provider**

创建 `Sources/APIInquiryCore/Providers/DeepSeekBalanceProvider.swift`，实现 `DeepSeekBalanceProvider: BalanceProvider`。它必须使用注入的 `HTTPClient`，默认发送 `GET https://api.deepseek.com/user/balance`，附加 `Authorization: Bearer <apiKey>`，解码 `is_available` 和 `balance_infos`，优先选择 CNY，缺少 CNY 时回退到第一个币种，保留可选赠金和充值余额，用 `Locale(identifier: "en_US_POSIX")` 解析 decimal，并按设计映射状态码和错误。

- [ ] **步骤 4：运行 provider 测试和构建**

运行：

```bash
swift run APIInquiryCoreTestsRunner
swift build
```

预期：两者都 PASS。

- [ ] **步骤 5：提交 provider 和 runner 测试**

```bash
git add Package.swift Sources/APIInquiryCore/Providers/DeepSeekBalanceProvider.swift Sources/APIInquiryCoreTestsRunner
git commit -m "feat: add deepseek balance provider"
```

---

### 任务 3：安全凭据存储

**文件：**
- 创建：`Sources/APIInquiryCore/Security/CredentialStore.swift`
- 创建：`Sources/APIInquiryCoreTestsRunner/KeychainCredentialStoreTests.swift`
- 修改：`Sources/APIInquiryCoreTestsRunner/main.swift`

- [ ] **步骤 1：添加失败的凭据存储 runner 测试**

添加 runner 测试，使用隔离的 Keychain service name 保存、读取、替换和删除假 API Key。使用本地 `TestHarness`，不要使用 XCTest 或真实 key。

- [ ] **步骤 2：确认红灯状态**

运行 `swift run APIInquiryCoreTestsRunner`。

预期：FAIL，因为 `KeychainCredentialStore` 还不存在。

- [ ] **步骤 3：实现凭据存储**

创建 `CredentialStore`、`CredentialStoreError`、`KeychainCredentialStore` 和 `InMemoryCredentialStore`。生产凭据只通过 macOS Keychain 存储；内存存储只用于测试和 view model 依赖注入。

- [ ] **步骤 4：确认绿灯状态并构建**

运行：

```bash
swift run APIInquiryCoreTestsRunner
swift build
```

预期：两者都 PASS。

- [ ] **步骤 5：提交凭据存储**

```bash
git add Sources/APIInquiryCore/Security Sources/APIInquiryCoreTestsRunner
git commit -m "feat: store api keys in keychain"
```

---

### 任务 4：刷新控制器与 ViewModel

**文件：**
- 创建：`Sources/APIInquiryCore/Refresh/BalanceRefreshController.swift`
- 创建：`Sources/APIInquiryCore/ViewModels/MenuBarBalanceViewModel.swift`
- 创建：`Sources/APIInquiryCoreTestsRunner/BalanceRefreshControllerTests.swift`
- 创建：`Sources/APIInquiryCoreTestsRunner/MenuBarBalanceViewModelTests.swift`
- 修改：`Sources/APIInquiryCoreTestsRunner/main.swift`

- [ ] **步骤 1：添加失败的刷新和 ViewModel runner 测试**

添加 runner 测试，覆盖缺少凭据、刷新成功、重叠刷新保护、失败时保留上次快照、已加载状态菜单标题格式化、已配置 key 但暂无余额时的占位标题、失败状态保留标题、面板余额文本、状态文本，以及保存/配置后清空 API Key 输入。只使用 mock provider 和假 key。

- [ ] **步骤 2：确认红灯状态**

运行 `swift run APIInquiryCoreTestsRunner`。

预期：FAIL，因为 `BalanceRefreshController` 和 `MenuBarBalanceViewModel` 还不存在。

- [ ] **步骤 3：实现刷新控制器**

实现 `@MainActor` observable controller：读取凭据、避免重叠刷新、保留最近一次成功快照、暴露 `BalanceState`、支持手动刷新、支持 300 秒自动刷新循环，并将错误映射为不暴露密钥的用户提示。

- [ ] **步骤 4：实现菜单栏 ViewModel**

实现菜单标题 `DS ¥68.6`、面板文本 `¥68.65 CNY`、设置/错误/状态文本、API Key 保存/更换/删除命令，以及到 `DeepSeekBalanceProvider` 和 `KeychainCredentialStore` 的生产 wiring。

- [ ] **步骤 5：确认绿灯状态并构建**

运行：

```bash
swift run APIInquiryCoreTestsRunner
swift build
```

预期：两者都 PASS。

- [ ] **步骤 6：提交刷新和 ViewModel**

```bash
git add Sources/APIInquiryCore/Refresh Sources/APIInquiryCore/ViewModels Sources/APIInquiryCoreTestsRunner
git commit -m "feat: coordinate balance refresh state"
```

---

### 任务 5：原生菜单栏 UI 与本地 App Bundle

**文件：**
- 修改：`Package.swift`
- 创建：`Sources/APIInquiryApp/APIInquiryApp.swift`
- 创建：`Sources/APIInquiryApp/MenuBarContentView.swift`
- 创建：`Scripts/build-local-app.sh`

- [ ] **步骤 1：添加 app executable target**

更新 `Package.swift`，保留 `APIInquiryCore` 和 `APIInquiryCoreTestsRunner`，并添加依赖 `APIInquiryCore` 的 executable product/target `APIInquiryApp`。

- [ ] **步骤 2：创建 SwiftUI 菜单栏应用**

创建 `APIInquiryApp.swift`，包含 `MenuBarExtra(viewModel.menuBarTitle)`、`.menuBarExtraStyle(.window)` 和 accessory activation policy。

- [ ] **步骤 3：创建极简展开面板**

创建 `MenuBarContentView.swift`，包含 DeepSeek 标识、大号余额、状态、最近刷新文本、刷新图标按钮、安全 API Key 输入、更换/删除 key、Open Console 和 Quit。保持极简，不添加图表。

- [ ] **步骤 4：创建本地 app bundle 脚本**

创建 `Scripts/build-local-app.sh`：运行 `swift build`，生成 `.build/APIInquiry.app`，复制可执行文件，并写入包含 `LSUIElement=true` 的 `Info.plist`。

- [ ] **步骤 5：验证 runner、构建和 app bundle**

运行：

```bash
swift run APIInquiryCoreTestsRunner
swift build
Scripts/build-local-app.sh
```

预期：runner 和 build 通过，脚本生成 `.build/APIInquiry.app`。

- [ ] **步骤 6：提交 app UI 和 bundle 脚本**

```bash
git add Package.swift Sources/APIInquiryApp Scripts/build-local-app.sh
git commit -m "feat: add native menu bar app"
```

---

### 任务 6：完整验证与手动运行说明

**文件：**
- 创建：`README.md`
- 创建：`README_zh.md`

- [ ] **步骤 1：创建英文 README**

记录运行要求、`swift run APIInquiryCoreTestsRunner`、`Scripts/build-local-app.sh`、生成的 `.build/APIInquiry.app`，以及 Keychain 安全行为。

- [ ] **步骤 2：创建中文 README**

创建语义同步的中文版本，包含相同命令和安全说明。

- [ ] **步骤 3：运行完整自动化验证**

运行：

```bash
swift run APIInquiryCoreTestsRunner
swift build
Scripts/build-local-app.sh
```

预期：所有命令通过。

- [ ] **步骤 4：启动进行手动测试**

运行：

```bash
open .build/APIInquiry.app
```

预期：macOS 启动菜单栏应用。如果 sandbox 阻止 `open`，请求批准。

- [ ] **步骤 5：完成手动检查**

检查无 key 设置状态、保存真实 key 到本机、菜单标题余额格式、面板余额格式、刷新按钮、更换/删除 key、控制台链接和退出。

- [ ] **步骤 6：提交 README 文件**

```bash
git add README.md README_zh.md
git commit -m "docs: add local run instructions"
```

- [ ] **步骤 7：交付前最终验证**

运行：

```bash
git status --short
swift run APIInquiryCoreTestsRunner
swift build
Scripts/build-local-app.sh
```

预期：

- `git status --short` 不输出已跟踪源码改动。
- `swift run APIInquiryCoreTestsRunner` 通过。
- `swift build` 通过。
- `Scripts/build-local-app.sh` 构建 `.build/APIInquiry.app`。

---

## 计划自检

- Spec 覆盖：仅余额的 DeepSeek 菜单栏应用、5 分钟刷新、手动刷新、Keychain 存储、极简面板、供应商抽象、第一版不做图表、本地源码交付物均已覆盖。
- 空洞内容扫描：计划使用精确文件、代码块、命令、预期结果和提交信息。
- 类型一致性：`ProviderID`、`BalanceSnapshot`、`BalanceState`、`BalanceProvider`、`HTTPClient`、`CredentialStore`、`BalanceRefreshController` 和 `MenuBarBalanceViewModel` 在各任务中命名一致。
