# Screen 14 — Habits list

**Design file:** `design/14_habits_list.png`  ·  **Route:** `/library/habits`  ·  **Feature folder:** `lib/features/habits/`
**Read first:** `prompts/00_MASTER_PROMPT.md`, `prompts/01_DESIGN_SYSTEM.md`

> Prompt for Claude Code: *"Implement Screen 14 — Habits list in Flutter exactly as shown in `design/14_habits_list.png`, following the spec below and the shared design-system widgets. Wire it to real Riverpod providers and the Drift repositories (no mock data except in widget tests). Add a widget test and a golden test."*

## Purpose
Track today's habits with one-tap check-ins, rings, weekly dots and streaks.

## Layout (top → bottom)
1. Large header 'Habits' + '2 of 5 done today'; stats + more buttons.
2. Indigo→violet gradient hero: white ring 72 with 40% + 'Keep the chain going!' + longest active streak.
3. Chips: Today, All habits, Morning, Evening, Archived.
4. Habit cards: ring 50 (habit colour) with icon, name, progress text ('6 / 8 glasses' / 'Completed' / schedule), right action button (outlined + when pending, filled check when done). Footer: 7 weekday squares (filled = done) + streak '🔥 12 days' in orange.

## Interactions & behaviour
- Tap + → increment count (or toggle). Long-press + → enter custom amount / skip today.
- Tap card → Habit detail (16). Swipe → Archive/Delete. Drag to reorder.
- Quit-habits (e.g. 'No sugar') count days since last slip; check = 'clean today'.
- Day resets at user's 'Habit reset time' (Settings › Habits).

## States
- Empty, all done ('Perfect day!' confetti once), not scheduled today (greyed with 'Rest day').

## Data & state
- `todayHabitsProvider`, `habitStreakProvider(habitId)` (pure function over logs, unit-tested).

## Navigation
- From Library/Home rings.

## Acceptance checklist
- [ ] Streak logic respects frequency (weekdays-only habits don't break on weekends).
- [ ] Visually matches the PNG (spacing, radius, colours, fonts, icons) in light mode; dark mode works from tokens.
- [ ] No overflow at text scale 1.3 and on 360-pt-wide devices; semantics labels on icon buttons.
- [ ] `flutter analyze` clean; widget + golden test added.
