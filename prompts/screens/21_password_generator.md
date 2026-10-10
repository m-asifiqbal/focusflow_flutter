# Screen 21 — Password generator

**Design file:** `design/21_password_generator.png`  ·  **Route:** `/vault/generator`  ·  **Feature folder:** `lib/features/vault/`
**Read first:** `prompts/00_MASTER_PROMPT.md`, `prompts/01_DESIGN_SYSTEM.md`

> Prompt for Claude Code: *"Implement Screen 21 — Password generator in Flutter exactly as shown in `design/21_password_generator.png`, following the spec below and the shared design-system widgets. Wire it to real Riverpod providers and the Drift repositories (no mock data except in widget tests). Add a widget test and a golden test."*

## Purpose
Generate strong passwords, passphrases or PINs and save/copy them.

## Layout (top → bottom)
1. Title 'Generator' + history button.
2. Segmented: Password / Passphrase / PIN.
3. Result card (emerald gradient glass): generated value 25 mono with coloured symbols/digits, 4-segment meter, 'VERY STRONG · 98 bits entropy', buttons Regenerate / Copy.
4. OPTIONS: Length slider 8–64 (value shown), switches Uppercase, Lowercase, Numbers, Symbols, Avoid ambiguous.
5. RECENTLY GENERATED (last 10, local only, encrypted).
6. Primary 'Save to new vault item'.

## Interactions & behaviour
- Use `Random.secure()`. Passphrase: EFF wordlist, words count, separator, capitalise, add number.
- Regenerate on any option change; haptic on copy.

## States
- Password, passphrase, PIN modes.

## Data & state
- `generatorControllerProvider`.

## Navigation
- Inner vault tab; also as modal from editor (20) returning value.

## Acceptance checklist
- [ ] Entropy calculation unit-tested.
- [ ] Visually matches the PNG (spacing, radius, colours, fonts, icons) in light mode; dark mode works from tokens.
- [ ] No overflow at text scale 1.3 and on 360-pt-wide devices; semantics labels on icon buttons.
- [ ] `flutter analyze` clean; widget + golden test added.
