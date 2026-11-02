import APIInquiryCore
import CryptoKit
import Foundation

/// Covers the pieces of the WorkBuddy provider the compiler cannot check: the credit
/// arithmetic, the envelope decoding, and the credential store's forwarding.
///
/// The encryption tests build their own envelope with a throwaway key, so they exercise
/// the real GCM path without ever touching a real sign-in. The key payload is synthetic.
enum WorkBuddyProviderTests {
    static func run(using harness: TestHarness) async {
        snapshotAggregationTests(using: harness)
        packageClassificationTests(using: harness)
        credentialParsingTests(using: harness)
        credentialForwardingTests(using: harness)
        decoderTests(using: harness)
        storeDecryptionTests(using: harness)
        creditFormattingTests(using: harness)
        await secondaryRowTests(using: harness)
        await providerTests(using: harness)
    }

    // MARK: - Aggregation

    private static func snapshotAggregationTests(using harness: TestHarness) {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let soon = now.addingTimeInterval(2 * 86_400)
        let later = now.addingTimeInterval(20 * 86_400)

        let packages = [
            WorkBuddyPackage(name: "月包", capacityType: 4, remaining: 500, cycleSize: 500, cycleEnd: later),
            WorkBuddyPackage(name: "裂变包", capacityType: 1, remaining: Decimal(string: "93.64")!, expiresAt: later),
            WorkBuddyPackage(name: "裂变包", capacityType: 1, remaining: 100, expiresAt: soon)
        ]
        let snapshot = WorkBuddyBalanceProvider.makeSnapshot(
            from: packages,
            providerID: .workbuddy,
            fetchedAt: now
        )

        harness.expectEqual(snapshot.totalBalance, Decimal(string: "693.64")!, "total sums every package")
        harness.expectEqual(snapshot.grantedBalance, Decimal(string: "193.64")!, "one-off grants are the granted portion")
        harness.expectEqual(snapshot.toppedUpBalance, 500, "the monthly package is the paid portion")
        harness.expectEqual(snapshot.currency, "CREDITS", "credits are not a currency")
        harness.expectEqual(snapshot.expiringAt, soon, "the soonest expiry wins")
        harness.expectTrue(snapshot.isAvailable, "a positive balance is available")
        harness.expectEqual(snapshot.providerID, .workbuddy, "snapshot carries the provider id")

        // A monthly package refreshes rather than lapsing, so it must not set the expiry.
        let monthlyOnly = WorkBuddyBalanceProvider.makeSnapshot(
            from: [WorkBuddyPackage(name: "月包", capacityType: 4, remaining: 500, cycleSize: 500, cycleEnd: soon)],
            providerID: .workbuddy,
            fetchedAt: now
        )
        harness.expectEqual(monthlyOnly.expiringAt, nil, "a monthly package does not expire")
        harness.expectEqual(monthlyOnly.grantedBalance, 0, "no one-off grants means no granted portion")

        // Two dates, two meanings: a monthly allowance REFRESHES at its cycle end and
        // never lapses; a one-off grant EXPIRES. Conflating them would tell the user the
        // wrong thing about half the balance.
        harness.expectEqual(snapshot.refreshingAt, later, "the monthly cycle end is the refresh date")
        harness.expectEqual(monthlyOnly.refreshingAt, soon, "a monthly-only balance refreshes")
        harness.expectEqual(monthlyOnly.expiringAt, nil, "a monthly package never expires")
        harness.expectEqual(
            WorkBuddyPackage(name: "o", capacityType: 1, remaining: 1).refreshAt, nil,
            "a one-off grant never refreshes"
        )

        let empty = WorkBuddyBalanceProvider.makeSnapshot(from: [], providerID: .workbuddy, fetchedAt: now)
        harness.expectEqual(empty.totalBalance, 0, "no packages means a zero balance")
        harness.expectTrue(!empty.isAvailable, "a zero balance is not available")

        // Only credits that can still be lost have a "next expiry". A package that has
        // already lapsed keeps its old ExpiredTime while its cycle end is still in the
        // future, so it survives the request window holding nothing — and ranking it
        // reported a date in the past (real account, #102: 11/02 instead of 11/08).
        let lapsed = now.addingTimeInterval(-1_800)
        let withLapsed = WorkBuddyBalanceProvider.makeSnapshot(
            from: [
                WorkBuddyPackage(name: "失效包", capacityType: 1, remaining: 0, expiresAt: lapsed),
                WorkBuddyPackage(
                    name: "裂变包", capacityType: 1,
                    remaining: Decimal(string: "78.35")!, expiresAt: soon
                )
            ],
            providerID: .workbuddy,
            fetchedAt: now
        )
        harness.expectEqual(withLapsed.expiringAt, soon, "a lapsed package cannot set the next expiry")
        harness.expectEqual(
            withLapsed.grantedBalance, Decimal(string: "78.35")!,
            "a lapsed package still adds nothing to the balance"
        )

        // Same rule from two other sides: a drained package has no expiry to warn about,
        // and an un-swept remainder must never surface a date that has already passed.
        let drained = WorkBuddyBalanceProvider.makeSnapshot(
            from: [WorkBuddyPackage(name: "已用完", capacityType: 1, remaining: 0, expiresAt: soon)],
            providerID: .workbuddy,
            fetchedAt: now
        )
        harness.expectEqual(drained.expiringAt, nil, "a drained package has no expiry")

        let unswept = WorkBuddyBalanceProvider.makeSnapshot(
            from: [WorkBuddyPackage(name: "过期未冲销", capacityType: 1, remaining: 12, expiresAt: lapsed)],
            providerID: .workbuddy,
            fetchedAt: now
        )
        harness.expectEqual(unswept.expiringAt, nil, "an expiry in the past is never reported")

        // Negative remainders are clamped: the upstream can report a small negative once a
        // package is overdrawn, and summing it would understate the total.
        let overdrawn = WorkBuddyBalanceProvider.makeSnapshot(
            from: [WorkBuddyPackage(name: "x", capacityType: 1, remaining: -5, expiresAt: later)],
            providerID: .workbuddy,
            fetchedAt: now
        )
        harness.expectEqual(overdrawn.totalBalance, 0, "a negative remainder clamps to zero")
    }

