# Screen 16 — Habit detail & stats

**Design file:** `design/16_habit_detail.png`  ·  **Route:** `/habits/:id`  ·  **Feature folder:** `lib/features/habits/`
**Read first:** `prompts/00_MASTER_PROMPT.md`, `prompts/01_DESIGN_SYSTEM.md`

> Prompt for Claude Code: *"Implement Screen 16 — Habit detail & stats in Flutter exactly as shown in `design/16_habit_detail.png`, following the spec below and the shared design-system widgets. Wire it to real Riverpod providers and the Drift repositories (no mock data except in widget tests). Add a widget test and a golden test."*

## Purpose
Deep view of one habit: today's progress, streaks, consistency heatmap, monthly chart and history.

## Layout (top → bottom)
1. Header: back, 'Habit', edit + more.
2. Big ring 132 (75%) with icon and '6/8'. Name 24 w700 + meta line.
3. Buttons: '+ Log 1 glass' (habit colour, shadow) and 'Skip today' (white).
4. 2×2 stat cards: Current streak (orange), Best streak (indigo), Completion % last 30 days (emerald), Total check-ins (blue).
5. Consistency heatmap (GitHub style, 17 weeks × 7 days, 4 opacity levels, future days dashed) + Less/More legend.
6. Monthly completion bar chart (6 months, current month solid).
7. History list (date, description, % or Skip) + 'See all'.

## Interactions & behaviour
- Tap heatmap cell → bottom sheet to edit that day's log (count / skip / note).
- Range selector on heatmap: 4 months / 1 year.
- More → Pause habit, Archive, Delete, Export CSV.

## States
- New habit with no data: placeholders + 'Your stats appear after the first check-in'.

## Data & state
- `habitDetailProvider(id)` → stats computed in an isolate for big histories.

## Navigation
- Push from Habits list.

## Acceptance checklist
- [ ] Heatmap & stats match logs exactly (unit tests on stats calculator).
- [ ] Visually matches the PNG (spacing, radius, colours, fonts, icons) in light mode; dark mode works from tokens.
- [ ] No overflow at text scale 1.3 and on 360-pt-wide devices; semantics labels on icon buttons.
- [ ] `flutter analyze` clean; widget + golden test added.
