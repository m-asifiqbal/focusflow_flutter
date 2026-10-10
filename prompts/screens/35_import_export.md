# Screen 35 — Settings › Import & Export

**Design file:** `design/35_import_export.png`  ·  **Route:** `/settings/import-export`  ·  **Feature folder:** `lib/features/backup/`
**Read first:** `prompts/00_MASTER_PROMPT.md`, `prompts/01_DESIGN_SYSTEM.md`

> Prompt for Claude Code: *"Implement Screen 35 — Settings › Import & Export in Flutter exactly as shown in `design/35_import_export.png`, following the spec below and the shared design-system widgets. Wire it to real Riverpod providers and the Drift repositories (no mock data except in widget tests). Add a widget test and a golden test."*

## Purpose
Export selected data in multiple formats and import from other apps.

## Layout (top → bottom)
1. Segmented Export / Import.
2. FORMAT tiles: .ffbackup (Full · encrypted, selected), JSON, CSV, PDF/MD (notes only).
3. INCLUDE checklist per module with counts (Vault unchecked by default), switches Include archived, Include attachments.
4. Amber warning: vault only exported encrypted.
5. SAVE TO tiles: Google Drive, This device, Share….
6. Primary 'Export 89 items'.
7. IMPORT FROM OTHER APPS pills: Google Keep, Todoist, Bitwarden CSV, 1Password, Loop Habit, Evernote (.enex).

## Interactions & behaviour
- Import tab: pick file → detect format → preview mapping & counts → Import (dedupe by title+date).
- CSV vault import immediately encrypts and deletes the temp file.

## States
- Progress, success summary, partial-failure report.

## Data & state
- `exportServiceProvider`, `importServiceProvider` with pluggable parsers.

## Navigation
- From Settings.

## Acceptance checklist
- [ ] Each parser has fixture-based tests.
- [ ] Visually matches the PNG (spacing, radius, colours, fonts, icons) in light mode; dark mode works from tokens.
- [ ] No overflow at text scale 1.3 and on 360-pt-wide devices; semantics labels on icon buttons.
- [ ] `flutter analyze` clean; widget + golden test added.
