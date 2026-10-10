# Screen 37 — Home — Dark mode reference

**Design file:** `design/37_home_dark.png`  ·  **Route:** `/home (dark)`  ·  **Feature folder:** `lib/features/home/`
**Read first:** `prompts/00_MASTER_PROMPT.md`, `prompts/01_DESIGN_SYSTEM.md`

> Prompt for Claude Code: *"Implement Screen 37 — Home — Dark mode reference in Flutter exactly as shown in `design/37_home_dark.png`, following the spec below and the shared design-system widgets. Wire it to real Riverpod providers and the Drift repositories (no mock data except in widget tests). Add a widget test and a golden test."*

## Purpose
Reference for the dark theme applied to all non-vault screens.

## Layout (top → bottom)
1. Same structure as Home (03).
2. Canvas #06231C; cards white 4% + 10% border; text white; muted emerald-100/50; hero keeps gradient; FAB ring matches canvas; tab bar #0B2E25 @95%.

## Interactions & behaviour
- Theme switches instantly from Appearance (32) or system.

## States
- —

## Data & state
- `themeControllerProvider`.

## Navigation
- —

## Acceptance checklist
- [ ] Every screen golden-tested in dark mode too.
- [ ] Visually matches the PNG (spacing, radius, colours, fonts, icons) in light mode; dark mode works from tokens.
- [ ] No overflow at text scale 1.3 and on 360-pt-wide devices; semantics labels on icon buttons.
- [ ] `flutter analyze` clean; widget + golden test added.
