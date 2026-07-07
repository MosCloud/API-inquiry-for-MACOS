import APIInquiryCore
import Foundation

enum UsageConsoleViewModelTests {
    @MainActor
    static func run(using harness: TestHarness) async {
        testProviderSummariesExposeUnconfiguredProvider(using: harness)
        await testProviderSummariesExposeConfiguredActiveProvider(using: harness)
        await testProviderSummariesExposeChineseCopy(using: harness)
        await testProviderSummariesExposeAPIAccessCopy(using: harness)
        await testProviderSummariesExposeChineseAPIAccessCopy(using: harness)
        testProviderSummariesExposeUnconfiguredAPIAccessCopy(using: harness)
        testProviderSummariesExposeCodexConfigTarget(using: harness)
        await testProviderSummariesExposeInvalidProvider(using: harness)
        await testProviderSummariesExposeBalanceHealthToneBoundaries(using: harness)
        await testProviderSummariesExposePlanHealthToneBoundaries(using: harness)
        await testProviderSummariesAggregateQuotaHealthTone(using: harness)
        await testProviderSummariesExposeResourceBadgeCopy(using: harness)
        await testProviderSummariesKeepNonQuotaStatesNeutral(using: harness)
        await testSavingAPIKeyRefreshesBalance(using: harness)
        await testSavingAPIKeyUsesChineseFeedback(using: harness)
        await testSaveFailureKeepsInputAndDoesNotExposeKey(using: harness)
        await testConfirmingAPIKeyDeletionReturnsBalanceToSetup(using: harness)
        testRemovingUnmanagedCredentialProviderSkipsCredentialDeletion(using: harness)
        await testMultiProviderSummariesExposePrimaryAndPlanUsage(using: harness)
        await testMultiProviderSummariesExposeHealthTone(using: harness)
        testAddingProviderUpdatesAvailableProviderOptions(using: harness)
        testRemovingProviderShowsFeedbackWhenCredentialDeletionFails(using: harness)
        testRemovingProviderClearsProviderScopedAPIKeyInput(using: harness)
        await testSavingProviderScopedAPIKeyRefreshesOnlyThatProvider(using: harness)
        await testCodexSummaryExposesManualResetCredits(using: harness)
        testUnconfiguredCodexDoesNotExposeManualResetCredits(using: harness)
        await testCodexSummaryUsesFormatterTimezone(using: harness)
        testManualResetCredentialTrackingDoesNotUseHashValue(using: harness)
        await testCodexManualResetCreditsRefreshUsesCache(using: harness)
        await testCodexManualResetCreditsCacheTracksCredentialChanges(using: harness)
        await testCodexManualResetCreditsForceRefreshBypassesCache(using: harness)
        await testCodexManualResetCreditsRefreshDoesNotRefreshMainQuota(using: harness)
        await testCodexManualResetCreditsFailureKeepsPreviousSummary(using: harness)
        await testCodexManualResetCreditsRefreshReportsOutcome(using: harness)
        await testRemovingCodexClearsManualResetCreditsState(using: harness)
        await testInFlightManualResetRefreshDoesNotRestoreRemovedCodexState(using: harness)
        await testStaleManualResetRefreshDoesNotClearNewRefreshState(using: harness)
    }

    @MainActor
    private static func testCodexSummaryExposesManualResetCredits(using harness: TestHarness) async {
        let coordinator = makeCodexCoordinator(primaryProviderID: .codex)
        await coordinator.refresh(.codex)
        let now = isoDate("2026-07-01T00:00:00Z")
        let manualResetProvider = RecordingManualResetCreditsProvider(results: [
            .success(manualResetSnapshot(now: now, expiry: "2026-07-18T00:35:47Z")),
        ])
        let viewModel = UsageConsoleViewModel(
            coordinator: coordinator,
            credentialStore: InMemoryCredentialStore(credentialsByAccount: ["codex-session-token": "codex-token"]),
            manualResetCreditsProvider: manualResetProvider,
            now: { now }
        )

        await viewModel.refreshCodexManualResetCredits(force: true)

        let codexSummary = viewModel.providerSummaries.first { $0.id == .codex }
        harness.expectEqual(codexSummary?.balanceText, "5h 72% remg", "codex console detail")
        harness.expectEqual(codexSummary?.planNameText, nil, "codex console plan replaced")
        harness.expectEqual(codexSummary?.manualResetCreditsText, "1 · 07/18 expires", "codex console manual reset")
        harness.expectEqual(codexSummary?.isManualResetCreditsRefreshing, false, "codex manual reset not refreshing")
        harness.expectEqual(codexSummary?.validationStatusText, "Quota available", "codex console status")
        harness.expectEqual(codexSummary?.supportsAPIKeyManagement, false, "codex console hides api key management")
    }

    @MainActor
    private static func testUnconfiguredCodexDoesNotExposeManualResetCredits(using harness: TestHarness) {
        let credentialStore = InMemoryCredentialStore()
        let coordinator = makeCodexCoordinator(primaryProviderID: .codex, credentialStore: credentialStore)
        let viewModel = UsageConsoleViewModel(coordinator: coordinator, credentialStore: credentialStore)

        let codexSummary = viewModel.providerSummaries.first { $0.id == .codex }
        harness.expectEqual(codexSummary?.manualResetCreditsText, nil, "unconfigured codex hides manual reset summary")
        harness.expectEqual(codexSummary?.isManualResetCreditsRefreshing, false, "unconfigured codex hides manual reset refreshing state")
    }

    @MainActor
    private static func testCodexSummaryUsesFormatterTimezone(using harness: TestHarness) async {
        let coordinator = makeCodexCoordinator(primaryProviderID: .codex)
        await coordinator.refresh(.codex)
        let now = isoDate("2026-07-01T00:00:00Z")
        let manualResetProvider = RecordingManualResetCreditsProvider(results: [
            .success(manualResetSnapshot(now: now, expiry: "2026-07-18T00:35:47Z")),
        ])
        let viewModel = UsageConsoleViewModel(
            coordinator: coordinator,
            credentialStore: InMemoryCredentialStore(credentialsByAccount: ["codex-session-token": "codex-token"]),
            manualResetCreditsProvider: manualResetProvider,
            now: { now },
            lastRefreshTimeFormatter: LastRefreshTimeFormatter(
                locale: Locale(identifier: "en_US"),
                timeZone: TimeZone(identifier: "America/Los_Angeles")!
            )
        )

        await viewModel.refreshCodexManualResetCredits(force: true)

        let codexSummary = viewModel.providerSummaries.first { $0.id == .codex }
        harness.expectEqual(codexSummary?.manualResetCreditsText, "1 · 07/17 expires", "codex manual reset summary uses local timezone")
    }

    private static func testManualResetCredentialTrackingDoesNotUseHashValue(using harness: TestHarness) {
        let sourcePath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("APIInquiryCore")
            .appendingPathComponent("ViewModels")
            .appendingPathComponent("UsageConsoleViewModel.swift")
        let source = (try? String(contentsOf: sourcePath, encoding: .utf8)) ?? ""

        harness.expectTrue(
            !source.contains("hashValue"),
            "manual reset credential tracking does not use process-randomized hashValue"
        )
    }

    @MainActor
    private static func testCodexManualResetCreditsRefreshUsesCache(using harness: TestHarness) async {
        var now = isoDate("2026-07-01T00:00:00Z")
        let provider = RecordingManualResetCreditsProvider(results: [
            .success(manualResetSnapshot(now: now, expiry: "2026-07-18T00:35:47Z")),
            .success(manualResetSnapshot(now: now, expiry: "2026-07-27T00:44:20Z"))
        ])
        let viewModel = makeCodexManualResetViewModel(provider: provider, now: { now })

        await viewModel.refreshCodexManualResetCredits(force: false)
        await viewModel.refreshCodexManualResetCredits(force: false)

        harness.expectEqual(provider.fetchCount, 1, "manual reset cache prevents repeated fetch")

        now = now.addingTimeInterval(3_601)
        await viewModel.refreshCodexManualResetCredits(force: false)

        harness.expectEqual(provider.fetchCount, 2, "manual reset cache refreshes after ttl")
    }

