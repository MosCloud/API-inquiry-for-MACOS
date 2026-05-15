# macOS Packaging And Login Launch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn API Inquiry from a development `.build` app into a durable local macOS app package with a path that can later support install and login launch.

**Architecture:** Add a release packaging script that builds `APIInquiryApp`, assembles a standard `dist/API Inquiry.app` bundle, copies image resources into `Contents/Resources`, validates `Info.plist`, and ad-hoc signs the app. Keep the existing `.build/APIInquiry.app` development builder unchanged for quick local debugging.

**Tech Stack:** Swift Package Manager, Bash, macOS app bundle layout, `plutil`, ad-hoc `codesign`.

---

## Tasks

### Task 1: Formal Local App Packaging

**Files:**
- Create: `Scripts/package-mac-app.sh`
- Modify: `.gitignore`
- Modify: `README.md`
- Modify: `README_zh.md`

- [x] Write a red check confirming `Scripts/package-mac-app.sh` and `dist/API Inquiry.app` do not exist yet.
- [x] Create `Scripts/package-mac-app.sh` to generate `dist/API Inquiry.app` from a release SwiftPM build.
- [x] Mark `Scripts/package-mac-app.sh` executable.
- [x] Run `bash -n Scripts/package-mac-app.sh`.
- [x] Run `Scripts/package-mac-app.sh`.
- [x] Fix strict signing failure by keeping the packaged app root to `Contents/` only and loading images from `Contents/Resources`.
- [x] Verify `dist/API Inquiry.app/Contents/Info.plist` is valid.
- [x] Verify the app binary exists at `dist/API Inquiry.app/Contents/MacOS/APIInquiry`.
- [x] Verify DeepSeek PNG resources exist in `dist/API Inquiry.app/Contents/Resources`.
- [x] Verify ad-hoc code signature with `codesign --verify --deep "dist/API Inquiry.app"`.
- [x] Update English and Chinese README instructions.
- [x] Run `swift run APIInquiryCoreTestsRunner` and `swift build`.
- [x] Commit and push the packaging change.

### Task 2: Installed App Path

**Files:**
- Create: `Scripts/install-mac-app.sh`
- Create: `Scripts/restart-installed-app.sh`
- Modify: `README.md`
- Modify: `README_zh.md`

- [ ] Install `dist/API Inquiry.app` into `~/Applications/API Inquiry.app`.
- [ ] Restart from `~/Applications/API Inquiry.app`.
- [ ] Verify the running process path is under `~/Applications`.

### Task 3: Launch At Login

**Files:**
- Create: `Sources/APIInquiryApp/LaunchAtLoginController.swift`
- Modify: `Sources/APIInquiryApp/MenuBarContentView.swift`
- Modify: `README.md`
- Modify: `README_zh.md`

- [ ] Add an `SMAppService.mainApp` wrapper for status, register, and unregister.
- [ ] Add a compact `Launch at Login` toggle in the details panel.
- [ ] Verify the toggle against the installed app package.
