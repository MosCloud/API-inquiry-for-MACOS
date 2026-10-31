# Repository layout

Where each kind of file lives, and where new ones belong. Keep this page in sync when
the structure changes; the pairs are `docs/repository-layout.md` / `_zh.md`.

```text
AGENTS.md                  agent contract for this repository
AGENT.md / AGENT_zh.md     redirect stubs, kept so links in old plans still resolve
README.md                  Chinese readme (the canonical one); README_en.md is English
Package.swift              SwiftPM manifest: one library plus two executables
Scripts/                   executable tooling — see Scripts/README.md
Sources/
  APIInquiryCore/          all logic, UI-free; subfolders are domains, tests live beside them
  APIInquiryApp/           SwiftUI + AppKit, grouped by surface:
    App/                   entry point, lifecycle, app-wide support
    MenuBar/               the status-bar panel
    Console/               the local console window
    Providers/             provider logos, badges, visual catalog
    Resources/             images bundled into the app; keep this path — generate-app-icon.swift reads it
  APIInquiryCoreTestsRunner/  custom test runner (no XCTest target)
docs/
  release-runbook*.md      release procedure, bilingual pair
  roadmap.md               capabilities and near-term plan
  releases/                per-version release notes
  superpowers/             historical plans and specs (frozen, links point into it)
  assets/                  screenshots used by the READMEs (fixed raw.githubusercontent URLs)
.github/workflows/         CI, runs only for release/* tags
dist/ .build/ .worktrees/  generated, gitignored
CLAUDE.md docs/agents/ docs/reviews/  local-only notes, gitignored by design
```

## Where new things go

- **Core logic** → `Sources/APIInquiryCore/<domain>/`. Never in the App target.
- **A view** → the surface it belongs to: `MenuBar/`, `Console/`, or `App/` for app-wide pieces.
- **Provider assets** → `Sources/APIInquiryApp/Resources/` with the `<id>-logo-header` /
  `<id>-menu-icon-template` naming, plus the matching entry in `ProviderVisualCatalog`.
- **A script** → `Scripts/` with a phase prefix (`build-`, `package-`, `install-`), and a row
  in `Scripts/README.md`.
- **Documentation** → `docs/`. Release-procedure changes go into the runbook pair; a new
  design note goes under `docs/superpowers/specs/`.
- **Local notes** → `CLAUDE.md`, `docs/agents/`, `docs/reviews/`; they stay untracked and may
  lag behind the code.

## Why not flatter or deeper

Scripts are named by phase already, so moving them into subfolders would rewrite about 45
references for no functional gain. `docs/superpowers/` holds ~67 interlinked historical files;
renaming it would break those links. `docs/assets/` paths are embedded in README image URLs
served from `raw.githubusercontent.com`, so moving them breaks the published page.
