# DeepSeek 菜单栏余额监控设计

## 概要

构建一个名为 API Inquiry 的原生 macOS 菜单栏应用。第一版只聚焦一件事：使用 DeepSeek 官方 API 查询账号余额，并把余额常驻显示在 macOS 菜单栏中。

菜单栏标签以动态渲染的 DeepSeek template 图像加 `¥68.6` 这类紧凑余额文本为基础。展开面板显示极简的 DeepSeek 余额视图，标题区域使用可随浅色/深色外观自适应的单色 DeepSeek logo，包含手动刷新、状态、最近刷新时间、API Key 设置、外部控制台入口和退出。安装后的 `.app` 包含自定义苹果风格应用图标，该图标由本地资源生成，并以 `AppIcon.icns` 打包。详细用量图表、本地 DeepSeek 控制台、多供应商界面都延后处理。

## 目标

- 在 macOS 菜单栏直接显示 DeepSeek 账号余额。
- 每 5 分钟自动刷新余额，并支持手动刷新。
- 将 DeepSeek API Key 安全存储在 macOS Keychain 中。
- 展开面板保持极简、安静，第一版不做图表。
- 使用供应商抽象，方便后续接入其他 API 供应商而不重写界面。
- 第一阶段交付可在本机运行的源码项目，并提供本地 ad-hoc `.app` 打包；Developer ID 签名、公证和分发后续再做。

## 非目标

- 第一版不做月度用量图表。
- 第一版不抓取或自动化 DeepSeek 网页控制台。
- 第一版 UI 不展示充值余额或赠金余额，即使 API 数据模型会保留这些字段。
- 第一版 UI 不支持多个供应商切换。
- 第一版不构建本地 DeepSeek 控制台。
- 第一版不做公证或对外分发；本地 ad-hoc `.app` 打包包含在范围内。

## 平台与技术

- 平台：macOS 13 Ventura 及以上。
- 应用形态：原生 macOS 菜单栏应用。
- UI：SwiftUI 的 `MenuBarExtra`。
- 网络：`URLSession`。
- 安全存储：macOS Keychain。
- 数据源：DeepSeek 官方 API `GET https://api.deepseek.com/user/balance`。

## DeepSeek API 范围

DeepSeek 公开文档提供 `GET /user/balance`，返回：

- `is_available`
- `balance_infos[].currency`
- `balance_infos[].total_balance`
- `balance_infos[].granted_balance`
- `balance_infos[].topped_up_balance`

第一版只使用：

- `is_available`
- 优先选择 `CNY` 的余额记录；如果没有 `CNY`，回退到第一个返回的余额记录
- `total_balance`
- `currency`

应用会在解析模型中保留 `granted_balance` 和 `topped_up_balance`，为后续功能预留，但第一版 UI 不展示它们。

DeepSeek 公开 FAQ 对详细 API Key 用量的说明是：进入 Usage 页面选择月份后导出 CSV 文件。目前没有清晰公开的详细月用量查询 API，因此第一版不尝试自动刷新用量图表。

## 用户体验

### 首次启动

如果本机没有存储 DeepSeek API Key，菜单栏使用紧凑的未配置状态，例如 DeepSeek 图标加 `Setup`。

打开菜单后显示一个聚焦的设置面板：

- DeepSeek 标题
- API Key 安全输入框
- 保存按钮
- 校验或保存失败时的简短状态提示

API Key 只在用户输入时可见。保存后，常规 UI 不再以明文展示 API Key。当 key 已配置时，API Key 行默认折叠，只显示已配置状态和展开控件；展开后才显示更换输入框、Replace 和 Delete 控件。

### 常规菜单栏标签

基础菜单栏标签格式为：

```text
[DeepSeek 图标] ¥68.6
```

规则：

