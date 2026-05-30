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
- [x] Fork `v0.3.7-liquidGlass` from the v0.3.7 branch state for visual exploration.
- [x] Run separated read-only agent reviews for project acceptance, UI boundary management, implementation feasibility, and QA risk.
- [x] Implement the first Liquid Glass-style experiment on the Console shell/root background and navigation background.
- [x] Respond to user feedback by making the exploration more visually explicit with macOS 26+ `glassEffect` for Console and MenuBar details backgrounds.
- [x] Fix the Console top navigation background layering by moving selection rendering into its own glass surface instead of a solid fill over the container.
- [x] Address user feedback that the glass still looked unlike Dock and the Console titlebar was visually broken.
- [x] Move large glass backgrounds to native AppKit-backed `NSGlassEffectView` / `NSVisualEffectView` surfaces and hide the AppKit Console title while preserving the window title string.
- [x] Analyze MenuBar details for the same double-layer class and remove the extra rounded/stroked surface from its window container background.
- [x] Verify the exploration patch with `git diff --check`, `swift build`, and `swift run APIInquiryCoreTestsRunner`.

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
- `v0.3.7-liquidGlass` is an exploration branch, not a formal redesign branch.
- The first safe pass was limited to Console shell/root and top navigation material; the second exploration pass intentionally uses macOS 26+ `glassEffect` / `GlassEffectContainer` for a more obvious Apple-style glass direction.
- Provider cards, quota values, badges, status text, API key controls, provider architecture, credential handling, and refresh logic remain untouched.
- macOS 13+ fallback support remains in place through material/solid surfaces, even though the exploration branch now exercises macOS 26+ glass APIs when available.
- Dock-like large-surface glass should be AppKit-backed in this exploration: macOS 26+ uses `NSGlassEffectView`, while macOS 13-25 uses `NSVisualEffectView` with semantic materials.
- The Console system title is hidden to avoid titlebar/content glass layer separation; the `NSWindow.title` remains set for window management and accessibility.
- In `MenuBarExtra.window`, the outer rounded window shell belongs to the system. Custom content supplied through `containerBackground(for: .window)` must be flat and rimless to avoid drawing a second panel inside the system panel.

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
| First Liquid Glass build failed on macOS 13 target | Used SwiftUI `accessibilityContrast` environment key in the new material surface views | Replaced it with macOS AppKit `NSWorkspace.accessibilityDisplayShouldIncreaseContrast` and kept SwiftUI `accessibilityReduceTransparency` for reduce-transparency fallback |
| First Liquid Glass pass was too subtle and navigation looked visually wrong | The navigation selected state used a solid accent fill over a weak material container, while MenuBar details had no glass surface | Added macOS 26+ `glassEffect` surfaces for Console/MenuBar backgrounds and moved selected navigation rendering into `ConsoleNavigationSelectionBackground` |
| User review found the glass still lacked Dock-like texture and the Console titlebar was broken | Large backgrounds were decorative SwiftUI surfaces and AppKit still drew a visible system title/titlebar over the content glass | Replaced large backgrounds with native AppKit glass/visual-effect backdrops, hid the visible Console title, removed the titlebar separator, and extended the background into the titlebar safe area |
| MenuBar details showed a related double-layer feel | `MenuBarExtra.window` supplied the system panel shell while custom `containerBackground` content drew another rounded/stroked/shadowed surface | Replaced the macOS 15+ MenuBar window background content with a flat native glass backdrop and left shape/rim/shadow to the system panel |

## Next Suggested Work

- Manually review the `v0.3.7-liquidGlass` Console visual effect in light/dark appearances, Reduce Transparency, Increase Contrast, and normal Provider/API workflows before deciding whether to keep, tune, or discard the exploration patch.
