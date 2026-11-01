# How to write release copy

A release produces three kinds of text, each with a different reader:

| Text | Reader | Question it answers |
|---|---|---|
| Release notes (`docs/releases/vX.Y.Z_github.md`) | People who use the app | What changed for me in this version? |
| CHANGELOG (`CHANGELOG.md` / `CHANGELOG_zh.md`) | People tracing history, contributors | What changed in which version? |
| `docs/releases/vX.Y.Z.md` / `_zh.md` | The same readers, one language only | Same question, one language |

The same change may appear in all three, but the **depth must differ**: release notes describe
what you perceive, the CHANGELOG records facts and numbers.

## Release notes

### Structure

Three sections only; omit any that is empty:

- New Features
- App Optimization
- Bug Fixes

One line per change: a bold phrase naming the change, then one sentence saying what it means
for the person using the app.

### Only perceptible changes

The test: after upgrading, will someone notice this in the UI, or will it change how they
use the app?

```
Good: A shorter panel: the hero area keeps only the current window and folds the rest
      into one summary line.
Bad:  The panel went from 442pt to 364pt.
```

The second is written for a developer and belongs in the CHANGELOG.

### Leave out

- Specific numbers (18%, 442pt, 39pt columns) — they go in the CHANGELOG
- File names, internal type names, framework names
- Test counts, build flags
- Engineering narration ("we refactored…", "we unified…")
- Docs, licence, CI and script changes — nobody perceives them
- Repeated complaints about the old behaviour (say "no longer…" once)

### Voice

Statements, short sentences, no superlatives. People spend about ten seconds on release notes.

### Volume

- 3–6 new features
- 3–8 improvements
- 2–6 fixes

Beyond that, the release is probably too large, or internal work leaked in.

## CHANGELOG

Follow [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and SemVer:

- Newest version first, heading `## [x.y.z] - YYYY-MM-DD`
- Section mapping: Added, Changed, Fixed, Removed
- **Technical detail belongs here**: numbers, internal refactors, docs and tooling changes
- One line per change; link the issue/PR where it exists, e.g. `(#80)`
- The two languages mirror each other: same version headings, same section order, same bullet counts
- On release day, fold `[Unreleased]` into the new version section, stamp the date, leave
  `[Unreleased]` empty

## Deciding where a change goes

Ask three questions in order:

1. **Will a user notice it?** No → CHANGELOG only (or just the commit).
2. **Can it be said in one sentence of user language?** Yes → one line in release notes, details in the CHANGELOG.
3. **Does it change behaviour or implementation?** Behaviour → release notes; implementation → CHANGELOG.

## Worked example: v0.4.0

| First draft | Release notes | CHANGELOG |
|---|---|---|
| Panel height reduced by ~18% | The panel height was tightened | 442pt → 364pt |
| Columns shrink to their content instead of fixed reservations | (omitted) | typical widths 39 / 48 / 65pt |
| The four wordmarks scale from one optical baseline | Every logo finally renders at a consistent size | scaled from a shared cap-height baseline |

The pattern: **every number removed from the release notes reappears in the CHANGELOG**. No
information is lost; it just moved to the reader who wants it.

## Checklist

```
[ ] Release notes have only New Features / App Optimization / Bug Fixes; empty sections dropped
[ ] Each line starts with a bold phrase and explains what the user feels
[ ] No numbers, file names, type names, test counts, framework names or refactor wording
[ ] Docs / licence / CI / script changes are absent from the notes
[ ] CHANGELOG folded Unreleased with the release date
[ ] Both languages have identical headings, sections and bullet counts
[ ] Every number dropped from the notes can be found in the CHANGELOG
```