    @MainActor
    private static func testCodexManualResetCreditsCacheTracksCredentialChanges(using harness: TestHarness) async {
        var now = isoDate("2026-07-01T00:00:00Z")
        let provider = RecordingManualResetCreditsProvider(results: [
            .success(manualResetSnapshot(now: now, expiry: "2026-07-18T00:35:47Z")),
            .success(manualResetSnapshot(now: now, expiry: "2026-07-27T00:44:20Z"))
        ])
        let credentialStore = InMemoryCredentialStore(credentialsByAccount: ["codex-session-token": "old-token"])
        let coordinator = makeCodexCoordinator(primaryProviderID: .codex, credentialStore: credentialStore)
        let viewModel = UsageConsoleViewModel(
            coordinator: coordinator,
            credentialStore: credentialStore,
            manualResetCreditsProvider: provider,
            now: { now }
        )

        await viewModel.refreshCodexManualResetCredits(force: false)
        try? credentialStore.saveCredential("new-token", forAccount: "codex-session-token")
        let staleSummary = viewModel.providerSummaries.first { $0.id == .codex }?.manualResetCreditsText
        now = now.addingTimeInterval(60)
        await viewModel.refreshCodexManualResetCredits(force: false)

        let codexSummary = viewModel.providerSummaries.first { $0.id == .codex }
        harness.expectEqual(staleSummary, "--", "manual reset summary hides cache after codex credential changes")
        harness.expectEqual(provider.fetchCount, 2, "manual reset cache misses after codex credential changes")
        harness.expectEqual(provider.lastAPIKey, "new-token", "manual reset refresh uses changed codex credential")
        harness.expectEqual(codexSummary?.manualResetCreditsText, "1 · 07/27 expires", "manual reset summary updates after credential change")
    }

    @MainActor
    private static func testCodexManualResetCreditsForceRefreshBypassesCache(using harness: TestHarness) async {
        let now = isoDate("2026-07-01T00:00:00Z")
        let provider = RecordingManualResetCreditsProvider(results: [
            .success(manualResetSnapshot(now: now, expiry: "2026-07-18T00:35:47Z")),
            .success(manualResetSnapshot(now: now, expiry: "2026-07-27T00:44:20Z"))
        ])
        let viewModel = makeCodexManualResetViewModel(provider: provider, now: { now })

        await viewModel.refreshCodexManualResetCredits(force: false)
        await viewModel.refreshCodexManualResetCredits(force: true)

        harness.expectEqual(provider.fetchCount, 2, "manual reset force refresh bypasses cache")
    }

    @MainActor
    private static func testCodexManualResetCreditsRefreshDoesNotRefreshMainQuota(using harness: TestHarness) async {
        let now = isoDate("2026-07-01T00:00:00Z")
        let codexProvider = MockBalanceProvider(
            id: .codex,
            results: [.success(.quotaUsage(makeCodexSnapshot()))]
        )
        let credentialStore = InMemoryCredentialStore(credentialsByAccount: ["codex-session-token": "codex-token"])
        let coordinator = MultiProviderBalanceCoordinator(
            registrations: [testRegistration(for: codexProvider)],
            credentialStore: credentialStore,
            preferences: InMemoryProviderPreferencesStore(addedProviderIDs: [.codex], primaryProviderID: .codex),
            defaultProviderID: .codex
        )
        let manualResetProvider = RecordingManualResetCreditsProvider(results: [
            .success(manualResetSnapshot(now: now, expiry: "2026-07-18T00:35:47Z"))
        ])
        let viewModel = UsageConsoleViewModel(
            coordinator: coordinator,
            credentialStore: credentialStore,
            manualResetCreditsProvider: manualResetProvider,
            now: { now }
        )

        await viewModel.refreshCodexManualResetCredits(force: true)

        harness.expectEqual(codexProvider.fetchCount, 0, "manual reset refresh does not refresh main quota")
        harness.expectEqual(manualResetProvider.fetchCount, 1, "manual reset provider is refreshed")
    }

    @MainActor
    private static func testCodexManualResetCreditsFailureKeepsPreviousSummary(using harness: TestHarness) async {
        let now = isoDate("2026-07-01T00:00:00Z")
        let provider = RecordingManualResetCreditsProvider(results: [
            .success(manualResetSnapshot(now: now, expiry: "2026-07-18T00:35:47Z")),
            .failure(BalanceProviderError.serverError(statusCode: 500))
        ])
        let viewModel = makeCodexManualResetViewModel(provider: provider, now: { now })

        await viewModel.refreshCodexManualResetCredits(force: true)
        await viewModel.refreshCodexManualResetCredits(force: true)

        let codexSummary = viewModel.providerSummaries.first { $0.id == .codex }
        harness.expectEqual(codexSummary?.manualResetCreditsText, "1 · 07/18 expires", "manual reset failure keeps cached summary")
        harness.expectEqual(provider.fetchCount, 2, "manual reset failure fetch count")
    }

    @MainActor
    private static func testCodexManualResetCreditsRefreshReportsOutcome(using harness: TestHarness) async {
        let now = isoDate("2026-07-01T00:00:00Z")
        let provider = RecordingManualResetCreditsProvider(results: [
            .success(manualResetSnapshot(now: now, expiry: "2026-07-18T00:35:47Z")),
            .failure(BalanceProviderError.serverError(statusCode: 500))
        ])
        let viewModel = makeCodexManualResetViewModel(provider: provider, now: { now })

        let success = await viewModel.refreshCodexManualResetCredits(force: true)
        let failure = await viewModel.refreshCodexManualResetCredits(force: true)

        harness.expectEqual(success, true, "manual reset refresh reports success")
        harness.expectEqual(failure, false, "manual reset refresh reports failure")
    }

    @MainActor
    private static func testRemovingCodexClearsManualResetCreditsState(using harness: TestHarness) async {
        let now = isoDate("2026-07-01T00:00:00Z")
        let provider = RecordingManualResetCreditsProvider(results: [
            .success(manualResetSnapshot(now: now, expiry: "2026-07-18T00:35:47Z"))
        ])
        let viewModel = makeCodexManualResetViewModel(provider: provider, now: { now })

        await viewModel.refreshCodexManualResetCredits(force: true)
        viewModel.removeProvider(.codex)
        viewModel.addProvider(.codex)

        harness.expectEqual(viewModel.codexManualResetCreditsState, .idle, "removing codex clears manual reset state")
        harness.expectEqual(
            viewModel.providerSummaries.first { $0.id == .codex }?.manualResetCreditsText,
            "--",
            "re-adding codex does not show stale manual reset summary"
        )
    }

    @MainActor
    private static func testInFlightManualResetRefreshDoesNotRestoreRemovedCodexState(using harness: TestHarness) async {
        let now = isoDate("2026-07-01T00:00:00Z")
        let provider = DelayedManualResetCreditsProvider()
        let viewModel = makeCodexManualResetViewModel(provider: provider, now: { now })

        let refreshTask = Task {
            await viewModel.refreshCodexManualResetCredits(force: true)
        }
        await provider.waitUntilStarted()
        viewModel.removeProvider(.codex)
        provider.complete(with: manualResetSnapshot(now: now, expiry: "2026-07-18T00:35:47Z"))
        let result = await refreshTask.value
        viewModel.addProvider(.codex)

        harness.expectEqual(result, false, "removed codex makes in-flight manual reset refresh stale")
        harness.expectEqual(viewModel.codexManualResetCreditsState, .idle, "stale manual reset refresh does not restore state")
        harness.expectEqual(
            viewModel.providerSummaries.first { $0.id == .codex }?.manualResetCreditsText,
            "--",
            "stale manual reset refresh does not restore summary"
        )
    }

