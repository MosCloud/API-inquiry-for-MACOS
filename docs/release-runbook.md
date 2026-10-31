# Release Runbook

Operational notes for cutting an API Inquiry release. Written from the v0.3.16 release, where two packaging defects shipped a DMG with a missing app icon and a default install window. Chinese version: [release-runbook_zh.md](release-runbook_zh.md).

## 0. Version numbering

- Released versions live in tags named `release/vX.Y.Z`, releases are titled `API Inquiry vX.Y.Z`.
- `v0.3.16` is **reused**: `0.3.16`–`0.3.20` were withdrawn Anthropic builds (2026-10-13). The current `release/v0.3.16` is the Codex Credits display fix, build 21.
- Always check the number is unused before bumping: `git ls-remote --tags origin 'release/vX.Y.Z'` and `gh api repos/MosCloud/API-inquiry-for-MACOS/releases/tags/release/vX.Y.Z` (404 = free).

## 1. Version bump checklist

All of these must agree, or `ReleaseVersionConsistencyTests` fails:

- `Scripts/version.env`: `APP_VERSION`, `BUILD_NUMBER`, `RELEASE_TAG`, `RELEASE_VERSION`, `DMG_BASENAME`, `VOLUME_NAME`
- `Sources/APIInquiryApp/App/AppVersion.swift` (`vX.Y.Z`)
- `Sources/APIInquiryCoreTestsRunner/ReleaseVersionConsistencyTests.swift` (version, tag, dmg name, volume name, build number)
- `README.md`, `README_en.md` (DMG name examples, "latest released version")
- `docs/roadmap.md` (date, latest version, capability summary — both languages)
- `AGENTS.md` (current version sentence)
- New `docs/releases/vX.Y.Z_github.md`, bilingual, user-facing sections only: New Features / App Optimization / Bug Fixes (omit empty sections), then download verification and known limitations.

## 2. Build environment

- **Use the Xcode toolchain for packaging.** The Command Line Tools SDK on this machine cannot resolve the SwiftUI macros, so Release builds fail without Xcode's toolchain. `Scripts/package-mac-app.sh` selects `/Applications/Xcode.app/Contents/Developer` itself when `DEVELOPER_DIR` is unset, and aborts with a readable message when no Xcode is installed; set `DEVELOPER_DIR` explicitly to use a different Xcode.
- **SwiftPM's default build system is now the Xcode one.** Products go to `.build/out/Products/<Configuration>/` and `.build/<configuration>` is a symlink to it. The resource bundle is a macOS bundle (`APIInquiry_APIInquiryApp.bundle/Contents/Resources/*.png|icns`), **not** the flat layout older releases had. Packaging must search the bundle recursively; never assume `maxdepth 1`.
- **Build with `--build-system native`.** SwiftPM's Xcode build system records `LC_BUILD_VERSION sdk` as the deployment target (13.0), which opts the app out of the macOS 26 design: the Console's add-provider control renders as a wide legacy pop-up button instead of the compact glass pill, and the menu bar panel loses its rounded glass chrome. The native build system records the real SDK and matches v0.3.15. Both app scripts assert this automatically and fail below `sdk 20`; for a bare `swift build`, check the candidate with `otool -l "…/MacOS/APIInquiry" | grep -A4 LC_BUILD_VERSION` (healthy: `sdk 26.x`/`27.x`, broken: `sdk 13.0`).
- **Never carry a compatibility or test `SDKROOT` into an acceptance or release build.** The scripts resolve the active SDK themselves; only `API_INQUIRY_APP_SDKROOT` may override it on purpose. Check the executable itself with `xcrun vtool -show-build` (expect the current macOS SDK), not only the bundle's signature.
- **SwiftPM runs its own sandbox**, so `swift build` / `swift run` fail under a restrictive agent sandbox with `sandbox-exec: sandbox_apply: Operation not permitted`. Use `--disable-sandbox`, or run with full file access. `hdiutil` (DMG create/mount) also needs full access.
- **Keychain tests** (`save/replace/delete credential`) fail with `unexpectedStatus(100001)` when the Keychain is unreachable. That is an environment limit, not a regression: `PASS: N expectations` requires running outside the sandbox, otherwise expect exactly those three failures.
- The repository lives under `Desktop`, so FileProvider/Finder metadata can land on files seconds after they are written. Anything code-signed on that path must be re-cleaned (`xattr -cr`) before strict verification. Local runs therefore stage the signed app under `/private/tmp` and expose `.build/APIInquiry.app` only as an entry-point symlink; a signature that passes immediately but fails after a delay is a blocker until the DMG-contained copy passes strict verification.

## 3. Packaging pipeline

`Scripts/package-mac-app.sh`

1. Generates the app icon, builds the `release` product, strips the staging app, writes `Info.plist`, ad-hoc signs, verifies.
2. Copies `*.png` / `*.icns` from the SwiftPM resource bundle **anywhere inside it** into `Contents/Resources`, and aborts if `AppIcon.icns` did not arrive.
3. `ditto`s the staged app into `dist/`, runs `xattr -cr` (FileProvider detritus), then verifies again.

`Scripts/package-dmg.sh`