    private static func packageClassificationTests(using harness: TestHarness) {
        harness.expectTrue(WorkBuddyPackage(name: "m", capacityType: 4, remaining: 1).isMonthly, "capacity type 4 is monthly")
        harness.expectTrue(!WorkBuddyPackage(name: "o", capacityType: 1, remaining: 1).isMonthly, "capacity type 1 is a grant")

        // Expiry falls back to the cycle end when a one-off package leaves ExpiredTime blank,
        // which is the common case on the real endpoint.
        let cycleEnd = Date(timeIntervalSince1970: 1_800_000_000)
        let withCycleEnd = WorkBuddyPackage(name: "o", capacityType: 1, remaining: 1, cycleEnd: cycleEnd)
        harness.expectEqual(withCycleEnd.expiry, cycleEnd, "a one-off package falls back to its cycle end")

        let explicit = Date(timeIntervalSince1970: 1_900_000_000)
        let withBoth = WorkBuddyPackage(
            name: "o", capacityType: 1, remaining: 1, cycleEnd: cycleEnd, expiresAt: explicit
        )
        harness.expectEqual(withBoth.expiry, explicit, "an explicit expiry outranks the cycle end")

        harness.expectEqual(
            WorkBuddyPackage(name: "o", capacityType: 1, remaining: 1).expiry, nil,
            "no dates means no expiry"
        )

        // Timestamp parsing must tolerate the empty string the endpoint sends.
        harness.expectEqual(WorkBuddyPackage.parseTimestamp(""), nil, "an empty timestamp parses to nil")
        harness.expectEqual(WorkBuddyPackage.parseTimestamp("   "), nil, "a blank timestamp parses to nil")
        harness.expectTrue(WorkBuddyPackage.parseTimestamp("2026-11-05 21:57:05") != nil, "a wire timestamp parses")
        harness.expectEqual(WorkBuddyPackage.parseTimestamp("not a date"), nil, "garbage parses to nil")
    }

    // MARK: - Credential payload

