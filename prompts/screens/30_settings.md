# Screen 30 — Settings (main)

**Design file:** `design/30_settings.png`  ·  **Route:** `/settings (tab 4)`  ·  **Feature folder:** `lib/features/settings/`
**Read first:** `prompts/00_MASTER_PROMPT.md`, `prompts/01_DESIGN_SYSTEM.md`

> Prompt for Claude Code: *"Implement Screen 30 — Settings (main) in Flutter exactly as shown in `design/30_settings.png`, following the spec below and the shared design-system widgets. Wire it to real Riverpod providers and the Drift repositories (no mock data except in widget tests). Add a widget test and a golden test."*

## Purpose
Comprehensive settings hub with search.

## Layout (top → bottom)
1. Large header 'Settings'; search 'Search settings…'.
2. Account card: avatar, name, Google email with G logo, 'SYNCED 2 MIN AGO' pill → Account (36).
3. GENERAL: Language, Start screen, Week starts on, Date & time format.
4. PREFERENCES: Notifications & Reminders (31), Appearance (32), Pinned items, Home layout & widgets, Gestures & swipe actions, Sounds & haptics.
5. MODULES: Notes, Tasks, Reminders, Habits (defaults per module), Tags & folders.
6. SECURITY & PRIVACY: Vault security (33), App lock, Hide content in app switcher (switch), Clear clipboard after.
7. DATA & SYNC: Backup & Sync (34), Import & Export (35), Storage, Archive, Recently deleted.
8. SUPPORT: Help & Support, Send feedback, Rate FocusFlow, About (version).
9. Sign out button (rose text) + footer.

## Interactions & behaviour
- Settings search filters all rows across sub-pages (index of titles/keywords) and deep-links.
- Module sub-pages: Notes (default view, sort, default colour), Tasks (default list, smart lists, show completed), Reminders (default snooze, sound), Habits (reset time, week start), Home layout (reorder sections), Gestures (configure swipe left/right per module), App lock (PIN/biometric for whole app).

## States
- Signed-out variant: account card says 'Sign in to back up' with Google button.

## Data & state
- `settingsProvider` backed by shared_preferences (typed `AppSettings` freezed model).

## Navigation
- Tab root; pushes sub-pages.

## Acceptance checklist
- [ ] Every setting persists and takes effect immediately.
- [ ] Visually matches the PNG (spacing, radius, colours, fonts, icons) in light mode; dark mode works from tokens.
- [ ] No overflow at text scale 1.3 and on 360-pt-wide devices; semantics labels on icon buttons.
- [ ] `flutter analyze` clean; widget + golden test added.