- 使用动态渲染的单色 template DeepSeek 图像替代 `DS` 文字前缀。
- 菜单栏图标大于金额文字，贴近常见 macOS 状态栏项目比例；金额文字使用 regular 字重，让标签保持轻盈。
- CNY 尽量使用人民币符号。
- 菜单栏显示一位小数，节省空间。
- 如果后续刷新失败，保留上一次成功获取的余额。
- 如果还没有成功获取过余额，显示 DeepSeek 图标加 `--`。

视图模型仍保留 `DS` 文本 fallback，用于测试和辅助场景；实际应用标签使用图标优先展示。

### 展开面板

展开面板应尽可能极简：

- 以 template 方式渲染的 DeepSeek logo 图片，自动适配浅色和深色外观
- 顶部 logo 尺寸进一步收紧，让余额成为视觉焦点
- 大号余额，例如 `¥68.65 CNY`，数字部分以 medium 字重占据明确视觉主导，货币符号和货币代码以更小的 regular 字重显示
- 小号状态行：
  - 可用
  - 余额不足
  - 未配置
  - 正在刷新
  - 刷新失败
- 最近一次成功刷新时间
- 刷新按钮，位置易触达但视觉上保持安静
- 次要操作：
  - 打开 DeepSeek 控制台 `https://platform.deepseek.com/usage`
  - 设置或更换 API Key
  - 删除 API Key
  - 退出

第一版展开面板不显示充值余额或赠金余额。

### App Bundle 图标

打包后的 app 使用自定义 macOS 图标，而不是默认可执行文件图标。

规则：

- 通过 `Scripts/generate-app-icon.swift` 生成图标，确保源资源、预览 PNG 和 `.icns` 可复现。
- 使用蓝色圆角 macOS 风格底板、干净的 DeepSeek 标识，以及小型用量柱状标记，让图标和 API 余额监控功能产生关联。
- 打包 `Sources/APIInquiryApp/Resources/AppIcon.icns`，并在 `Info.plist` 中将 `CFBundleIconFile` / `CFBundleIconName` 设置为 `AppIcon`。

## 架构

### 供应商抽象

定义供应商边界，让 DeepSeek 成为第一个供应商实现，而不是散落在全应用里的硬编码特例。

核心概念：

- `BalanceProvider`
  - 供应商 id
  - 展示名称
  - 菜单栏短前缀
  - 凭据 key 名称
  - 余额获取函数
- `BalanceSnapshot`
  - 供应商 id
  - 总余额
  - 货币
  - 可用状态
  - 可选赠金余额
  - 可选充值余额
  - 获取时间戳
- `BalanceState`
  - 未配置
  - 加载中
  - 已加载快照
  - 失败但有上次成功快照
  - 失败且没有快照

第一版只提供一个具体供应商：`DeepSeekBalanceProvider`。

### 应用服务

- `DeepSeekBalanceProvider`
  - 构建 `/user/balance` 请求
  - 附加 `Authorization: Bearer <api key>`
  - 解码响应
  - 将 API 错误映射为用户可理解的状态
- `KeychainCredentialStore`
  - 保存、读取、替换和删除 API Key
  - 绝不记录密钥明文
- `BalanceRefreshController`
  - 在启动、手动点击和 5 分钟定时器触发刷新
  - 避免并发重叠刷新
  - 失败时保留最近一次成功快照
- `MenuBarBalanceViewModel`
  - 格式化菜单栏标签
  - 暴露面板状态
  - 协调设置操作和刷新命令

### UI 组件

- `APIInquiryApp`
  - 应用入口
  - 持有 `MenuBarExtra`
- `MenuBarContentView`
  - 紧凑的展开面板
  - 在设置状态和余额状态之间切换
- `APIKeySettingsView`
  - 首次保存或更换时的输入视图
  - 保存后默认显示折叠的已配置行
  - 展开已配置行后显示更换和删除相关操作

## 数据流

