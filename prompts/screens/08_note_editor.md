# Screen 08 — Note editor

**Design file:** `design/08_note_editor.png`  ·  **Route:** `/notes/:id (new: /notes/new)`  ·  **Feature folder:** `lib/features/notes/`
**Read first:** `prompts/00_MASTER_PROMPT.md`, `prompts/01_DESIGN_SYSTEM.md`

> Prompt for Claude Code: *"Implement Screen 08 — Note editor in Flutter exactly as shown in `design/08_note_editor.png`, following the spec below and the shared design-system widgets. Wire it to real Riverpod providers and the Drift repositories (no mock data except in widget tests). Add a widget test and a golden test."*

## Purpose
Distraction-free rich-text editor with auto-save, tags, checklists, colours and attachments.

## Layout (top → bottom)
1. White canvas. Header: back round button, centre folder name + 'AUTO-SAVED' (cloud icon, 10 w800 emerald), right Pin + More buttons.
2. Tag row: folder tag, #tags, '+' add.
3. Title 27 w700 (multi-line, placeholder 'Title').
4. Meta line: 'Edited today, 9:12 AM · 214 words · 🔔 Reminder Fri'.
5. Body rich text (Quill): paragraphs 15.5/1.75, H3 headings Lexend 18, bold, checklists (emerald checkboxes), quote block (left 4px emerald border, italic).
6. Bottom toolbar (white, radius 26 top): colour swatches row (white, mint, amber, blue, pink, violet) + Undo; formatting icons: Heading, Bold, Italic, Bullet list, Checklist, Quote, Image, Voice.

## Interactions & behaviour
- Auto-save debounced 600 ms + on back; show 'Saving…' then 'AUTO-SAVED'.
- Toolbar sits above keyboard; colour change updates note card colour.
- More menu: Share/Export (PDF, TXT, Markdown), Duplicate, Move to folder, Set reminder (opens 13 linked), Lock note, Word count, Archive, Delete.
- Image → gallery/camera, stored in attachments; Voice → speech-to-text inserts text.
- Empty new note discarded automatically on back.

## States
- New, editing, locked (requires vault PIN), read-only (in archive).

## Data & state
- `noteEditorController(id)` (AsyncNotifier) with Quill controller, debounced save to `NotesRepository`.

## Navigation
- Back returns to previous list; deep link from reminder notification opens here.

## Acceptance checklist
- [ ] No data loss on app kill (save on lifecycle pause).
- [ ] Undo/redo works.
- [ ] Visually matches the PNG (spacing, radius, colours, fonts, icons) in light mode; dark mode works from tokens.
- [ ] No overflow at text scale 1.3 and on 360-pt-wide devices; semantics labels on icon buttons.
- [ ] `flutter analyze` clean; widget + golden test added.
