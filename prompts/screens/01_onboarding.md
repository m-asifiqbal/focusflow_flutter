# Screen 01 — Onboarding

**Design file:** `design/01_onboarding.png`  ·  **Route:** `/onboarding`  ·  **Feature folder:** `lib/features/onboarding/`
**Read first:** `prompts/00_MASTER_PROMPT.md`, `prompts/01_DESIGN_SYSTEM.md`

> Prompt for Claude Code: *"Implement Screen 01 — Onboarding in Flutter exactly as shown in `design/01_onboarding.png`, following the spec below and the shared design-system widgets. Wire it to real Riverpod providers and the Drift repositories (no mock data except in widget tests). Add a widget test and a golden test."*

## Purpose
First-run introduction that sells the all-in-one value (Notes, Tasks, Reminders, Habits, Vault) in a calm, premium way. 3 pages in a PageView; the mockup shows page 1.

## Layout (top → bottom)
1. Status bar; top-right **Skip** text button (emerald, 15 w700).
2. Hero illustration 342×330: two concentric mint circles, a rotated (-8°) emerald gradient app tile (radius 40) with a bolt icon, and 5 floating white chips (Notes, Tasks, Reminders, Habits, Vault) each with its module solid icon tile — chips gently float (6px, 3s loop, staggered).
3. Title 30 w700 two lines: 'Everything you need,' / 'in one calm place.' (second line emerald).
4. Body 15.5 inkMuted centred, max 2–3 lines.
5. Page indicator: active pill 28×8 emerald, inactive dots 8×8 emerald-200.
6. Primary gradient button **Get Started** (56 h, radius 16).
7. Footer text: 'Already have a backup? **Restore**'.

## Interactions & behaviour
- Pages: 1) All-in-one, 2) 'Private by design' (vault + encryption illustration), 3) 'Sync everywhere' (Drive illustration). Swipe or button advances; last page button = 'Continue'.
- Skip → Sign-in (02). Restore → Sign-in with intent=restore (after Google login go straight to Backup restore picker).
- Store `onboardingSeen=true` in shared prefs; never show again.

## States
- Only one state. Respect reduce-motion (disable floating animation).

## Data & state
- `onboardingControllerProvider` (page index).
- `appPrefsProvider` for the seen flag.

## Navigation
- → `/sign-in` on Get Started/Skip.
- Splash decides: seen? → Home (or vault/app lock first if App lock on).

## Acceptance checklist
- [ ] Floating chips animate and don't clip on small screens (scale illustration with `FittedBox`).
- [ ] Flag persisted; relaunch skips onboarding.
- [ ] Visually matches the PNG (spacing, radius, colours, fonts, icons) in light mode; dark mode works from tokens.
- [ ] No overflow at text scale 1.3 and on 360-pt-wide devices; semantics labels on icon buttons.
- [ ] `flutter analyze` clean; widget + golden test added.
