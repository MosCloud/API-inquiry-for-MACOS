# Scripts

Executable tooling for local builds, packaging and installation. Run them from the
repository root; each script resolves `ROOT_DIR` itself.

| Script | What it does | Calls |
|---|---|---|
| `verify.sh` | PR gate: runs the test suite, then compiles every target (App included); `--release` for release builds | `lib/toolchain.sh` |
| `build-local-app.sh` | Builds the dev bundle at `.build/APIInquiry.app` (no launch) | `generate-app-icon.swift` |
| `run-local-app.sh` | Builds via the script above, then `pkill -x APIInquiry` and opens the bundle | `build-local-app.sh` |
| `package-mac-app.sh` | Builds the release bundle, writes `Info.plist`, ad-hoc signs → `dist/API Inquiry.app`; refuses a `0.0.0-dev` version | `generate-app-icon.swift` |
| `package-dmg.sh` | Packages the app, lays out the DMG window through Finder → `dist/API-Inquiry-vX.Y.Z.dmg` + `.sha256` | `package-mac-app.sh` |
| `install-mac-app.sh` | Packages, then copies into `~/Applications` | `package-mac-app.sh` |
| `restart-installed-app.sh` | Relaunches the copy installed under `~/Applications` | — |
| `clean-development-apps.sh` | Removes local dev bundles after release verification | — |
| `generate-app-icon.swift` | Regenerates `Resources/AppIcon.icns`; the build scripts call it automatically | — |
| `generate-dmg-background.js` | Regenerates `Assets/dmg-background.png` | — |

Support files:

- `version.env` — the release version values (`APP_VERSION`, `BUILD_NUMBER`, `RELEASE_TAG`, …). Release versions exist only in artifacts, never in a dev build.
- `Assets/` — source images for the app icon and the DMG background.
- `lib/toolchain.sh` — shared guards: `ensure_xcode_toolchain` picks Xcode's developer directory when `DEVELOPER_DIR` is unset, and `assert_modern_build_sdk` fails the build when the product links against the deployment-target SDK (13.0) instead of a real one.

Notes:

- The two app scripts select the Xcode toolchain themselves; a bare `swift build` still needs `DEVELOPER_DIR`.
- Scripts run outside SwiftPM's sandbox; pass `--disable-sandbox` if you invoke SwiftPM directly under one.
- Release packaging is a release-candidate step. The full checklist is
  `docs/release-runbook.md` / `docs/release-runbook_zh.md`.
