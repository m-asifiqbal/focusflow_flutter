# Screen 29 — Empty state pattern

**Design file:** `design/29_empty_state.png`  ·  **Route:** `any list`  ·  **Feature folder:** `lib/features/core/widgets/`
**Read first:** `prompts/00_MASTER_PROMPT.md`, `prompts/01_DESIGN_SYSTEM.md`

> Prompt for Claude Code: *"Implement Screen 29 — Empty state pattern in Flutter exactly as shown in `design/29_empty_state.png`, following the spec below and the shared design-system widgets. Wire it to real Riverpod providers and the Drift repositories (no mock data except in widget tests). Add a widget test and a golden test."*

## Purpose
Reusable friendly empty state (Reminders shown).

## Layout (top → bottom)
1. Normal list header + chips.
2. Illustration: concentric soft circles in module colour + rotated module tile with icon + small stars.
3. Title 22 w700 'All clear for today', body 14.5 muted, primary button 'Add a reminder', hint text example.

## Interactions & behaviour
- Each module provides its own copy + CTA. Hint text is tappable and pre-fills quick capture.

## States
- —

## Data & state
- `FFEmptyState` widget props: color, icon, title, body, ctaLabel, onCta, hint.

## Navigation
- —

## Acceptance checklist
- [ ] Used by all 5 module lists, Archive, Trash, Search, Notification center.
- [ ] Visually matches the PNG (spacing, radius, colours, fonts, icons) in light mode; dark mode works from tokens.
- [ ] No overflow at text scale 1.3 and on 360-pt-wide devices; semantics labels on icon buttons.
- [ ] `flutter analyze` clean; widget + golden test added.
