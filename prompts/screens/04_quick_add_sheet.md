# Screen 04 — Quick Add sheet ('What's next?')

**Design file:** `design/04_quick_add_sheet.png`  ·  **Route:** `modal from FAB`  ·  **Feature folder:** `lib/features/quick_add/`
**Read first:** `prompts/00_MASTER_PROMPT.md`, `prompts/01_DESIGN_SYSTEM.md`

> Prompt for Claude Code: *"Implement Screen 04 — Quick Add sheet ('What's next?') in Flutter exactly as shown in `design/04_quick_add_sheet.png`, following the spec below and the shared design-system widgets. Wire it to real Riverpod providers and the Drift repositories (no mock data except in widget tests). Add a widget test and a golden test."*

## Purpose
Two-tap capture of anything; also natural-language quick capture.

## Layout (top → bottom)
1. Underlying screen dimmed: emerald-950 @45% + blur 3.
2. Sheet (bg #F7FBFA, top radius 34, handle 44×6).
3. Title 'What's next?' 23 w700 centred + subtitle 'Capture anything in two taps'.
4. Quick-capture field (52 h, white, emerald-100 border): wand icon, placeholder 'Try “Pay rent tomorrow 9am”', mic icon.
5. 3×2 grid of tiles (radius 22): Note, Task, Reminder, Habit, Password, Scan — each solid module icon tile 46, title 15 w600, uppercase caption (Ideas, To-dos, Alerts, Routine, Secure, OCR).
6. Cancel button (white, 52 h).

## Interactions & behaviour
- Tile → opens the matching editor (08, 11, 13, 15, 20). Password requires vault unlock first (17) then editor.
- Scan → camera/gallery → ML Kit OCR → creates a Note prefilled with recognised text, opens editor.
- Quick capture: parse with a local rule-based parser (dates: today/tomorrow/weekday/'next week', times '9am', '14:30', 'every day/week' → repeat; '!high' priority; '#tag'). If it contains a time → Reminder, if has date but no time → Task, else Note. Show a parsed-preview chip row above keyboard ('Task · Tomorrow 9:00 AM · #home') before saving. Mic uses speech-to-text (`speech_to_text`).
- Drag down / tap backdrop / Cancel closes.

## States
- Default; quick-capture typing with preview; mic listening (pulsing mic).

## Data & state
- `quickCaptureParserProvider` (pure Dart, unit-tested with 20+ phrases).

## Navigation
- Opened from the FAB on any tab; returns to the previous tab after save.

## Acceptance checklist
- [ ] Parser unit tests pass for EN phrases above.
- [ ] Sheet height fits content; works with keyboard open.
- [ ] Visually matches the PNG (spacing, radius, colours, fonts, icons) in light mode; dark mode works from tokens.
- [ ] No overflow at text scale 1.3 and on 360-pt-wide devices; semantics labels on icon buttons.
- [ ] `flutter analyze` clean; widget + golden test added.
