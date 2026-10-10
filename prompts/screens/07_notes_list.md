# Screen 07 — Notes list

**Design file:** `design/07_notes_list.png`  ·  **Route:** `/library/notes`  ·  **Feature folder:** `lib/features/notes/`
**Read first:** `prompts/00_MASTER_PROMPT.md`, `prompts/01_DESIGN_SYSTEM.md`

> Prompt for Claude Code: *"Implement Screen 07 — Notes list in Flutter exactly as shown in `design/07_notes_list.png`, following the spec below and the shared design-system widgets. Wire it to real Riverpod providers and the Drift repositories (no mock data except in widget tests). Add a widget test and a golden test."*

## Purpose
Browse, filter and manage all notes in a masonry grid (default) or list view.

## Layout (top → bottom)
1. Large header 'Notes' + '48 notes · 3 pinned'; buttons: view toggle (grid/list), More.
2. Search field 'Search notes…' with filter icon.
3. Folder/tag chips: All, Ideas, Work, Personal, Travel… (+ '+ New folder' at end).
4. Row: sort label ('Last edited' with sort icon) left, 'Select' right.
5. 2-column **masonry** of note cards (radius 22): tag, pin icon, title 15.5 w600, preview (max 6 lines), optional cover image, checklist preview, footer meta 'TODAY · IDEAS'. Card background = note colour.
6. Pinned notes always first.

## Interactions & behaviour
- Tap → Note editor (08). Long-press → Item actions sheet (09). Select → multi-select with checkmarks (top-right circle) and bottom bar (Pin, Tag, Archive, Delete).
- Sort options: Last edited, Created, Title A–Z, Colour, Manual (drag).
- View toggle persisted (Settings › Notes default view). List view = compact rows with tile, title, 1-line preview, date.
- Locked notes show a lock icon and blurred preview.

## States
- Empty (no notes): empty state with 'Write your first note'. Empty filter: 'No notes in Work'.

## Data & state
- `notesListProvider(filter, sort)` stream.
- `noteFoldersProvider`.

## Navigation
- From Library or Home 'See All'. Back to Library.

## Acceptance checklist
- [ ] Masonry stays stable while items update.
- [ ] Multi-select bulk actions work with Undo.
- [ ] Visually matches the PNG (spacing, radius, colours, fonts, icons) in light mode; dark mode works from tokens.
- [ ] No overflow at text scale 1.3 and on 360-pt-wide devices; semantics labels on icon buttons.
- [ ] `flutter analyze` clean; widget + golden test added.