    @MainActor
    private static func testStaleManualResetRefreshDoesNotClearNewRefreshState(using harness: TestHarness) async {
        let now = isoDate("2026-07-01T00:00:00Z")
        let provider = SequencedDelayedManualResetCreditsProvider()
        let credentialStore = InMemoryCredentialStore(credentialsByAccount: ["codex-session-token": "old-token"])
        let coordinator = makeCodexCoordinator(primaryProviderID: .codex, credentialStore: credentialStore)
        let viewModel = UsageConsoleViewModel(
            coordinator: coordinator,
            credentialStore: credentialStore,
            manualResetCreditsProvider: provider,
            now: { now }
        )

        let staleRefreshTask = Task {
            await viewModel.refreshCodexManualResetCredits(force: true)
        }
        await provider.waitUntilStarted(requestCount: 1)

        try? credentialStore.saveCredential("new-token", forAccount: "codex-session-token")
        let currentRefreshTask = Task {
            await viewModel.refreshCodexManualResetCredits(force: true)
        }
        await provider.waitUntilStarted(requestCount: 2)

        provider.completeRequest(
            at: 0,
            with: manualResetSnapshot(now: now, expiry: "2026-07-18T00:35:47Z")
        )
        let staleResult = await staleRefreshTask.value

        let refreshingSummary = viewModel.providerSummaries.first { $0.id == .codex }
        harness.expectEqual(staleResult, false, "stale manual reset refresh reports stale outcome")
        harness.expectEqual(
            refreshingSummary?.isManualResetCreditsRefreshing,
            true,
            "stale manual reset completion keeps current refresh active"
        )

        provider.completeRequest(
            at: 1,
            with: manualResetSnapshot(now: now, expiry: "2026-07-27T00:44:20Z")
        )
        let currentResult = await currentRefreshTask.value

        let completedSummary = viewModel.providerSummaries.first { $0.id == .codex }
        harness.expectEqual(currentResult, true, "current manual reset refresh succeeds")
        harness.expectEqual(
            completedSummary?.isManualResetCreditsRefreshing,
            false,
            "current manual reset completion clears refreshing state"
        )
        harness.expectEqual(
            completedSummary?.manualResetCreditsText,
            "1 · 07/27 expires",
            "current manual reset refresh owns final summary"
        )
    }

    @MainActor
    private static func testProviderSummariesExposeAPIAccessCopy(using harness: TestHarness) async {
        let credentialStore = InMemoryCredentialStore(credentialsByAccount: [
            "deepseek-api-key": "deepseek-key",
            "zhipu-coding-plan-api-key": "zhipu-key",
            "codex-session-token": "codex-token"
        ])
        let coordinator = makeAPIAccessCoordinator(credentialStore: credentialStore)
        let viewModel = UsageConsoleViewModel(coordinator: coordinator, credentialStore: credentialStore)

        let deepSeekSummary = viewModel.providerSummaries.first { $0.id == .deepseek }
        let zhipuSummary = viewModel.providerSummaries.first { $0.id == .zhipuCodingPlan }
        let codexSummary = viewModel.providerSummaries.first { $0.id == .codex }

        harness.expectEqual(deepSeekSummary?.apiAccessStatusText, "Configured", "deepseek api access status")
        harness.expectEqual(deepSeekSummary?.apiAccessState, .available, "deepseek configured api access state")
        harness.expectEqual(deepSeekSummary?.apiAccessPurposeText, "Available for prepaid balance checks", "deepseek api access purpose")
        harness.expectEqual(zhipuSummary?.apiAccessStatusText, "Configured", "zhipu api access status")
        harness.expectEqual(zhipuSummary?.apiAccessState, .available, "zhipu configured api access state")
        harness.expectEqual(zhipuSummary?.apiAccessPurposeText, "Available for plan balance checks", "zhipu api access purpose")
        harness.expectEqual(codexSummary?.apiAccessStatusText, "Loaded", "codex api access status")
        harness.expectEqual(codexSummary?.apiAccessState, .available, "codex loaded api access state")
        harness.expectEqual(codexSummary?.apiAccessPurposeText, "Available for plan balance checks", "codex api access purpose")
    }

    @MainActor
    private static func testProviderSummariesExposeChineseAPIAccessCopy(using harness: TestHarness) async {
        let credentialStore = InMemoryCredentialStore(credentialsByAccount: [
            "deepseek-api-key": "deepseek-key",
            "zhipu-coding-plan-api-key": "zhipu-key",
            "codex-session-token": "codex-token"
        ])
        let coordinator = makeAPIAccessCoordinator(credentialStore: credentialStore)
        let viewModel = UsageConsoleViewModel(
            coordinator: coordinator,
            credentialStore: credentialStore,
            languageStore: makeLanguageStore(selection: .zh)
        )

        let deepSeekSummary = viewModel.providerSummaries.first { $0.id == .deepseek }
        let zhipuSummary = viewModel.providerSummaries.first { $0.id == .zhipuCodingPlan }
        let codexSummary = viewModel.providerSummaries.first { $0.id == .codex }

        harness.expectEqual(deepSeekSummary?.apiAccessStatusText, "已配置", "chinese deepseek api access status")
        harness.expectEqual(deepSeekSummary?.apiAccessState, .available, "chinese deepseek api access state")
        harness.expectEqual(deepSeekSummary?.apiAccessPurposeText, "可用于充值余额查询", "chinese deepseek api access purpose")
        harness.expectEqual(zhipuSummary?.apiAccessStatusText, "已配置", "chinese zhipu api access status")
        harness.expectEqual(zhipuSummary?.apiAccessState, .available, "chinese zhipu api access state")
        harness.expectEqual(zhipuSummary?.apiAccessPurposeText, "可用于套餐余额查询", "chinese zhipu api access purpose")
        harness.expectEqual(codexSummary?.apiAccessStatusText, "已加载", "chinese codex api access status")
        harness.expectEqual(codexSummary?.apiAccessState, .available, "chinese codex api access state")
        harness.expectEqual(codexSummary?.apiAccessPurposeText, "可用于套餐余额查询", "chinese codex api access purpose")
    }

    @MainActor
    private static func testProviderSummariesExposeUnconfiguredAPIAccessCopy(using harness: TestHarness) {
        let coordinator = makeAPIAccessCoordinator(credentialStore: InMemoryCredentialStore())
        let viewModel = UsageConsoleViewModel(coordinator: coordinator, credentialStore: InMemoryCredentialStore())

        let deepSeekSummary = viewModel.providerSummaries.first { $0.id == .deepseek }
        let zhipuSummary = viewModel.providerSummaries.first { $0.id == .zhipuCodingPlan }
        let codexSummary = viewModel.providerSummaries.first { $0.id == .codex }

        harness.expectEqual(deepSeekSummary?.apiAccessStatusText, "Not configured", "deepseek unconfigured api access status")
        harness.expectEqual(deepSeekSummary?.apiAccessState, .unavailable, "deepseek unconfigured api access state")
        harness.expectEqual(deepSeekSummary?.apiAccessPurposeText, "Available for prepaid balance checks", "deepseek unconfigured api access purpose")
        harness.expectEqual(zhipuSummary?.apiAccessStatusText, "Not configured", "zhipu unconfigured api access status")
        harness.expectEqual(zhipuSummary?.apiAccessState, .unavailable, "zhipu unconfigured api access state")
        harness.expectEqual(zhipuSummary?.apiAccessPurposeText, "Available for plan balance checks", "zhipu unconfigured api access purpose")
        harness.expectEqual(codexSummary?.apiAccessStatusText, "Not loaded", "codex unloaded api access status")
        harness.expectEqual(codexSummary?.apiAccessState, .unavailable, "codex unloaded api access state")
        harness.expectEqual(codexSummary?.apiAccessPurposeText, "Available for plan balance checks", "codex unloaded api access purpose")
    }