    private static func credentialParsingTests(using harness: TestHarness) {
        let payload = """
        {"accessToken":"tok","uid":"uid-1","domain":"www.workbuddy.cn"}
        """
        harness.expectEqual(try? WorkBuddyCredentialParser.parse(payload).accessToken, "tok", "the token is read")
        harness.expectEqual(try? WorkBuddyCredentialParser.parse(payload).userID, "uid-1", "the uid is read")
        harness.expectEqual(try? WorkBuddyCredentialParser.parse(payload).domain, "www.workbuddy.cn", "the domain is read")

        // The international sign-in is refused rather than silently mis-billed.
        let global = """
        {"accessToken":"tok","uid":"u","domain":"www.workbuddy.ai"}
        """
        var threwGlobal = false
        do {
            _ = try WorkBuddyCredentialParser.parse(global)
        } catch let error as BalanceProviderError {
            threwGlobal = error == .subscriptionRequired
        } catch {
            threwGlobal = false
        }
        harness.expectTrue(threwGlobal, "the international region is refused in v0.4.1")

        harness.expectEqual(
            WorkBuddyCredential.billingBase(forDomain: "www.workbuddy.cn"),
            URL(string: "https://www.codebuddy.cn"),
            "the CN domain maps to the codebuddy base"
        )
        harness.expectEqual(
            WorkBuddyCredential.billingBase(forDomain: "www.workbuddy.ai"),
            URL(string: "https://www.workbuddy.ai"),
            "the global domain maps to the workbuddy base"
        )
    }

    // MARK: - Store forwarding (#83)

    private static func credentialForwardingTests(using harness: TestHarness) {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let delegate = InMemoryCredentialStore(credentialsByAccount: [
            "deepseek-api-key": "delegate-key"
        ])
        let store = WorkBuddyCredentialStore(
            delegate: delegate,
            authFileURL: directory.appendingPathComponent("absent.info"),
            authDirectoryURL: directory
        )

        // A provider this store does not own must still reach the delegate.
        harness.expectEqual(
            try? store.credential(forAccount: "deepseek-api-key"), "delegate-key",
            "other accounts fall through to the delegate"
        )
        harness.expectEqual(
            try? store.credential(forAccount: WorkBuddyCredentialStore.defaultWorkBuddyAccount), nil,
            "a missing auth file yields no credential"
        )

        // 打开配置 must forward too; answering nil would disable other providers' buttons.
        harness.expectEqual(store.configurationURL(for: .workbuddy), directory, "workbuddy points at the auth directory")
        harness.expectEqual(store.configurationURL(for: .deepseek), nil, "unowned providers are forwarded, not swallowed")

        // Writes never touch the desktop app's file.
        let writable = WorkBuddyCredentialStore(
            delegate: InMemoryCredentialStore(),
            authFileURL: directory.appendingPathComponent("absent.info"),
            authDirectoryURL: directory
        )
        try? writable.saveCredential("saved", forAccount: WorkBuddyCredentialStore.defaultWorkBuddyAccount)
        harness.expectTrue(true, "saving does not throw for the workbuddy account")
    }

    // MARK: - Decoder

