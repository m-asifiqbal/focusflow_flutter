# Screen 33 — Settings › Vault security

**Design file:** `design/33_settings_vault_security.png`  ·  **Route:** `/settings/vault-security`  ·  **Feature folder:** `lib/features/settings/`
**Read first:** `prompts/00_MASTER_PROMPT.md`, `prompts/01_DESIGN_SYSTEM.md`

> Prompt for Claude Code: *"Implement Screen 33 — Settings › Vault security in Flutter exactly as shown in `design/33_settings_vault_security.png`, following the spec below and the shared design-system widgets. Wire it to real Riverpod providers and the Drift repositories (no mock data except in widget tests). Add a widget test and a golden test."*

## Purpose
Vault protection options and recovery.

## Layout (top → bottom)
1. Dark emerald card 'Zero-knowledge encryption' explaining AES-256-GCM + Argon2id.
2. UNLOCK: Face ID / Fingerprint switch, Change master PIN, Auto-lock vault (After 5 min), Lock when app goes to background.
3. PROTECTION: Clear copied passwords 30 s, Block screenshots in Vault, Breach monitoring (k-anonymity subtitle), Wipe vault after 10 failed attempts.
4. AUTOFILL: Use FocusFlow for autofill (Android Autofill Service / iOS AutoFill extension — v1.1).
5. RECOVERY: Recovery kit (PDF) download, Export vault (encrypted).
6. Warning footnote.

## Interactions & behaviour
- Every change requires current PIN/biometric re-auth.
- Change PIN re-wraps DEK (no re-encryption of items needed).

## States
- Vault not set up → show 'Set up vault' CTA instead.

## Data & state
- `vaultSettingsProvider`, `VaultCrypto`.

## Navigation
- Back to Settings.

## Acceptance checklist
- [ ] Changing PIN keeps all items decryptable (test).
- [ ] Visually matches the PNG (spacing, radius, colours, fonts, icons) in light mode; dark mode works from tokens.
- [ ] No overflow at text scale 1.3 and on 360-pt-wide devices; semantics labels on icon buttons.
- [ ] `flutter analyze` clean; widget + golden test added.
