# Screen 05 — Library (all spaces hub)

**Design file:** `design/05_library.png`  ·  **Route:** `/library (tab 2)`  ·  **Feature folder:** `lib/features/library/`
**Read first:** `prompts/00_MASTER_PROMPT.md`, `prompts/01_DESIGN_SYSTEM.md`

> Prompt for Claude Code: *"Implement Screen 05 — Library (all spaces hub) in Flutter exactly as shown in `design/05_library.png`, following the spec below and the shared design-system widgets. Wire it to real Riverpod providers and the Drift repositories (no mock data except in widget tests). Add a widget test and a golden test."*

## Purpose
One place to see every module with counts and jump to each list, plus Pinned, Favourites, Tags, Archive and Recently Deleted — the 'lists view for all features' hub.

## Layout (top → bottom)
1. Large header 'Library' + subtitle '113 items across 5 spaces'; Search & More buttons.
2. 2-column module cards (radius 22, white, soft module-colour circle bottom-right): solid icon tile 42, big count 26 + module name, highlight line in module ink (e.g. '7 due today'), muted second line. Vault card spans 2 columns with lock icon when locked.
3. Section 'COLLECTIONS': grouped list rows — Pinned (9), Favourites (14), Tags & Folders (11), Archive (37), Recently Deleted (5, subtitle 'Auto-deletes after 30 days').
4. Section 'TAGS': wrap of tag pills (#work …).

## Interactions & behaviour
- Card tap → module list (07/10/12/14/17). More menu → reorder/hide modules, 'Show counts'.
- Pinned/Favourites open a mixed list (all modules, grouped by module, same row widgets). Tag tap → mixed list filtered by tag.
- Long-press tag → rename/colour/delete tag.

## States
- Counts load with skeletons; zero states show '0 Notes · Create your first'.

## Data & state
- `libraryCountsProvider` (stream of counts per module + archive/trash/pinned/fav).
- `tagsProvider`.

## Navigation
- Tab root; pushes module routes inside the Library branch so the tab bar stays visible.

## Acceptance checklist
- [ ] All counts live-update.
- [ ] Vault card never reveals secrets; shows 'Locked' / 'Unlocked'.
- [ ] Visually matches the PNG (spacing, radius, colours, fonts, icons) in light mode; dark mode works from tokens.
- [ ] No overflow at text scale 1.3 and on 360-pt-wide devices; semantics labels on icon buttons.
- [ ] `flutter analyze` clean; widget + golden test added.