1. 应用启动。
2. ViewModel 向 `KeychainCredentialStore` 读取 DeepSeek API Key。
3. 如果缺失，菜单栏显示设置状态。
4. 如果存在，应用立即刷新余额。
5. `DeepSeekBalanceProvider` 发送 `GET https://api.deepseek.com/user/balance`。
6. 响应被解码为 `BalanceSnapshot`。
7. ViewModel 更新菜单栏标签和展开面板。
8. 应用运行时，每 5 分钟定时刷新一次。
9. 手动刷新复用同一条刷新路径。
10. 刷新失败时，菜单栏保留上一次成功余额，并在展开面板显示错误状态。

## 错误处理

- 缺少 API Key：显示设置状态。
- API Key 无效或认证失败：显示清晰的“API Key 可能无效”提示，并提供更换/删除入口。
- 余额不足：显示余额，同时显示不可用状态。
- 网络失败：如果已有上次成功余额则保留；否则显示 DeepSeek 图标加 `--`。
- 非 JSON 或结构不匹配：显示刷新失败，并保留上次成功余额。
- 限速或服务器错误：显示刷新失败和简短的重试导向提示。

错误信息不得包含 API Key、Authorization 头或任何其他密钥内容。

## 安全要求

- API Key 只能存储在 macOS Keychain。
- 不得将 API Key 存储到 UserDefaults、日志、快照、崩溃信息或明文文件中。
- API Key 只在用户输入或更换时显示。
- 保存后，UI 默认只显示折叠的已配置状态，直到用户展开 API Key 行。
- 测试必须使用假 key，不能依赖真实 DeepSeek 账号。

## 测试计划

### 单元测试

- 解码成功的 DeepSeek 余额响应。
- 多币种返回时优先选择 CNY。
- 没有 CNY 时回退到第一个余额记录。
- 将菜单栏标签格式化为 DeepSeek 图标加 `¥68.6`。
- 将完整面板余额格式化为 `¥68.65 CNY`。
- 刷新失败时保留上次成功快照。
- 将缺少 key、key 无效、余额不足、网络失败和服务器失败映射到正确 UI 状态。
- 验证供应商抽象可以通过 mock provider 获取余额，且 UI 不与 DeepSeek 强耦合。

### Keychain 测试

- 保存假 API Key。
- 读取假 API Key。
- 替换假 API Key。
- 删除假 API Key。
- 确认 UI 展示状态不会返回完整保存 key。

### 集成测试

- 使用 mock `URLProtocol` 或可注入 HTTP client 模拟 DeepSeek 响应。
- 验证自动刷新可以通过刷新控制器触发，而不需要真实等待 5 分钟。
- 验证手动刷新和自动刷新复用同一条代码路径。

### 手动测试

- 在没有 API Key 的状态下启动。
- 本地保存真实 API Key。
- 确认菜单栏从设置状态切换为余额状态。
- 点击刷新并确认状态更新。
- 断开网络并确认最后一次成功余额仍然显示。
- 删除 API Key 并确认回到设置状态。
- 打开 DeepSeek 控制台链接。
- 从菜单中退出应用。

## 后续扩展

- 第一版稳定后，开发本地 DeepSeek 用量控制台。
- 支持导入 DeepSeek Usage 导出的 CSV。
- 在有稳定数据源后，增加月消费、请求次数和 tokens 图表。
- 基于现有供应商抽象接入更多 API 供应商。
- 增加可选的菜单栏显示样式配置。
- 增加 Developer ID 签名、公证和分发流程。

## 参考

- DeepSeek 余额 API：`https://api-docs.deepseek.com/zh-cn/api/get-user-balance`
- DeepSeek 用量导出 FAQ：`https://api-docs.deepseek.com/faq`

## 已确认决策

- 产品形态：macOS 菜单栏应用。
- 第一版供应商：仅 DeepSeek。
- 第一版数据：仅余额。
- 刷新频率：每 5 分钟自动刷新，并支持手动刷新。
- API Key 存储：仅 macOS Keychain。
- 最低系统：macOS 13 Ventura。
- 技术栈：Swift 和 SwiftUI。
- 第一阶段交付物：本地可运行源码项目。
