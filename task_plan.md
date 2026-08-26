# Current Task Plan

## Goal

Build and verify v0.3.15 so that the OpenAI/Codex card on Console Home replaces the redundant `Status` metric with a raw `Credits balance` metric sourced from the existing `/backend-api/wham/usage` response, without currency conversion or unrelated UI changes.

## Confirmed Product Decisions

- The metric title is `Credits balance` in English and `Credits 余额` in Chinese.
- Display the raw `credits.balance` value with the `Credits` unit; do not convert it to money.
- If `credits.unlimited` is true, display localized `Unlimited` / `无限`.
- If credits are absent or invalid, display `--` while preserving successfully decoded 5h/1W quota data.
- Only the OpenAI/Codex Console Home card replaces `Status`; other providers remain unchanged.
- The existing top status badge remains the availability/status signal.
- Menubar output, detail-sheet content, panel geometry, corner radius, materials, and transparency are out of scope.
- Reuse the existing `/wham/usage` request and authentication path; add no account, currency, pricing, or conversion endpoints.

## Execution Plan

- [x] Phase 1 — Create `.worktrees/v0.3.15` from the existing `v0.3.15` branch and verify a clean baseline.
- [x] Phase 2 — Code implementation agent uses TDD to model/decode optional raw Credits, format the value, expose it in Console Home, localize labels, and bump v0.3.15 metadata.
- [x] Phase 3 — Initial acceptance agent independently reviews the completed diff, model boundaries, parser behavior, localization, and test coverage.
- [x] Phase 4 — UI guardian independently verifies that only the intended Console Home metric changes and that Menubar/detail/material/radius/transparency behavior remains untouched.
- [x] Phase 5 — Primary agent resolves findings, runs full Core tests, build, diff checks, local app bundle build, version checks, and targeted UI evidence collection.
- [x] Phase 6 — Commit the verified v0.3.15 implementation in reviewable commits and deliver the final acceptance report. Publishing/release remains a separate explicit step.
- [x] Phase 7 — Prepare bilingual v0.3.15 release documentation, README/roadmap release references, and user-facing GitHub release notes; commit the release-preparation changes on `v0.3.15` as `e04ca3f`.
- [ ] Phase 8 — Re-run release-candidate tests/build and confirm branch, version, diff, remote, and GitHub authentication gates.
- [ ] Phase 9 — Fast-forward `v0.3.15` into the root `main` checkout without touching its pre-existing untracked files; re-run merged-main verification.
- [ ] Phase 10 — Package the macOS app and DMG from merged `main`; validate bundle metadata, strict codesign, DMG structure/mount, SHA-256, and exact artifact names.
- [ ] Phase 11 — Create annotated tag `release/v0.3.15`, push main and tag, publish a non-draft/non-prerelease GitHub Release with exactly the DMG and `.sha256`, verify remote state/assets, then perform only the documented release cleanup.

## Acceptance Criteria

- `/wham/usage` fixtures with numeric or string Credits balance decode successfully.
- Explicit zero renders as `0 Credits`; unlimited renders localized unlimited text; absent/malformed credits render `--`.
- Credits decode/format failures do not discard valid 5h/1W quota data.
- OpenAI/Codex Console Home displays `Credits balance` / `Credits 余额` in place of `Status`.
- Other providers retain their existing Status metric.
- Existing OpenAI/Codex header status badge and quota detail metric remain unchanged.
- Menubar and detail panel outputs remain unchanged under regression tests/review.
- Chinese and English strings are covered.
- `swift run APIInquiryCoreTestsRunner`, `swift build`, and `Scripts/build-local-app.sh` pass.
- Built application reports v0.3.15 metadata.

## Agent Ownership

- Primary `/root`: overall design boundary, worktree/plan coordination, integration, remediation, final build and acceptance.
- `credits_implementation`: TDD implementation in the v0.3.15 worktree; recommended model `gpt-5.6-luna`, reasoning `max`.
- `initial_acceptance`: independent code/model/test acceptance; no edits unless explicitly reassigned.
- `ui_guardian`: UI regression guard for Console Home, Menubar, detail panel, corner radius and transparency; no edits unless explicitly reassigned.
- `github_release_operator`: execute the standard release flow under primary-agent gates using `gpt-5.6-luna` with max reasoning.

## Errors Encountered

| Error | Attempt | Resolution |
| --- | --- | --- |
| Stale planning files described v0.3.11 | Planning-session recovery | Replaced them with this v0.3.15 plan before implementation. |
| First patch tried deleting and adding the same paths in one operation | Plan-file refresh | Split deletion and creation into separate patches. |
| Git could not create `.git/index.lock` in the sandbox | First root-to-worktree migration attempt | Commit the plan on v0.3.15, then rerun the Git-only migration with approved repository-metadata access. |
| Process-list diagnostic was blocked by the sandbox | Attempted to check whether Swift was already running | Avoided further process inspection; agents coordinate test execution through completion messages and Git state. |
| Primary-agent SwiftPM run failed at manifest `sandbox-exec` | First local-cache test attempt | Re-run the identical test in the approved host environment while retaining worktree-local module/scratch caches. |
| New release-agent spawn hit the thread limit | Attempted to create a fourth historical sub-agent | Reuse the completed `credits_implementation` agent, which already runs `gpt-5.6-luna` with max reasoning, and assign it the release operation. |

## Current Status

Phases 1–7 are complete. Phase 8 RC verification is pending the next explicitly authorized release stage.
