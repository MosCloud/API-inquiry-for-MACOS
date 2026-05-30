# Current Task Plan

## Goal

Prepare the `v0.3.7` branch from `main` and record the version plan for restrained UI polish before the v0.4.0 provider expansion.

## Current Status

- [x] Create isolated worktree branch `v0.3.7` from current `main`.
- [x] Review existing planning files, roadmap, UI guidance, and current UI code shape.
- [x] Record the v0.3.7 UI polish plan in paired English and Chinese plan docs.
- [x] Update `docs/roadmap.md` so `v0.3.7` is the next planned version before `v0.4.0`.
- [x] Refresh root `task_plan.md`, `findings.md`, and `progress.md` for the new branch context.
- [x] Review the recorded plan with the user before implementation starts.
- [x] Add a concrete Round 1 implementation plan for the low-risk UI polish pass.
- [x] Implement v0.3.7 Round 1 UI polish in small, reviewable steps.
- [x] Verify with `swift run APIInquiryCoreTestsRunner` and `swift build`.
- [x] Launch the local app for user manual UI review.
- [x] Add a concrete Round 2 plan for versioned high-API UI effects with macOS 13 fallback.
- [x] Implement v0.3.7 Round 2 versioned UI effects in the smallest safe surface.
- [x] Verify Round 2 with `swift run APIInquiryCoreTestsRunner`, `swift build`, agent QA, and manual UI review launch.
- [x] Add a concrete Round 3 plan for more perceptible versioned UI effects without redesign.
- [x] Implement v0.3.7 Round 3 perceptible versioned UI effects in the smallest safe surface.
- [x] Verify Round 3 with `swift run APIInquiryCoreTestsRunner`, `swift build`, agent QA, and manual UI review launch.
- [x] Receive user approval to close the current build as the formal v0.3.7 release.
- [x] Update release metadata, Settings version display, README, roadmap, and v0.3.7 release notes.
- [x] Address release QA feedback for Reduce Motion coverage, Console Home accessibility grouping, and release note section format.
- [x] Verify release candidate with `git diff --check`, `swift run APIInquiryCoreTestsRunner`, `swift build`, local app launch, DMG packaging, Info.plist version checks, codesign verification, `hdiutil verify`, and checksum verification.

## Decisions

- `v0.3.7` is a UI polish release, not a provider expansion release.
- The UI style boundary is strict: minimal, restrained, efficient, lightly technical, and content-first.
- Any UI element that does not improve content scanning, feedback, or accessibility should be removed or rejected.
- `v0.4.0` remains the version for more providers and generic provider capabilities.
- Round 1 intentionally deferred `MenuBarContentView` splitting, Console Home density/layout changes, API removal confirmation model changes, provider expansion, and AppKit logo drawing replacement.
- Round 2 keeps macOS 13+ as the fallback baseline while enabling higher-version SwiftUI APIs only through a centralized App-target helper.
- Round 2 numeric text transitions must not parse formatted display amount strings; use the macOS 13+ safe numeric text fallback unless a real numeric value is already available.
- Round 3 should make higher-version API value perceptible by exposing real numeric values, adding deterministic refresh click feedback, and making result feedback easier to scan; it must not become a redesign.
- The untracked `.superpowers/` directory in the main worktree remains untouched.
- Release notes use the repository release sections when applicable: `App Optimization` and `Bug Fixes`.

## Errors Encountered

| Error | Attempt | Resolution |
| --- | --- | --- |
| Sandbox blocked initial branch creation | `git worktree add .worktrees/v0.3.7 -b v0.3.7 main` could not create a ref lock | Re-ran the same command with approved escalation and created the worktree successfully |
| SwiftPM/Clang cache write blocked in sandbox | `swift run APIInquiryCoreTestsRunner` and `swift build` without escalation could not write under `/Users/zbw/.cache/clang/ModuleCache` | Re-ran verification commands with approved escalation |
| App build failed after first UI animation pass | `FeedbackText` chained `.animation` outside a concrete conditional `View` | Wrapped the conditional content in `Group` and re-ran `swift build` successfully |
| Round 2 plan docs used ambiguous numeric fallback wording | Plan docs described `ContentTransition.numericText()` even though the implementation uses explicit `ContentTransition.numericText(countsDown: false)` | Updated the Round 2 plan docs to match the macOS 13 safe fallback |
| Round 3 QA found refresh visual hold could persist after menu close | `onDisappear` cancelled the hold task without resetting `isRefreshVisuallyHeld` | First fixed cleanup; later removed the hold-based animation entirely after user visual review |
| User review found refresh animation stuttered/backtracked and exceeded the claimed 550ms | Active/hold state drove system/fallback rotation, so deactivation could reset the symbol independently from the intended hold duration | Replaced active/hold refresh animation with a cumulative forward-only turn loop using a fixed 0.8s linear animation |
| Release QA found Reduce Motion and Console Home accessibility gaps | Newly added non-refresh transitions and provider row accessibility grouping were not fully gated or could flatten child controls | Added centralized motion helpers, passed Reduce Motion into numeric/top-change/subtle animations, and removed row-level accessibility flattening |
| Root-level checksum verification failed from the repository root | The `.sha256` file stores the DMG basename, so `shasum -c dist/API-Inquiry-v0.3.7.dmg.sha256` from repo root could not find the file | Re-ran checksum verification from `dist/`, matching the install/download directory workflow |

## Next Suggested Work

- Commit the release candidate, push the branch, tag `release/v0.3.7`, and create the GitHub Release with the generated DMG assets.
