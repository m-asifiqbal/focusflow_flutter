# Screen 32 — Settings › Appearance

**Design file:** `design/32_settings_appearance.png`  ·  **Route:** `/settings/appearance`  ·  **Feature folder:** `lib/features/settings/`
**Read first:** `prompts/00_MASTER_PROMPT.md`, `prompts/01_DESIGN_SYSTEM.md`

> Prompt for Claude Code: *"Implement Screen 32 — Settings › Appearance in Flutter exactly as shown in `design/32_settings_appearance.png`, following the spec below and the shared design-system widgets. Wire it to real Riverpod providers and the Drift repositories (no mock data except in widget tests). Add a widget test and a golden test."*

## Purpose
Theme, accent colour, text size, app icon and layout density.

## Layout (top → bottom)
1. THEME: 3 phone-preview cards Light / Dark / System (selected ring + check).
2. ACCENT COLOUR: 6 swatches (emerald default, blue, indigo, pink, orange, slate).
3. TEXT SIZE slider A–A with live preview text.
4. APP ICON: Default, Mint, Night, Mono (alternate icons: `flutter_dynamic_icon` iOS / activity-alias Android).
5. LAYOUT: Notes default view, List density, Reduce motion, Use system font.

## Interactions & behaviour
- Accent swaps the `primary` token family at runtime (ThemeExtension).
- Instant preview without restart.

## States
- —

## Data & state
- `themeControllerProvider`.

## Navigation
- Back to Settings.

## Acceptance checklist
- [ ] All screens respect accent & text size.
- [ ] Visually matches the PNG (spacing, radius, colours, fonts, icons) in light mode; dark mode works from tokens.
- [ ] No overflow at text scale 1.3 and on 360-pt-wide devices; semantics labels on icon buttons.
- [ ] `flutter analyze` clean; widget + golden test added.