    private static func decoderTests(using harness: TestHarness) {
        // The key is the SHA-256 of the payload's base64 STRING, not of its decoded bytes.
        // Hashing the decoded bytes produces a different key, and every field then fails
        // the GCM tag with no hint about why.
        let secret = "dGhpcy1pcy1hLXRlc3Qtc2VjcmV0LWtleS1ibG9i"
        let payload = "{\"atRestSecretKey\":\"\(secret)\"}"
        let expected = Data(SHA256.hash(data: Data(secret.utf8)))
        harness.expectEqual(try? WorkBuddyCredentialDecoder.deriveKey(payloadJSON: payload), expected, "the key hashes the base64 string")

        harness.expectEqual(
            WorkBuddyCredentialDecoder.keyID(for: expected),
            String(SHA256.hash(data: expected).map { String(format: "%02x", $0) }.joined().prefix(16)),
            "the key id is the first 16 hex of the key's own hash"
        )

        harness.expectTrue(
            (try? WorkBuddyCredentialDecoder.deriveKey(payloadJSON: "{}")) == nil,
            "a payload without a secret is rejected"
        )
        harness.expectTrue(
            (try? WorkBuddyCredentialDecoder.deriveKey(payloadJSON: "not json")) == nil,
            "a malformed payload is rejected"
        )

        // Field-wrapper detection.
        harness.expectTrue(
            WorkBuddyCredentialDecoder.isEncryptedField(["$wbEncrypted": 1, "envelope": "x"]),
            "the wrapper shape is recognised"
        )
        harness.expectTrue(
            !WorkBuddyCredentialDecoder.isEncryptedField(["$wbEncrypted": 1]),
            "a wrapper without an envelope is rejected"
        )
        harness.expectTrue(
            !WorkBuddyCredentialDecoder.isEncryptedField(["envelope": "x", "extra": "y"]),
            "an unexpected third key is rejected"
        )
        harness.expectTrue(
            !WorkBuddyCredentialDecoder.isEncryptedField("just-a-string"),
            "a plain string is not a wrapper"
        )

        // A round trip proves the AAD transcript is byte-exact: any difference fails the
        // tag, which is indistinguishable from having the wrong key.
        let key = Data(SHA256.hash(data: Data("round-trip-secret".utf8)))
        let keyID = WorkBuddyCredentialDecoder.keyID(for: key)
        let wrapper = makeEnvelope(plaintext: "the-real-token", key: key, keyID: keyID)
        harness.expectEqual(
            try? WorkBuddyCredentialDecoder.openField(wrapper, key: key), "the-real-token",
            "a well-formed envelope opens"
        )

        let otherKey = Data(SHA256.hash(data: Data("another-secret".utf8)))
        var threwMismatch = false
        do {
            _ = try WorkBuddyCredentialDecoder.openField(wrapper, key: otherKey)
        } catch let error as WorkBuddyCredentialError {
            if case .keyMismatch = error { threwMismatch = true }
        } catch {
            threwMismatch = false
        }
        harness.expectTrue(threwMismatch, "a mismatched key is named, not silently wrong")

        harness.expectTrue(
            (try? WorkBuddyCredentialDecoder.openField(["$wbEncrypted": 1, "envelope": "!!!"], key: key)) == nil,
            "a malformed envelope is rejected"
        )
    }

    // MARK: - Store decryption

    private static func storeDecryptionTests(using harness: TestHarness) {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        // The key is the SHA-256 of the payload's atRestSecretKey STRING, so the fixture
        // must hash the base64 spelling the fake app prints — not its decoded bytes.
        let secretString = "c3RvcmUtc2VjcmV0"
        let key = Data(SHA256.hash(data: Data(secretString.utf8)))
        let keyID = WorkBuddyCredentialDecoder.keyID(for: key)
        let authURL = directory.appendingPathComponent("workbuddy-desktop.info")

        // The on-disk shape the app writes: an encrypted wrapper plus the account block.
        let document: [String: Any] = [
            "auth": [
                "accessToken": makeEnvelope(plaintext: "decrypted-token", key: key, keyID: keyID),
                "domain": "www.workbuddy.cn",
                "expiresAt": 1_796_184_315_327
            ],
            "account": ["uid": "uid-9"]
        ]
        if let data = try? JSONSerialization.data(withJSONObject: document) {
            try? data.write(to: authURL)
        }

        // Inject the key payload instead of launching the real app: the store takes the
        // executable path, and a script that prints the payload stands in for it.
        let fakeApp = directory.appendingPathComponent("fake-app.sh")
        let payload = "{\"atRestSecretKey\":\"\(secretString)\"}"
        let script = "#!/bin/sh\nprintf '%s' '\(payload)'\n"
        try? script.write(to: fakeApp, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeApp.path)

        let store = WorkBuddyCredentialStore(
            delegate: InMemoryCredentialStore(),
            authFileURL: authURL,
            authDirectoryURL: directory,
            appExecutablePath: fakeApp.path
        )

        let stored = try? store.credential(forAccount: WorkBuddyCredentialStore.defaultWorkBuddyAccount)
        let object = stored
            .flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        harness.expectEqual(object?["accessToken"] as? String, "decrypted-token", "the store decrypts the token")
        harness.expectEqual(object?["uid"] as? String, "uid-9", "the store carries the billing identity")
        harness.expectEqual(object?["domain"] as? String, "www.workbuddy.cn", "the store carries the domain")
        harness.expectEqual(object?["expiresAt"] as? Double, 1_796_184_315_327, "millisecond expiry is preserved")

        // Expiry unit normalisation: the desktop document writes millis, plugin-side
        // copies write seconds. Treating seconds as millis dates the token to 1970.
        harness.expectEqual(WorkBuddyCredentialStore.epochMilliseconds(1_796_184_315_327), 1_796_184_315_327, "millis stay millis")
        harness.expectEqual(WorkBuddyCredentialStore.epochMilliseconds(1_796_184_315), 1_796_184_315_000, "seconds become millis")
        harness.expectEqual(WorkBuddyCredentialStore.epochMilliseconds(nil), 0, "absent becomes zero")
        harness.expectEqual(WorkBuddyCredentialStore.epochMilliseconds("0"), 0, "zero stays zero")
    }

