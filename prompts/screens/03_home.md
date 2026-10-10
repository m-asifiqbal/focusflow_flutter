# Screen 03 — Home (Today dashboard)

**Design file:** `design/03_home.png`  ·  **Route:** `/home (tab 1)`  ·  **Feature folder:** `lib/features/home/`
**Read first:** `prompts/00_MASTER_PROMPT.md`, `prompts/01_DESIGN_SYSTEM.md`

> Prompt for Claude Code: *"Implement Screen 03 — Home (Today dashboard) in Flutter exactly as shown in `design/03_home.png`, following the spec below and the shared design-system widgets. Wire it to real Riverpod providers and the Drift repositories (no mock data except in widget tests). Add a widget test and a golden test."*

## Purpose
Daily command centre: greeting, today's progress across modules, week strip, next reminder, today's tasks, recent notes and habit rings.

## Layout (top → bottom)
1. Header: avatar 44 (initial on gradient, white 3px border) + date overline (11.5 w800 emerald-600/70, e.g. 'TUESDAY, JUNE 13') + 'Good morning, Asif' 19 w700 (time-aware: morning/afternoon/evening). Right: round Search button and round Bell with red unread dot.
2. **Today's Focus** hero card (gradient, radius 28, decorative white circle top-right): title, encouragement line (dynamic), % pill, white progress bar, 3 glass stat tiles: Tasks 4/7, Habits 2/4, Reminders 3.
3. Section 'June 2023' + 'View Monthly' link → horizontal week strip of day pills (52 wide, radius 18). Selected day filled emerald with white text + dot; days with items show emerald dot.
4. Section 'Up Next' + 'All Reminders': orange-tinted card with next reminder (icon tile, title, 'in 25 min · 10:00 AM', **Snooze** pill).
5. Section 'Today's Tasks' + 'N LEFT' badge: up to 5 task rows (check circle, title, time, tag, pin icon). Completed rows struck-through at 40% opacity.
6. Section 'Recent Notes' + 'See All': 2-column note previews (pinned note uses its colour; checklist note renders checkboxes).
7. Section 'Habit Tracker' + 'Trends': card with 4 progress rings (module colour per habit) + labels.
8. Bottom nav (Home active) with centre FAB.

## Interactions & behaviour
- Tap a day in the strip → filters 'Today's Tasks' and 'Up Next' to that date (header label changes to that date).
- Tap check circle → completes task with haptic + animation; Undo snackbar.
- Snooze → snooze by default minutes, card updates.
- Tap habit ring → +1 log (or toggle for yes/no habits); long-press → Habit detail.
- Home sections are customisable in Settings › Home layout (show/hide/reorder). Pull to refresh = sync.
- Bell → Notification center (27). Search → Global search (06). View Monthly → Calendar (26).

## States
- Empty day: friendly empty card per section with inline 'Add task' / 'Add reminder' buttons.
- First-run: show a 3-step 'Get started' checklist card in place of tasks.
- Skeleton shimmer while first DB load.

## Data & state
- `homeSummaryProvider(date)` combines streams from tasks, habits, reminders.
- `todayTasksProvider(date)`, `nextReminderProvider`, `recentNotesProvider(limit:4)`, `todayHabitsProvider`.
- `greetingProvider` (time-of-day).

## Navigation
- Tab root. FAB → Quick Add (04). Items → their editors/detail screens.

## Acceptance checklist
- [ ] Progress numbers update live when completing items on other screens.
- [ ] Greeting changes by time of day; week strip scrolls and starts on the user's 'Week starts on' setting.
- [ ] Visually matches the PNG (spacing, radius, colours, fonts, icons) in light mode; dark mode works from tokens.
- [ ] No overflow at text scale 1.3 and on 360-pt-wide devices; semantics labels on icon buttons.
- [ ] `flutter analyze` clean; widget + golden test added.