    @MainActor
    private static func testProviderSummariesExposeCodexConfigTarget(using harness: TestHarness) {
        let authFileURL = writeTemporaryAuthFile(#"{"tokens":{"access_token":"test-access-token"}}"#)
        let credentialStore = CodexCredentialStore(
            delegate: InMemoryCredentialStore(credentialsByAccount: ["codex-session-token": "fallback-token"]),
            authFileURLs: [authFileURL]
        )
        let coordinator = makeAPIAccessCoordinator(credentialStore: credentialStore)
        let viewModel = UsageConsoleViewModel(coordinator: coordinator, credentialStore: credentialStore)

        let codexSummary = viewModel.providerSummaries.first { $0.id == .codex }

        harness.expectEqual(codexSummary?.codexConfigTargetURL, authFileURL, "codex summary exposes config target")

        removeTemporaryFile(authFileURL)
    }

    @MainActor
    private static func testMultiProviderSummariesExposePrimaryAndPlanUsage(using harness: TestHarness) async {
        let coordinator = makeMultiProviderCoordinator(primaryProviderID: .zhipuCodingPlan, resetAt: sampleResetDate)
        await coordinator.refreshAddedProviders()
        let viewModel = UsageConsoleViewModel(
            coordinator: coordinator,
            credentialStore: InMemoryCredentialStore(credentialsByAccount: [
                "deepseek-api-key": "deepseek-key",
                "zhipu-coding-plan-api-key": "zhipu-key"
            ]),
            lastRefreshTimeFormatter: fixedTimeFormatter
        )

        harness.expectEqual(viewModel.providerSummaries.count, 2, "multi console provider summary count")
        harness.expectEqual(viewModel.providerSummaries.first?.id, .deepseek, "multi console first provider id")
        harness.expectEqual(viewModel.providerSummaries.first?.planNextResetText, nil, "multi console deepseek plan next reset hidden")
        harness.expectEqual(viewModel.providerSummaries.last?.id, .zhipuCodingPlan, "multi console zhipu provider id")
        harness.expectEqual(viewModel.providerSummaries.last?.balanceText, "5h 17% used", "multi console zhipu usage text")
        harness.expectEqual(viewModel.providerSummaries.last?.planNextResetText, "Plan Next Resets: 23:05", "multi console zhipu plan next reset")
        harness.expectEqual(viewModel.providerSummaries.last?.validationStatusText, "Plan available", "multi console zhipu status")
        harness.expectEqual(viewModel.providerSummaries.first?.supportsAPIKeyManagement, true, "multi console deepseek supports key management")
        harness.expectEqual(viewModel.providerSummaries.last?.supportsAPIKeyManagement, true, "multi console zhipu supports key management")
        harness.expectTrue(viewModel.providerSummaries.last?.isPrimary == true, "multi console zhipu primary")
    }

    @MainActor
    private static func testMultiProviderSummariesExposeHealthTone(using harness: TestHarness) async {
        let coordinator = makeMultiProviderCoordinator(primaryProviderID: .zhipuCodingPlan, resetAt: sampleResetDate)
        await coordinator.refreshAddedProviders()
        let viewModel = UsageConsoleViewModel(
            coordinator: coordinator,
            credentialStore: InMemoryCredentialStore(credentialsByAccount: [
                "deepseek-api-key": "deepseek-key",
                "zhipu-coding-plan-api-key": "zhipu-key"
            ])
        )

        let deepSeekSummary = viewModel.providerSummaries.first { $0.id == .deepseek }
        let zhipuSummary = viewModel.providerSummaries.first { $0.id == .zhipuCodingPlan }
        harness.expectEqual(deepSeekSummary?.healthTone, .good, "multi console deepseek health tone")
        harness.expectEqual(zhipuSummary?.healthTone, .good, "multi console zhipu health tone")
    }

    @MainActor
    private static func testProviderSummariesExposeChineseCopy(using harness: TestHarness) async {
        let snapshot = makeSnapshot(total: "68.65")
        let provider = MockBalanceProvider(results: [.success(.balance(snapshot))])
        let credentialStore = InMemoryCredentialStore(credentialsByAccount: ["deepseek-api-key": "test-key"])
        let controller = makeTestRefreshController(provider: provider, credentialStore: credentialStore)
        let viewModel = UsageConsoleViewModel(
            provider: provider,
            credentialStore: credentialStore,
            controller: controller,
            languageStore: makeLanguageStore(selection: .zh)
        )

        await controller.refresh()

        harness.expectEqual(viewModel.providerSummaries.first?.apiKeyStatusText, "已配置", "chinese console configured key status")
        harness.expectEqual(viewModel.providerSummaries.first?.validationStatusText, "正常", "chinese console active status")
    }

    @MainActor
    private static func testAddingProviderUpdatesAvailableProviderOptions(using harness: TestHarness) {
        let coordinator = makeMultiProviderCoordinator(
            addedProviderIDs: [.deepseek],
            primaryProviderID: .deepseek
        )
        let viewModel = UsageConsoleViewModel(coordinator: coordinator, credentialStore: InMemoryCredentialStore())

        harness.expectEqual(viewModel.availableProviderIDsToAdd, [.zhipuCodingPlan], "console available provider before add")

        viewModel.addProvider(.zhipuCodingPlan)

        harness.expectEqual(viewModel.availableProviderIDsToAdd, [], "console available provider after add")
        harness.expectEqual(viewModel.providerSummaries.map(\.id), [.deepseek, .zhipuCodingPlan], "console summaries after add")
    }

    @MainActor
    private static func testRemovingProviderShowsFeedbackWhenCredentialDeletionFails(using harness: TestHarness) {
        let store = FailingDeleteCredentialStore(credentialsByAccount: ["zhipu-coding-plan-api-key": "test-key"])
        let coordinator = makeMultiProviderCoordinator(
            addedProviderIDs: [.deepseek, .zhipuCodingPlan],
            primaryProviderID: .deepseek,
            credentialStore: store
        )
        let viewModel = UsageConsoleViewModel(coordinator: coordinator, credentialStore: store)

        viewModel.removeProvider(.zhipuCodingPlan)

        harness.expectEqual(coordinator.addedProviderIDs, [.deepseek, .zhipuCodingPlan], "console keeps provider when remove key delete fails")
        harness.expectEqual(viewModel.settingsFeedback(for: .zhipuCodingPlan)?.kind, .error, "console remove failure feedback kind")
        harness.expectTrue(
            viewModel.settingsFeedback(for: .zhipuCodingPlan)?.message.isEmpty == false,
            "console remove failure feedback message"
        )
    }

    @MainActor
    private static func testRemovingProviderClearsProviderScopedAPIKeyInput(using harness: TestHarness) {
        let coordinator = makeMultiProviderCoordinator(
            addedProviderIDs: [.deepseek, .zhipuCodingPlan],
            primaryProviderID: .deepseek
        )
        let viewModel = UsageConsoleViewModel(coordinator: coordinator, credentialStore: InMemoryCredentialStore())
        viewModel.setAPIKeyInput("typed-zhipu-key", for: .zhipuCodingPlan)

        viewModel.removeProvider(.zhipuCodingPlan)
        viewModel.addProvider(.zhipuCodingPlan)

        harness.expectEqual(viewModel.apiKeyInput(for: .zhipuCodingPlan), "", "console remove clears provider-scoped api key input")
    }

    @MainActor
    private static func testRemovingUnmanagedCredentialProviderSkipsCredentialDeletion(using harness: TestHarness) {
        let store = FailingDeleteCredentialStore(credentialsByAccount: ["codex-session-token": "codex-token"])
        let deepSeek = MockBalanceProvider(
            id: .deepseek,
            results: []
        )
        let codex = MockBalanceProvider(
            id: .codex,
            results: []
        )
        let coordinator = MultiProviderBalanceCoordinator(
            registrations: testRegistrations(for: [deepSeek, codex]),
            credentialStore: store,
            preferences: InMemoryProviderPreferencesStore(addedProviderIDs: [.deepseek, .codex])
        )
        let viewModel = UsageConsoleViewModel(coordinator: coordinator, credentialStore: store)

        viewModel.removeProvider(.codex)

        harness.expectEqual(coordinator.addedProviderIDs, [.deepseek], "console removes unmanaged credential provider")
        harness.expectEqual(viewModel.settingsFeedback(for: .codex), nil, "console unmanaged credential removal has no delete feedback")
    }

    @MainActor
    private static func testSavingProviderScopedAPIKeyRefreshesOnlyThatProvider(using harness: TestHarness) async {
        let deepSeek = MockBalanceProvider(
            id: .deepseek,
            results: [.success(.balance(makeSnapshot(providerID: .deepseek, total: "68.65")))]
        )
        let zhipu = MockBalanceProvider(
            id: .zhipuCodingPlan,
            results: [.success(.planUsage(PlanUsageSnapshot(
                providerID: .zhipuCodingPlan,
                windowLabel: "5h",
                usagePercentage: Decimal(17),
                resetAt: nil,
                isAvailable: true,
                fetchedAt: Date(timeIntervalSince1970: 1_715_000_000)
            )))]
        )
        let store = InMemoryCredentialStore()
        let coordinator = MultiProviderBalanceCoordinator(
            registrations: testRegistrations(for: [deepSeek, zhipu]),
            credentialStore: store,
            preferences: InMemoryProviderPreferencesStore(addedProviderIDs: [.deepseek, .zhipuCodingPlan])
        )
        let viewModel = UsageConsoleViewModel(coordinator: coordinator, credentialStore: store)
        viewModel.setAPIKeyInput("zhipu-key", for: .zhipuCodingPlan)

        await viewModel.saveAPIKey(for: .zhipuCodingPlan)

        harness.expectEqual(try? store.credential(forAccount: "zhipu-coding-plan-api-key"), "zhipu-key", "console provider-scoped key saved")
        harness.expectEqual(zhipu.lastAPIKey, "zhipu-key", "console provider-scoped save refreshes zhipu")
        harness.expectEqual(deepSeek.fetchCount, 0, "console provider-scoped save does not refresh deepseek")
        harness.expectEqual(viewModel.apiKeyInput(for: .zhipuCodingPlan), "", "console provider-scoped input clears")
        harness.expectEqual(viewModel.settingsFeedback(for: .zhipuCodingPlan), SettingsFeedback(kind: .success, message: "Saved securely."), "console provider-scoped save feedback")
    }

    @MainActor
    private static func testProviderSummariesExposeUnconfiguredProvider(using harness: TestHarness) {
        let viewModel = makeViewModel()

        harness.expectEqual(viewModel.providerSummaries.count, 1, "console provider summary count")
        harness.expectEqual(viewModel.providerSummaries.first?.displayName, "DeepSeek", "console provider summary name")
        harness.expectEqual(
            viewModel.providerSummaries.first?.homepageURL,
            URL(string: "https://platform.deepseek.com/usage")!,
            "console provider homepage url"
        )
        harness.expectEqual(viewModel.providerSummaries.first?.apiKeyStatusText, "Not configured", "console provider key status")
        harness.expectEqual(viewModel.providerSummaries.first?.validationStatusText, "Not configured", "console provider validation status")
        harness.expectEqual(viewModel.providerSummaries.first?.statusTone, .neutral, "console unconfigured provider status tone")
        harness.expectEqual(viewModel.providerSummaries.first?.balanceText, "--", "console provider balance placeholder")
    }

    @MainActor
    private static func testProviderSummariesExposeConfiguredActiveProvider(using harness: TestHarness) async {
        let snapshot = makeSnapshot(total: "68.65")
        let provider = MockBalanceProvider(results: [.success(.balance(snapshot))])
        let credentialStore = InMemoryCredentialStore(credentialsByAccount: ["deepseek-api-key": "test-key"])
        let controller = makeTestRefreshController(provider: provider, credentialStore: credentialStore)
        let viewModel = UsageConsoleViewModel(
            provider: provider,
            credentialStore: credentialStore,
            controller: controller
        )

        await controller.refresh()

        harness.expectEqual(viewModel.providerSummaries.first?.apiKeyStatusText, "Configured", "console configured provider key status")
        harness.expectEqual(viewModel.providerSummaries.first?.validationStatusText, "Active", "console active provider validation status")
        harness.expectEqual(viewModel.providerSummaries.first?.statusTone, .success, "console active provider status tone")
        harness.expectEqual(viewModel.providerSummaries.first?.balanceText, "¥68.65 CNY", "console provider balance")
    }

    @MainActor
    private static func testProviderSummariesExposeInvalidProvider(using harness: TestHarness) async {
        let provider = MockBalanceProvider(results: [.failure(BalanceProviderError.authenticationFailed)])
        let credentialStore = InMemoryCredentialStore(credentialsByAccount: ["deepseek-api-key": "bad-key"])
        let controller = makeTestRefreshController(provider: provider, credentialStore: credentialStore)
        let viewModel = UsageConsoleViewModel(
            provider: provider,
            credentialStore: credentialStore,
            controller: controller
        )

        await controller.refresh()

        harness.expectEqual(viewModel.providerSummaries.first?.apiKeyStatusText, "Configured", "console invalid provider key status")
        harness.expectEqual(viewModel.providerSummaries.first?.validationStatusText, "Invalid", "console invalid provider validation status")
        harness.expectEqual(viewModel.providerSummaries.first?.statusTone, .neutral, "console invalid provider status tone")
    }

    @MainActor
    private static func testProviderSummariesExposeBalanceHealthToneBoundaries(using harness: TestHarness) async {
        let cases: [(String, ProviderAmountTone, String)] = [
            ("50", .good, "balance 50 is good"),
            ("49.99", .warning, "balance below 50 is warning"),
            ("10", .warning, "balance 10 is warning"),
            ("9.99", .critical, "balance below 10 is critical")
        ]

        for item in cases {
            let provider = MockBalanceProvider(results: [.success(.balance(makeSnapshot(total: item.0)))])
            let credentialStore = InMemoryCredentialStore(credentialsByAccount: ["deepseek-api-key": "test-key"])
            let controller = makeTestRefreshController(provider: provider, credentialStore: credentialStore)
            let viewModel = UsageConsoleViewModel(
                provider: provider,
                credentialStore: credentialStore,
                controller: controller
            )

            await controller.refresh()

            harness.expectEqual(viewModel.providerSummaries.first?.healthTone, item.1, item.2)
        }
    }

    @MainActor
    private static func testProviderSummariesExposePlanHealthToneBoundaries(using harness: TestHarness) async {
        let cases: [(Decimal, ProviderAmountTone, String)] = [
            (Decimal(40), .good, "plan usage 40 is good"),
            (Decimal(string: "40.01")!, .warning, "plan usage above 40 is warning"),
            (Decimal(80), .warning, "plan usage 80 is warning"),
            (Decimal(string: "80.01")!, .critical, "plan usage above 80 is critical")
        ]

        for item in cases {
            let provider = MockBalanceProvider(
                id: .zhipuCodingPlan,
                results: [.success(.planUsage(PlanUsageSnapshot(
                    providerID: .zhipuCodingPlan,
                    windowLabel: "5h",
                    usagePercentage: item.0,
                    resetAt: nil,
                    isAvailable: item.0 < Decimal(100),
                    fetchedAt: Date(timeIntervalSince1970: 1_715_000_000)
                )))]
            )
            let credentialStore = InMemoryCredentialStore(credentialsByAccount: ["zhipu-coding-plan-api-key": "test-key"])
            let controller = makeTestRefreshController(provider: provider, credentialStore: credentialStore)
            let viewModel = UsageConsoleViewModel(
                provider: provider,
                credentialStore: credentialStore,
                controller: controller
            )

            await controller.refresh()

            harness.expectEqual(viewModel.providerSummaries.first?.healthTone, item.1, item.2)
        }
    }

    @MainActor
    private static func testProviderSummariesAggregateQuotaHealthTone(using harness: TestHarness) async {
        let provider = MockBalanceProvider(
            id: .codex,
            results: [.success(.quotaUsage(QuotaUsageSnapshot(
                providerID: .codex,
                planName: "Plus",
                windows: [
                    QuotaWindowSnapshot(label: "5h", remainingPercentage: Decimal(63), resetAt: nil, isAvailable: true),
                    QuotaWindowSnapshot(label: "Week", remainingPercentage: Decimal(18), resetAt: nil, isAvailable: true)
                ],
                fetchedAt: Date(timeIntervalSince1970: 1_715_000_000)
            )))]
        )
        let credentialStore = InMemoryCredentialStore(credentialsByAccount: ["codex-session-token": "test-token"])
        let controller = makeTestRefreshController(provider: provider, credentialStore: credentialStore)
        let viewModel = UsageConsoleViewModel(provider: provider, credentialStore: credentialStore, controller: controller)

        await controller.refresh()

        harness.expectEqual(viewModel.providerSummaries.first?.healthTone, .critical, "quota summary uses most urgent window")

        let boundaryProvider = MockBalanceProvider(
            id: .codex,
            results: [.success(.quotaUsage(QuotaUsageSnapshot(
                providerID: .codex,
                planName: "Plus",
                windows: [
                    QuotaWindowSnapshot(label: "5h", remainingPercentage: Decimal(60), resetAt: nil, isAvailable: true),
                    QuotaWindowSnapshot(label: "Window 1", remainingPercentage: Decimal(59), resetAt: nil, isAvailable: true),
                    QuotaWindowSnapshot(label: "Window 2", remainingPercentage: Decimal(20), resetAt: nil, isAvailable: true),
                    QuotaWindowSnapshot(label: "Window 3", remainingPercentage: Decimal(19), resetAt: nil, isAvailable: true)
                ],
                fetchedAt: Date(timeIntervalSince1970: 1_715_000_000)
            )))]
        )
        let boundaryStore = InMemoryCredentialStore(credentialsByAccount: ["codex-session-token": "test-token"])
        let boundaryController = makeTestRefreshController(provider: boundaryProvider, credentialStore: boundaryStore)
        let boundaryViewModel = UsageConsoleViewModel(provider: boundaryProvider, credentialStore: boundaryStore, controller: boundaryController)

        await boundaryController.refresh()

        harness.expectEqual(boundaryViewModel.providerSummaries.first?.healthTone, .critical, "quota summary aggregates boundary tones")
    }

    @MainActor
    private static func testProviderSummariesExposeResourceBadgeCopy(using harness: TestHarness) async {
        let balanceCases: [(String, String, String)] = [
            ("68.65", "Balance Sufficient", "余额充足"),
            ("20", "Balance Low", "余额偏低"),
            ("5", "Balance Critical", "余额告急")
        ]

        for item in balanceCases {
            let provider = MockBalanceProvider(results: [.success(.balance(makeSnapshot(total: item.0)))])
            let credentialStore = InMemoryCredentialStore(credentialsByAccount: ["deepseek-api-key": "test-key"])
            let controller = makeTestRefreshController(provider: provider, credentialStore: credentialStore)
            let englishViewModel = UsageConsoleViewModel(
                provider: provider,
                credentialStore: credentialStore,
                controller: controller
            )
            let chineseViewModel = UsageConsoleViewModel(
                provider: provider,
                credentialStore: credentialStore,
                controller: controller,
                languageStore: makeLanguageStore(selection: .zh)
            )

            await controller.refresh()

            harness.expectEqual(englishViewModel.providerSummaries.first?.summaryBadgeText, item.1, "english balance badge \(item.0)")
            harness.expectEqual(chineseViewModel.providerSummaries.first?.summaryBadgeText, item.2, "chinese balance badge \(item.0)")
            harness.expectEqual(englishViewModel.providerSummaries.first?.validationStatusText, "Active", "balance status metric stays service status")
        }

        let planCases: [(Decimal, String)] = [
            (Decimal(17), "额度充足"),
            (Decimal(60), "额度偏低"),
            (Decimal(90), "额度告急")
        ]

        for item in planCases {
            let provider = MockBalanceProvider(
                id: .zhipuCodingPlan,
                results: [.success(.planUsage(PlanUsageSnapshot(
                    providerID: .zhipuCodingPlan,
                    windowLabel: "5h",
                    usagePercentage: item.0,
                    resetAt: nil,
                    isAvailable: true,
                    fetchedAt: Date(timeIntervalSince1970: 1_715_000_000)
                )))]
            )
            let credentialStore = InMemoryCredentialStore(credentialsByAccount: ["zhipu-coding-plan-api-key": "test-key"])
            let controller = makeTestRefreshController(provider: provider, credentialStore: credentialStore)
            let viewModel = UsageConsoleViewModel(
                provider: provider,
                credentialStore: credentialStore,
                controller: controller,
                languageStore: makeLanguageStore(selection: .zh)
            )

            await controller.refresh()

            harness.expectEqual(viewModel.providerSummaries.first?.summaryBadgeText, item.1, "chinese plan badge \(item.0)")
            harness.expectEqual(viewModel.providerSummaries.first?.validationStatusText, "计划可用", "plan status metric stays service status")
        }

        let codexCoordinator = makeCodexCoordinator(primaryProviderID: .codex)
        await codexCoordinator.refresh(.codex)
        let codexViewModel = UsageConsoleViewModel(
            coordinator: codexCoordinator,
            credentialStore: InMemoryCredentialStore(credentialsByAccount: ["codex-session-token": "codex-token"]),
            languageStore: makeLanguageStore(selection: .zh)
        )

        harness.expectEqual(codexViewModel.providerSummaries.first?.summaryBadgeText, "额度偏低", "chinese quota badge uses quota copy")
        harness.expectEqual(codexViewModel.providerSummaries.first?.validationStatusText, "额度可用", "quota status metric stays service status")
    }

    @MainActor
    private static func testProviderSummariesKeepNonQuotaStatesNeutral(using harness: TestHarness) async {
        let unconfigured = makeViewModel()
        harness.expectEqual(unconfigured.providerSummaries.first?.healthTone, .neutral, "unconfigured summary health neutral")

        let loadingProvider = MockBalanceProvider(results: [])
        let loadingStore = InMemoryCredentialStore(credentialsByAccount: ["deepseek-api-key": "test-key"])
        let loadingController = makeTestRefreshController(
            provider: loadingProvider,
            credentialStore: loadingStore,
            initialState: .loading(last: nil)
        )
        let loadingViewModel = UsageConsoleViewModel(
            provider: loadingProvider,
            credentialStore: loadingStore,
            controller: loadingController
        )
        harness.expectEqual(loadingViewModel.providerSummaries.first?.healthTone, .neutral, "loading without snapshot summary health neutral")

        let loadingWithLastController = makeTestRefreshController(
            provider: loadingProvider,
            credentialStore: loadingStore,
            initialState: .loading(last: .balance(makeSnapshot(total: "68.65")))
        )
        let loadingWithLastViewModel = UsageConsoleViewModel(
            provider: loadingProvider,
            credentialStore: loadingStore,
            controller: loadingWithLastController
        )
        harness.expectEqual(loadingWithLastViewModel.providerSummaries.first?.healthTone, .neutral, "loading with snapshot summary health neutral")

        let invalidProvider = MockBalanceProvider(results: [.failure(BalanceProviderError.authenticationFailed)])
        let invalidStore = InMemoryCredentialStore(credentialsByAccount: ["deepseek-api-key": "bad-key"])
        let invalidController = makeTestRefreshController(provider: invalidProvider, credentialStore: invalidStore)
        let invalidViewModel = UsageConsoleViewModel(
            provider: invalidProvider,
            credentialStore: invalidStore,
            controller: invalidController
        )
        await invalidController.refresh()
        harness.expectEqual(invalidViewModel.providerSummaries.first?.healthTone, .neutral, "auth failure summary health neutral")
        harness.expectEqual(invalidViewModel.providerSummaries.first?.statusTone, .neutral, "auth failure summary status neutral")

        let unavailableController = makeTestRefreshController(
            provider: loadingProvider,
            credentialStore: loadingStore,
            initialState: .failed(
                message: "Network unavailable.",
                kind: .networkUnavailable,
                last: .balance(makeSnapshot(total: "68.65"))
            )
        )
        let unavailableViewModel = UsageConsoleViewModel(
            provider: loadingProvider,
            credentialStore: loadingStore,
            controller: unavailableController
        )
        harness.expectEqual(unavailableViewModel.providerSummaries.first?.healthTone, .neutral, "unavailable failure with snapshot summary health neutral")
        harness.expectEqual(unavailableViewModel.providerSummaries.first?.statusTone, .neutral, "unavailable failure summary status neutral")

        let limitReachedController = makeTestRefreshController(
            provider: loadingProvider,
            credentialStore: loadingStore,
            initialState: .failed(
                message: "Limit reached.",
                kind: .usageLimitReached,
                last: .planUsage(PlanUsageSnapshot(
                    providerID: .zhipuCodingPlan,
                    windowLabel: "5h",
                    usagePercentage: Decimal(100),
                    resetAt: nil,
                    isAvailable: false,
                    fetchedAt: Date(timeIntervalSince1970: 1_715_000_000)
                ))
            )
        )
        let limitReachedViewModel = UsageConsoleViewModel(
            provider: loadingProvider,
            credentialStore: loadingStore,
            controller: limitReachedController
        )
        harness.expectEqual(limitReachedViewModel.providerSummaries.first?.statusTone, .warning, "usage limit failure summary status warning")

        let planExpiredController = makeTestRefreshController(
            provider: loadingProvider,
            credentialStore: loadingStore,
            initialState: .failed(
                message: "Plan expired.",
                kind: .planExpired,
                last: nil
            )
        )
        let planExpiredViewModel = UsageConsoleViewModel(
            provider: loadingProvider,
            credentialStore: loadingStore,
            controller: planExpiredController
        )
        harness.expectEqual(planExpiredViewModel.providerSummaries.first?.statusTone, .warning, "plan expired failure summary status warning")
    }

    @MainActor
    private static func testSavingAPIKeyRefreshesBalance(using harness: TestHarness) async {
        let snapshot = makeSnapshot(total: "68.65")
        let provider = MockBalanceProvider(results: [.success(.balance(snapshot))])
        let credentialStore = InMemoryCredentialStore()
        let controller = makeTestRefreshController(provider: provider, credentialStore: credentialStore)
        let viewModel = UsageConsoleViewModel(
            provider: provider,
            credentialStore: credentialStore,
            controller: controller
        )
        viewModel.apiKeyInput = "test-key"

        await viewModel.saveAPIKey()

        harness.expectEqual(viewModel.apiKeyInput, "", "console api key input clears")
        harness.expectEqual(try? credentialStore.credential(forAccount: "deepseek-api-key"), "test-key", "console api key saved")
        harness.expectEqual(provider.lastAPIKey, "test-key", "console save refreshes balance")
        harness.expectEqual(viewModel.credentialStatusText, "Configured", "console credential configured")
        harness.expectEqual(viewModel.settingsFeedback, SettingsFeedback(kind: .success, message: "Saved securely."), "console save feedback")
    }

    @MainActor
    private static func testSavingAPIKeyUsesChineseFeedback(using harness: TestHarness) async {
        let snapshot = makeSnapshot(total: "68.65")
        let provider = MockBalanceProvider(results: [.success(.balance(snapshot))])
        let credentialStore = InMemoryCredentialStore()
        let controller = makeTestRefreshController(provider: provider, credentialStore: credentialStore)
        let viewModel = UsageConsoleViewModel(
            provider: provider,
            credentialStore: credentialStore,
            controller: controller,
            languageStore: makeLanguageStore(selection: .zh)
        )
        viewModel.apiKeyInput = "test-key"

        await viewModel.saveAPIKey()

        harness.expectEqual(viewModel.credentialStatusText, "已配置", "chinese console credential configured")
        harness.expectEqual(viewModel.settingsFeedback, SettingsFeedback(kind: .success, message: "已安全保存。"), "chinese console save feedback")
    }

    @MainActor
    private static func testSaveFailureKeepsInputAndDoesNotExposeKey(using harness: TestHarness) async {
        let provider = MockBalanceProvider(results: [.failure(BalanceProviderError.authenticationFailed)])
        let credentialStore = InMemoryCredentialStore()
        let controller = makeTestRefreshController(provider: provider, credentialStore: credentialStore)
        let viewModel = UsageConsoleViewModel(
            provider: provider,
            credentialStore: credentialStore,
            controller: controller
        )
        viewModel.apiKeyInput = "bad-key"

        await viewModel.saveAPIKey()

        harness.expectEqual(viewModel.apiKeyInput, "bad-key", "console save failure keeps input")
        harness.expectEqual(viewModel.settingsFeedback?.kind, .warning, "console save failure warning")
        harness.expectTrue(
            viewModel.settingsFeedback?.message.contains("bad-key") == false,
            "console save failure does not expose key"
        )
    }

    @MainActor
    private static func testConfirmingAPIKeyDeletionReturnsBalanceToSetup(using harness: TestHarness) async {
        let credentialStore = InMemoryCredentialStore(credentialsByAccount: ["deepseek-api-key": "test-key"])
        let provider = MockBalanceProvider(results: [.success(.balance(makeSnapshot(total: "68.65")))])
        let controller = makeTestRefreshController(provider: provider, credentialStore: credentialStore)
        let viewModel = UsageConsoleViewModel(
            provider: provider,
            credentialStore: credentialStore,
            controller: controller
        )

        await controller.refresh()
        viewModel.requestAPIKeyDeletion()
        await viewModel.confirmAPIKeyDeletion()

        harness.expectEqual(try? credentialStore.credential(forAccount: "deepseek-api-key"), nil, "console delete removes key")
        harness.expectEqual(viewModel.credentialStatusText, "Not configured", "console delete updates credential status")
        harness.expectEqual(controller.state, .notConfigured, "console delete marks balance not configured")
    }

    @MainActor
    private static func makeViewModel(
        credentialStore: CredentialStore = InMemoryCredentialStore(),
        languageSelection: AppLanguage = .en
    ) -> UsageConsoleViewModel {
        let provider = MockBalanceProvider(results: [])
        let controller = makeTestRefreshController(provider: provider, credentialStore: credentialStore)
        return UsageConsoleViewModel(
            provider: provider,
            credentialStore: credentialStore,
            controller: controller,
            languageStore: makeLanguageStore(selection: languageSelection)
        )
    }

    private static func makeLanguageStore(selection: AppLanguage) -> AppLanguageStore {
        let defaults = UserDefaults(suiteName: "APIInquiry.UsageConsoleViewModelTests.\(UUID().uuidString)")!
        let store = AppLanguageStore(userDefaults: defaults, preferredLanguages: { ["en-US"] })
        store.selection = selection
        return store
    }

    @MainActor
    private static func makeMultiProviderCoordinator(
        addedProviderIDs: [ProviderID] = [.deepseek, .zhipuCodingPlan],
        primaryProviderID: ProviderID,
        resetAt: Date? = nil,
        credentialStore: CredentialStore = InMemoryCredentialStore(credentialsByAccount: [
            "deepseek-api-key": "deepseek-key",
            "zhipu-coding-plan-api-key": "zhipu-key"
        ])
    ) -> MultiProviderBalanceCoordinator {
        let deepSeekSnapshot = makeSnapshot(providerID: .deepseek, total: "68.65")
        let zhipuSnapshot = PlanUsageSnapshot(
            providerID: .zhipuCodingPlan,
            windowLabel: "5h",
            usagePercentage: Decimal(17),
            resetAt: resetAt,
            isAvailable: true,
            fetchedAt: Date(timeIntervalSince1970: 1_715_000_000)
        )
        return MultiProviderBalanceCoordinator(
            registrations: testRegistrations(for: [
                MockBalanceProvider(
                    id: .deepseek,
                    results: [.success(.balance(deepSeekSnapshot))]
                ),
                MockBalanceProvider(
                    id: .zhipuCodingPlan,
                    results: [.success(.planUsage(zhipuSnapshot))]
                )
            ]),
            credentialStore: credentialStore,
            preferences: InMemoryProviderPreferencesStore(
                addedProviderIDs: addedProviderIDs,
                primaryProviderID: primaryProviderID
            )
        )
    }

    @MainActor
    private static func makeCodexCoordinator(primaryProviderID: ProviderID) -> MultiProviderBalanceCoordinator {
        makeCodexCoordinator(
            primaryProviderID: primaryProviderID,
            credentialStore: InMemoryCredentialStore(credentialsByAccount: ["codex-session-token": "codex-token"])
        )
    }

    @MainActor
    private static func makeCodexCoordinator(
        primaryProviderID: ProviderID,
        credentialStore: CredentialStore
    ) -> MultiProviderBalanceCoordinator {
        MultiProviderBalanceCoordinator(
            registrations: testRegistrations(for: [
                MockBalanceProvider(
                    id: .codex,
                    results: [.success(.quotaUsage(makeCodexSnapshot()))]
                )
            ]),
            credentialStore: credentialStore,
            preferences: InMemoryProviderPreferencesStore(
                addedProviderIDs: [.codex],
                primaryProviderID: primaryProviderID
            )
        )
    }

    @MainActor
    private static func makeCodexManualResetViewModel(
        provider: CodexManualResetCreditsProviding,
        now: @escaping () -> Date
    ) -> UsageConsoleViewModel {
        let credentialStore = InMemoryCredentialStore(credentialsByAccount: ["codex-session-token": "codex-token"])
        let coordinator = makeCodexCoordinator(primaryProviderID: .codex, credentialStore: credentialStore)
        return UsageConsoleViewModel(
            coordinator: coordinator,
            credentialStore: credentialStore,
            manualResetCreditsProvider: provider,
            now: now
        )
    }

    private static func makeCodexSnapshot() -> QuotaUsageSnapshot {
        QuotaUsageSnapshot(
            providerID: .codex,
            planName: "Plus",
            windows: [
                QuotaWindowSnapshot(
                    label: "5h",
                    remainingPercentage: Decimal(72),
                    resetAt: nil,
                    isAvailable: true
                ),
                QuotaWindowSnapshot(
                    label: "Week",
                    remainingPercentage: Decimal(48),
                    resetAt: nil,
                    isAvailable: true
                )
            ],
            fetchedAt: Date(timeIntervalSince1970: 1_715_000_000)
        )
    }

    private static func manualResetSnapshot(now: Date, expiry: String) -> CodexManualResetCreditsSnapshot {
        CodexManualResetCreditsSnapshot(
            credits: [
                CodexManualResetCredit(
                    grantedAt: now,
                    expiresAt: isoDate(expiry),
                    redeemedAt: nil
                )
            ],
            fetchedAt: now
        )
    }

    private static func isoDate(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    @MainActor
    private static func makeAPIAccessCoordinator(credentialStore: CredentialStore) -> MultiProviderBalanceCoordinator {
        MultiProviderBalanceCoordinator(
            registrations: testRegistrations(for: [
                MockBalanceProvider(
                    id: .deepseek,
                    results: []
                ),
                MockBalanceProvider(
                    id: .zhipuCodingPlan,
                    results: []
                ),
                MockBalanceProvider(
                    id: .codex,
                    results: []
                )
            ]),
            credentialStore: credentialStore,
            preferences: InMemoryProviderPreferencesStore(
                addedProviderIDs: [.deepseek, .zhipuCodingPlan, .codex],
                primaryProviderID: .deepseek
            )
        )
    }

    private static var fixedTimeFormatter: LastRefreshTimeFormatter {
        LastRefreshTimeFormatter(
            locale: Locale(identifier: "en_GB"),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )
    }

    private static var sampleResetDate: Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = 5
        components.day = 15
        components.hour = 23
        components.minute = 5
        return components.date!
    }

    private static func writeTemporaryAuthFile(_ contents: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "api-inquiry-console-codex-auth-\(UUID().uuidString).json")
        try? contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func removeTemporaryFile(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}

private final class FailingDeleteCredentialStore: CredentialStore {
    private var credentialsByAccount: [String: String]

    init(credentialsByAccount: [String: String]) {
        self.credentialsByAccount = credentialsByAccount
    }

    func credential(forAccount account: String) throws -> String? {
        credentialsByAccount[account]
    }

    func saveCredential(_ credential: String, forAccount account: String) throws {
        credentialsByAccount[account] = credential
    }

    func deleteCredential(forAccount account: String) throws {
        throw CredentialStoreError.unexpectedStatus(-1)
    }
}

private final class RecordingManualResetCreditsProvider: CodexManualResetCreditsProviding {
    private var results: [Result<CodexManualResetCreditsSnapshot, Error>]
    private(set) var fetchCount = 0
    private(set) var lastAPIKey: String?

    init(results: [Result<CodexManualResetCreditsSnapshot, Error>]) {
        self.results = results
    }

    func fetchSnapshot(apiKey: String) async throws -> CodexManualResetCreditsSnapshot {
        fetchCount += 1
        lastAPIKey = apiKey

        guard !results.isEmpty else {
            throw BalanceProviderError.missingBalanceInfo
        }
        return try results.removeFirst().get()
    }
}

private final class DelayedManualResetCreditsProvider: CodexManualResetCreditsProviding {
    private var continuation: CheckedContinuation<CodexManualResetCreditsSnapshot, Error>?
    private var startedContinuation: CheckedContinuation<Void, Never>?
    private var hasStarted = false

    func fetchSnapshot(apiKey: String) async throws -> CodexManualResetCreditsSnapshot {
        hasStarted = true
        startedContinuation?.resume()
        startedContinuation = nil

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func waitUntilStarted() async {
        if hasStarted {
            return
        }

        await withCheckedContinuation { continuation in
            self.startedContinuation = continuation
        }
    }

    func complete(with snapshot: CodexManualResetCreditsSnapshot) {
        continuation?.resume(returning: snapshot)
        continuation = nil
    }
}

private final class SequencedDelayedManualResetCreditsProvider: CodexManualResetCreditsProviding {
    private var continuations: [CheckedContinuation<CodexManualResetCreditsSnapshot, Error>?] = []
    private var startedContinuations: [(requestCount: Int, continuation: CheckedContinuation<Void, Never>)] = []

    func fetchSnapshot(apiKey: String) async throws -> CodexManualResetCreditsSnapshot {
        try await withCheckedThrowingContinuation { continuation in
            continuations.append(continuation)
            resumeStartedContinuations()
        }
    }

    func waitUntilStarted(requestCount: Int) async {
        if continuations.count >= requestCount {
            return
        }

        await withCheckedContinuation { continuation in
            startedContinuations.append((requestCount: requestCount, continuation: continuation))
        }
    }

    func completeRequest(at index: Int, with snapshot: CodexManualResetCreditsSnapshot) {
        guard continuations.indices.contains(index),
              let continuation = continuations[index] else {
            return
        }

        continuations[index] = nil
        continuation.resume(returning: snapshot)
    }

    private func resumeStartedContinuations() {
        let readyContinuations = startedContinuations.filter { continuations.count >= $0.requestCount }
        startedContinuations.removeAll { continuations.count >= $0.requestCount }
        for waiter in readyContinuations {
            waiter.continuation.resume()
        }
    }
}