    // MARK: - Formatting

    /// The menu bar's secondary row carries the unit, never a bare date.
    ///
    /// "2877.7 11/05" read as a fraction: the date has its own slashes, so putting it
    /// where the currency code goes needed a second separator. The date lives in the
    /// Console, where the prefix says which date means what.
    private static func secondaryRowTests(using harness: TestHarness) async {
        let expiring = Date(timeIntervalSince1970: 1_800_000_000)
        let balance = BalanceSnapshot(
            providerID: .workbuddy,
            totalBalance: Decimal(string: "2877.74")!,
            currency: "CREDITS",
            isAvailable: true,
            grantedBalance: Decimal(string: "2377.74")!,
            toppedUpBalance: 500,
            expiringAt: expiring,
            refreshingAt: expiring.addingTimeInterval(20 * 86_400),
            fetchedAt: expiring
        )
        let snapshot = ProviderSnapshot.balance(balance)
        let presentation = ProviderSnapshotPresentation.make(
            from: snapshot,
            strings: LocalizedStrings(language: .zh)
        )
        harness.expectEqual(presentation.trailingText, "积分", "the trailing cell is the unit")
        harness.expectTrue(
            presentation.trailingText != presentation.compactAmountText,
            "the trailing cell is not a repeat of the amount"
        )
    }

    private static func creditFormattingTests(using harness: TestHarness) {
        let english = LocalizedStrings(language: .en)
        let chinese = LocalizedStrings(language: .zh)

        harness.expectEqual(
            ProviderValueFormatter.formatAmount(Decimal(string: "2899.64")!, currency: "CREDITS", fractionDigits: 2, includeCurrencyCode: true, strings: english),
            "2899.64 credits",
            "english renders the credit unit"
        )
        harness.expectEqual(
            ProviderValueFormatter.formatAmount(Decimal(string: "2899.64")!, currency: "CREDITS", fractionDigits: 2, includeCurrencyCode: true, strings: chinese),
            "2899.64 积分",
            "chinese renders the credit unit"
        )
        harness.expectEqual(
            ProviderValueFormatter.formatAmount(Decimal(string: "2899.64")!, currency: "CREDITS", fractionDigits: 1, includeCurrencyCode: false, strings: chinese),
            "2899.6",
            "a menu bar value omits the unit"
        )
        // Money is untouched by the credit branch.
        harness.expectEqual(
            ProviderValueFormatter.formatAmount(Decimal(string: "68.65")!, currency: "CNY", fractionDigits: 2, includeCurrencyCode: true, strings: english),
            "¥68.65 CNY",
            "money keeps its symbol"
        )
        harness.expectTrue(ProviderValueFormatter.isCreditCurrency("credits"), "the credit check is case-insensitive")
        harness.expectTrue(!ProviderValueFormatter.isCreditCurrency("CNY"), "money is not credit")

        // The credit balance's trailing cell carries the unit, not a currency code.
        let balance = BalanceSnapshot(
            providerID: .workbuddy,
            totalBalance: Decimal(string: "2899.64")!,
            currency: "CREDITS",
            isAvailable: true,
            grantedBalance: Decimal(string: "2399.64")!,
            toppedUpBalance: 500,
            fetchedAt: Date()
        )
        let presentation = ProviderSnapshotPresentation.make(
            from: .balance(balance),
            strings: chinese
        )
        harness.expectEqual(presentation.trailingText, "积分", "the trailing cell is the unit")
        harness.expectEqual(presentation.leadingText, "", "credits carry no symbol")

        // The Console names the credit metric 「总积分」 rather than 「总余额」: credits are a
        // unit of account, and 余额 reads as cash. A prepaid balance keeps the old copy.
        harness.expectEqual(chinese.totalCreditsMetricTitle, "总积分", "chinese credit title")
        harness.expectEqual(chinese.grantedCreditsMetricTitle, "赠送积分", "chinese granted credit title")
        harness.expectEqual(english.totalCreditsMetricTitle, "Total credits", "english credit title")
        harness.expectEqual(english.grantedCreditsMetricTitle, "Granted credits", "english granted credit title")
        harness.expectTrue(
            chinese.totalBalanceMetricTitle != chinese.totalCreditsMetricTitle,
            "a credit balance and a money balance are named differently"
        )
    }

