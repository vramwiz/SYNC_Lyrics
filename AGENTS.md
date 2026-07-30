# SYNC_Lyrics agent guidance

## Context loading

- Start with `note.md`; it is the compact source of the current development state.
- Read only the relevant sections of `DESIGN.md` and `DEVELOPMENT.md`.
- Do not read `HISTORY.md` unless the task requires past decisions, regressions, or release history.
- Do not recursively inspect `.git/`, `Win32/`, `Win64/`, `Tests/Win64/`, `__history/`, or `__recovery/`.
- Do not inspect `ThirdParty/FFmpeg/bin/` unless the task concerns FFmpeg deployment or dependencies.
- Prefer targeted `rg` searches and open only files related to the requested change.

## Working rules

- Preserve unrelated user changes in the working tree.
- Follow the applicable rules in `DEVELOPMENT.md` for builds, tests, distribution, comments, and Git operations.
- When current priorities change, keep `note.md` concise.
- Record completed implementation and verification summaries in `HISTORY.md`; do not grow `note.md` with dated logs.
