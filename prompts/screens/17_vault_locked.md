# Screen 17 — Vault — locked

**Design file:** `design/17_vault_locked.png`  ·  **Route:** `/library/vault (locked)`  ·  **Feature folder:** `lib/features/vault/`
**Read first:** `prompts/00_MASTER_PROMPT.md`, `prompts/01_DESIGN_SYSTEM.md`

> Prompt for Claude Code: *"Implement Screen 17 — Vault — locked in Flutter exactly as shown in `design/17_vault_locked.png`, following the spec below and the shared design-system widgets. Wire it to real Riverpod providers and the Drift repositories (no mock data except in widget tests). Add a widget test and a golden test."*

## Purpose
Gate to the encrypted password vault: biometric unlock or 6-digit master PIN.

## Layout (top → bottom)
1. Vault theme: canvas #05382C, white text, glass cards (white 5% + 8% border).
2. Header: amber/emerald shield tile + 'Vault' 26 w700 + '24 items · AES-256 encrypted'; lock + add buttons.
3. Disabled search 'Search 24 accounts…' with lock icon.
4. Lock card (radius 30): face icon in ringed circle, 'Vault Locked', explanation, **Unlock with Face ID** primary button (fingerprint icon on Android), 6 PIN dots (filled emerald), number pad 3×4 (keys radius 16, white 6%), 'Use master PIN instead'.
5. Faded preview tiles (blurred names, masked dots).
6. Vault inner tab bar: Vault · Generator · Favourites · Security.

## Interactions & behaviour
- Auto-prompt biometrics on open (if enabled). PIN entry with haptics; wrong PIN shakes dots; after 5 fails exponential delay; optional wipe after 10 (setting).
- First-time: 'Create master PIN' flow (enter + confirm + enable biometrics + download recovery kit).

## States
- Locked, unlocking, error, first-time setup, lockout timer.

## Data & state
- `vaultSessionProvider` (locked/unlocked + DEK in memory + auto-lock timer).

## Navigation
- Unlock → Vault list (18). Leaving vault/background → re-lock per settings.

## Acceptance checklist
- [ ] Secrets never decrypted before unlock; screenshots blocked (screen_protector).
- [ ] Visually matches the PNG (spacing, radius, colours, fonts, icons) in light mode; dark mode works from tokens.
- [ ] No overflow at text scale 1.3 and on 360-pt-wide devices; semantics labels on icon buttons.
- [ ] `flutter analyze` clean; widget + golden test added.