    // MARK: - Provider

    private static func providerTests(using harness: TestHarness) async {
        let now = Date()

        let client = WorkBuddyMockHTTPClient(
            statusCode: 200,
            body: meterBody(accounts: [
                ["PackageName": "月包", "CapacityType": 4, "CycleCapacityRemainPrecise": "500",
                 "CycleCapacitySizePrecise": "500", "CycleEndTime": "2026-11-30 23:59:59"],
                ["PackageName": "裂变包", "CapacityType": 1, "CycleCapacityRemainPrecise": "93.64",
                 "CycleEndTime": "2026-11-05 21:57:05", "ExpiredTime": ""]
            ])
        )
        let provider = WorkBuddyBalanceProvider(httpClient: client, now: { now })
        let credential = """
        {"accessToken":"tok","uid":"uid-1","domain":"www.workbuddy.cn"}
        """

        let snapshot = try? await provider.fetchSnapshot(apiKey: credential)
        guard case .balance(let balance) = snapshot else {
            harness.expectTrue(false, "the provider returns a balance snapshot")
            return
        }
        harness.expectEqual(balance.totalBalance, Decimal(string: "593.64")!, "the provider sums the packages")
        harness.expectEqual(balance.grantedBalance, Decimal(string: "93.64")!, "the provider separates granted credit")
        harness.expectEqual(balance.currency, "CREDITS", "the provider reports credits")

        let request = client.lastRequest
        harness.expectEqual(
            request?.url?.absoluteString,
            "https://www.codebuddy.cn/v2/billing/meter/get-user-resource",
            "the request targets the CN billing endpoint"
        )
        harness.expectEqual(request?.httpMethod, "POST", "the billing call is a POST")
        harness.expectEqual(
            request?.value(forHTTPHeaderField: "Authorization"), "Bearer tok",
            "the token is a bearer credential"
        )
        harness.expectEqual(
            request?.value(forHTTPHeaderField: "X-User-Id"), "uid-1",
            "the billing identity is sent"
        )
        harness.expectEqual(
            request?.value(forHTTPHeaderField: "X-Domain"), "www.workbuddy.cn",
            "the domain is sent"
        )

        // The package window must reach the client's own absurd horizon. A narrower,
        // plausible-looking window (a month, a year) still answers 200 but silently drops
        // the monthly package: on a real account that read as 2,389 credits instead of
        // 2,889, with the monthly allowance missing from every surface.
        let body = client.lastRequestBody
        let end = (body?["PackageEndTimeRangeEnd"] as? String)
        harness.expectTrue(end != nil, "the request carries a package window end")
        if let end, let begin = body?["PackageEndTimeRangeBegin"] as? String {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let span = formatter.date(from: end).flatMap { e in
                formatter.date(from: begin).map { e.timeIntervalSince($0) }
            }
            harness.expectTrue(
                (span ?? 0) > 3_000_000_000,
                "the package window reaches the client's ~100-year horizon"
            )
        }
        harness.expectEqual(body?["ProductCode"] as? String, "p_tcaca", "the product code is the client's")
        harness.expectTrue(body?["Status"] != nil, "the status filter is sent")

        // 401 is an authentication problem, not a decode problem.
        let unauthorized = WorkBuddyBalanceProvider(
            httpClient: WorkBuddyMockHTTPClient(statusCode: 401, body: "{}"),
            now: { now }
        )
        await harness.expectThrowsBalanceProviderError(.authenticationFailed, {
            _ = try await unauthorized.fetchSnapshot(apiKey: credential)
        }, "401 reports an authentication failure")

        let rateLimited = WorkBuddyBalanceProvider(
            httpClient: WorkBuddyMockHTTPClient(statusCode: 429, body: "{}"),
            now: { now }
        )
        await harness.expectThrowsBalanceProviderError(.rateLimited, {
            _ = try await rateLimited.fetchSnapshot(apiKey: credential)
        }, "429 reports rate limiting")

        // A 200 carrying a non-zero envelope code is an application failure: reading it as
        // an empty balance would show "0 credits" for a working account.
        let envelopeError = WorkBuddyBalanceProvider(
            httpClient: WorkBuddyMockHTTPClient(statusCode: 200, body: "{\"code\":14018,\"msg\":\"no credit\"}"),
            now: { now }
        )
        var threwEnvelope = false
        do {
            _ = try await envelopeError.fetchSnapshot(apiKey: credential)
        } catch let error as BalanceProviderError {
            if case .serverError = error { threwEnvelope = true }
        } catch {
            threwEnvelope = false
        }
        harness.expectTrue(threwEnvelope, "a non-zero envelope code is an error, not zero balance")

        // The international region must not reach the network at all.
        await harness.expectThrowsBalanceProviderError(.subscriptionRequired, {
            _ = try await unauthorized.fetchSnapshot(apiKey: "{\"accessToken\":\"t\",\"domain\":\"www.workbuddy.ai\"}")
        }, "the international region is refused before any request")

        await harness.expectThrowsBalanceProviderError(.authenticationFailed, {
            _ = try await unauthorized.fetchSnapshot(apiKey: "")
        }, "an empty credential is rejected")
    }