1. Builds the app via the script above.
2. Creates a read-write HFS+ image in `/private/tmp`, mounts it, copies the app plus the `Applications` symlink, hides `.background/dmg-background.png`.
3. Drives Finder: **activate Finder, open the window, wait for it to materialize, set view options (background picture, 152 pt icons, no arrangement, bounds `{160,160,920,580}`, icon positions `{210,180}` / `{550,180}`), `update` the folder.**
4. Polls the staging volume's `.DS_Store` until it contains `dmg-background.png`; fails on timeout. Then closes the window, syncs, detaches.
5. Converts to UDZO, verifies, mounts the result read-only and asserts: app present and not hidden, executable, bundle id, version, build, `Applications` symlink, and `.DS_Store` containing the background alias. Writes `.sha256`.

Why step 3/4 matter: Finder only applies and persists window view options while it is the frontmost app and the window is actually open. Scripted from the background it silently drops them and the volume ends up with a 6 KB `.DS_Store` stub (`Bud1` only) — the DMG then opens as a plain window with no background and default icon arrangement. Never wrap the background assignment in `try`.

## 4. Acceptance checklist

Acceptance is the **app inside the final DMG**, not the `dist` copy (that one keeps picking up Finder metadata).

```bash
M=$(mktemp -d /private/tmp/relcheck.XXXXXX)
hdiutil attach -nobrowse -readonly -mountpoint "$M" dist/API-Inquiry-vX.Y.Z.dmg
ls -l "$M/.DS_Store"                      # ~10 KB; a 6 KB file means the layout is missing
strings -a "$M/.DS_Store" | grep dmg-background.png
ls "$M/API Inquiry.app/Contents/Resources" # 8 files: AppIcon.icns/.png + 6 provider logos
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$M/API Inquiry.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$M/API Inquiry.app/Contents/Info.plist"
codesign --verify --deep --strict -v "$M/API Inquiry.app"
hdiutil detach "$M"
(cd dist && shasum -a 256 -c API-Inquiry-vX.Y.Z.dmg.sha256)
```

Reference values from a good build (`v0.3.15`): `.DS_Store` 10244 bytes, window bounds `{{160, 527}, {760, 420}}`, background alias to `.background/dmg-background.png`.

- Native chrome parity cannot be proven from a source diff: inspect the built app's menu bar panel (screenshot or accessibility state). Do not hide a linked-SDK regression behind custom corners or backgrounds.
- Open the packaged app once and confirm Settings shows `vX.Y.Z`; a release is not done until it does.

## 5. Publishing

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

Release must be non-draft, non-prerelease, carry exactly two assets, and the DMG should be downloaded once and checksum-verified after upload:

```bash
gh release download release/vX.Y.Z --pattern "API-Inquiry-vX.Y.Z.dmg*"
shasum -a 256 -c API-Inquiry-vX.Y.Z.dmg.sha256
```

If a bad artifact is caught within minutes of publishing and only the packaging changed, replacing the two assets with `gh release upload --clobber` is acceptable; document that the checksum changed.

Write release notes for users, not as a changelog: New Features / App Optimization / Bug Fixes, empty sections omitted, and no internal type names, file paths, test counts, framework names, or refactor wording. Prefer perceptible phrasing ("refresh feels steadier", "status is easier to read") over implementation wording.

## 6. Cleanup

```bash
Scripts/clean-development-apps.sh          # removes dev app bundles, keeps the DMGs
git worktree remove .worktrees/<name> && git worktree prune
git branch -D <merged-branch>
hdiutil info                               # no leftover mounted images
```

## 7. Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| Finder shows a generic app icon; Console logos fall back to plain text | `Contents/Resources` empty — resource copy only matched the old flat SwiftPM bundle layout | recursive `find` in `package-mac-app.sh` + abort when `AppIcon.icns` is missing |
| Install window has no background/arrow, icons in default places, `.DS_Store` ~6148 bytes | Finder scripted from the background dropped the view options; `close` happened before they were persisted | activate Finder, wait for the window, poll `.DS_Store` for the background alias, then close |
| Console add-provider control is a wide pop-up button; panel loses glass chrome | built with the Xcode build system, so the binary records `sdk 13.0` and opts out of the macOS 26 design | rebuild with `--build-system native` and verify the recorded SDK |
| `codesign --verify` → "resource fork, Finder information, or similar detritus" | FileProvider/Finder metadata on the Desktop copy | `xattr -cr` before verifying; accept via the mounted DMG |
| Release build fails with impossible Swift errors (`'self' is immutable` on `@State`) | CLT SDK does not match `/usr/bin/swift` | build with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` |
| `sandbox-exec: sandbox_apply: Operation not permitted` | nested SwiftPM sandbox blocked by the agent sandbox | `swift build/run --disable-sandbox`, or full file access |
| `hdiutil create` → "operation not permitted" | agent sandbox blocks disk images | run packaging with full file access |
| 3 Keychain expectations fail with `unexpectedStatus(100001)` | no Keychain access inside the sandbox | run outside the sandbox; CI is the release gate |
| Desktop keeps a phantom disk icon for a test volume | the image was detached after its mountpoint directory had been deleted | `killall Finder`; check `hdiutil info` for stray images first |
