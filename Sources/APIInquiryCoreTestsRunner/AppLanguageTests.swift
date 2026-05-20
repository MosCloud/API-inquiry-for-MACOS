import APIInquiryCore
import Combine
import Foundation

enum AppLanguageTests {
    static func run(using harness: TestHarness) {
        testRawValuesAndDefault(using: harness)
        testAutoResolvesChinesePreferredLanguages(using: harness)
        testAutoResolvesNonChinesePreferredLanguagesToEnglish(using: harness)
        testManualLanguageOverridesSystemLanguages(using: harness)
        testLanguageStorePersistsSelection(using: harness)
        testLanguageStoreResolvesSpecificSelection(using: harness)
        testLanguageStorePublishesSelectionChanges(using: harness)
    }

    private static func testRawValuesAndDefault(using harness: TestHarness) {
        harness.expectEqual(AppLanguage(rawValue: "auto"), .auto, "auto language raw value")
        harness.expectEqual(AppLanguage(rawValue: "zh"), .zh, "zh language raw value")
        harness.expectEqual(AppLanguage(rawValue: "en"), .en, "en language raw value")
        harness.expectEqual(AppLanguage.defaultValue, .auto, "default language")
    }

    private static func testAutoResolvesChinesePreferredLanguages(using harness: TestHarness) {
        harness.expectEqual(AppLanguage.auto.resolved(preferredLanguages: ["zh-Hans-US"]), .zh, "zh-Hans resolves chinese")
        harness.expectEqual(AppLanguage.auto.resolved(preferredLanguages: ["zh-Hant-TW"]), .zh, "zh-Hant resolves chinese")
        harness.expectEqual(AppLanguage.auto.resolved(preferredLanguages: ["zh-CN"]), .zh, "zh-CN resolves chinese")
        harness.expectEqual(AppLanguage.auto.resolved(preferredLanguages: ["zh-TW"]), .zh, "zh-TW resolves chinese")
    }

    private static func testAutoResolvesNonChinesePreferredLanguagesToEnglish(using harness: TestHarness) {
        harness.expectEqual(AppLanguage.auto.resolved(preferredLanguages: ["en-US"]), .en, "english resolves english")
        harness.expectEqual(AppLanguage.auto.resolved(preferredLanguages: ["ja-JP", "en-US"]), .en, "non chinese resolves english")
        harness.expectEqual(AppLanguage.auto.resolved(preferredLanguages: []), .en, "empty languages resolves english")
    }

    private static func testManualLanguageOverridesSystemLanguages(using harness: TestHarness) {
        harness.expectEqual(AppLanguage.zh.resolved(preferredLanguages: ["en-US"]), .zh, "manual zh overrides english system")
        harness.expectEqual(AppLanguage.en.resolved(preferredLanguages: ["zh-Hans-US"]), .en, "manual en overrides chinese system")
    }

    private static func testLanguageStorePersistsSelection(using harness: TestHarness) {
        let suiteName = "APIInquiry.AppLanguageTests.persist"
        let defaults = makeCleanDefaults(suiteName: suiteName)
        let store = AppLanguageStore(userDefaults: defaults, preferredLanguages: { ["en-US"] })

        harness.expectEqual(store.selection, .auto, "language store default selection")
        harness.expectEqual(store.resolvedLanguage, .en, "language store default resolved")

        store.selection = .zh

        let reloaded = AppLanguageStore(userDefaults: defaults, preferredLanguages: { ["en-US"] })
        harness.expectEqual(reloaded.selection, .zh, "language store persisted selection")
        harness.expectEqual(reloaded.resolvedLanguage, .zh, "language store persisted resolved")

        defaults.removePersistentDomain(forName: suiteName)
    }

    private static func testLanguageStoreResolvesSpecificSelection(using harness: TestHarness) {
        let suiteName = "APIInquiry.AppLanguageTests.resolveSpecific"
        let defaults = makeCleanDefaults(suiteName: suiteName)
        let store = AppLanguageStore(userDefaults: defaults, preferredLanguages: { ["zh-Hans-US"] })

        harness.expectEqual(store.resolvedLanguage(for: .auto), .zh, "specific auto selection uses store preferred languages")
        harness.expectEqual(store.resolvedLanguage(for: .en), .en, "specific english selection resolves english")
        harness.expectEqual(store.resolvedLanguage(for: .zh), .zh, "specific chinese selection resolves chinese")

        defaults.removePersistentDomain(forName: suiteName)
    }

    private static func testLanguageStorePublishesSelectionChanges(using harness: TestHarness) {
        let suiteName = "APIInquiry.AppLanguageTests.publish"
        let defaults = makeCleanDefaults(suiteName: suiteName)
        let store = AppLanguageStore(userDefaults: defaults, preferredLanguages: { ["en-US"] })
        var receivedSelections: [AppLanguage] = []
        let cancellable = store.objectWillChange.sink {
            receivedSelections.append(store.selection)
        }

        store.selection = .zh
        store.selection = .en

        harness.expectEqual(receivedSelections, [.auto, .zh], "language store publishes before selection changes")

        cancellable.cancel()
        defaults.removePersistentDomain(forName: suiteName)
    }

    private static func makeCleanDefaults(suiteName: String) -> UserDefaults {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