    // MARK: - Helpers

    /// Build a real AES-GCM field wrapper, so the tests exercise the actual crypto path.
    private static func makeEnvelope(plaintext: String, key: Data, keyID: String) -> [String: Any] {
        let aad = WorkBuddyCredentialDecoder.additionalAuthenticatedData(keyID: keyID, suite: 1)
        let nonce = AES.GCM.Nonce()
        let sealed = try! AES.GCM.seal(
            Data(plaintext.utf8),
            using: SymmetricKey(data: key),
            nonce: nonce,
            authenticating: aad
        )
        let envelope: [String: Any] = [
            "suite": 1,
            "keyId": keyID,
            "nonce": Data(nonce).base64EncodedString(),
            "authTag": sealed.tag.base64EncodedString(),
            "ciphertext": sealed.ciphertext.base64EncodedString()
        ]
        let json = try! JSONSerialization.data(withJSONObject: envelope)
        return ["$wbEncrypted": 1, "envelope": json.base64EncodedString()]
    }

    private static func meterBody(accounts: [[String: Any]]) -> String {
        let document: [String: Any] = [
            "code": 0,
            "msg": "OK",
            "data": ["Response": ["Data": ["Accounts": accounts]]]
        ]
        let data = try! JSONSerialization.data(withJSONObject: document)
        return String(data: data, encoding: .utf8)!
    }

    private static func makeTemporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("workbuddy-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

private final class WorkBuddyMockHTTPClient: HTTPClient {
    private let statusCode: Int
    private let body: String
    private(set) var lastRequest: URLRequest?
    var lastRequestBody: [String: Any]? {
        lastRequest?.httpBody
            .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    }

    init(statusCode: Int, body: String) {
        self.statusCode = statusCode
        self.body = body
    }

    func data(for request: URLRequest) async throws -> HTTPResponse {
        lastRequest = request
        return HTTPResponse(data: Data(body.utf8), statusCode: statusCode)
    }
}
