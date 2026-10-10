# Screen 20 — Vault — add / edit item

**Design file:** `design/20_vault_item_editor.png`  ·  **Route:** `/vault/:id/edit | /vault/new`  ·  **Feature folder:** `lib/features/vault/`
**Read first:** `prompts/00_MASTER_PROMPT.md`, `prompts/01_DESIGN_SYSTEM.md`

> Prompt for Claude Code: *"Implement Screen 20 — Vault — add / edit item in Flutter exactly as shown in `design/20_vault_item_editor.png`, following the spec below and the shared design-system widgets. Wire it to real Riverpod providers and the Drift repositories (no mock data except in widget tests). Add a widget test and a golden test."*

## Purpose
Create/edit secure items of type Login, Card, Wi-Fi or Secure note.

## Layout (top → bottom)
1. Header Cancel · 'Edit Item' · Save.
2. Type chips: Login (selected), Card, Wi-Fi, Secure note.
3. Title card with icon (Change icon).
4. CREDENTIALS: Username/email, Password (mono font, eye, **Generate** pill) + 4-segment strength meter + text, Website, 2FA secret (TOTP) with QR scan icon.
5. ORGANISE: Folder, Tags, Add to favourites switch, Password expiry reminder (90 days).
6. NOTES multiline card. CUSTOM FIELDS dashed '+ Add field (PIN, security question…)'.

## Interactions & behaviour
- Generate → opens Generator (21) as sheet, returns value.
- Strength via zxcvbn-like estimator (`zxcvbn` Dart port).
- Scan QR (mobile_scanner) to import otpauth:// URI.
- On save: encrypt payload, push old password into history, update strength cache.

## States
- Per-type field sets; validation (title required).

## Data & state
- `vaultEditorController(id)`.

## Navigation
- From vault list +, Quick Add (after unlock), detail Edit.

## Acceptance checklist
- [ ] Plaintext never written to DB/logs.
- [ ] Visually matches the PNG (spacing, radius, colours, fonts, icons) in light mode; dark mode works from tokens.
- [ ] No overflow at text scale 1.3 and on 360-pt-wide devices; semantics labels on icon buttons.
- [ ] `flutter analyze` clean; widget + golden test added.
