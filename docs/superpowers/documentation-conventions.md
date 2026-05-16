# Documentation Conventions

## Bilingual Documents

Project planning documents should be created in paired English and Chinese versions by default.

For each substantial document:

- Create the English source document as `<name>.md`.
- Create the Chinese version as `<name>_zh.md`.
- Keep both versions semantically synchronized when adding, removing, or changing content.
- Prefer reviewing the Chinese version with the user when the conversation is in Chinese.

This convention applies to design specs, implementation plans, review notes, and similar project documents.

## Release Notes

Release notes should only include:

- New features added in the released version.
- Bug fixes for issues that existed in the previous published version.

Do not list bugs that were introduced and fixed during the same unreleased development cycle.
