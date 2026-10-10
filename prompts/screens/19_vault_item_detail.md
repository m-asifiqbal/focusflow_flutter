# Screen 19 — Vault — item detail

**Design file:** `design/19_vault_item_detail.png`  ·  **Route:** `/vault/:id`  ·  **Feature folder:** `lib/features/vault/`
**Read first:** `prompts/00_MASTER_PROMPT.md`, `prompts/01_DESIGN_SYSTEM.md`

> Prompt for Claude Code: *"Implement Screen 19 — Vault — item detail in Flutter exactly as shown in `design/19_vault_item_detail.png`, following the spec below and the shared design-system widgets. Wire it to real Riverpod providers and the Drift repositories (no mock data except in widget tests). Add a widget test and a golden test."*

## Purpose
Show one credential with copy actions, TOTP code, security health and history.

## Layout (top → bottom)
1. Header: '‹ Vault', heart, Edit pill (emerald-400 bg).
2. Brand tile 76, title 25 w700, 'Personal · Updated 3 days ago'.
3. Fields card: Username (copy), Password (colour-coded characters: symbols amber, digits sky; reveal + copy), One-time code (2FA) big digits emerald with countdown ring, Website (link, copy, open).
4. Security health card: score 98%, gradient bar, checklist (No breaches, Unique, 16+ characters, 2FA enabled).
5. Notes card + 'Password history · 4 versions' row.
6. Archive & Delete buttons.
7. Toast at bottom: 'Password copied · clears in 30s'.

## Interactions & behaviour
- Reveal requires biometric re-auth if 'Re-auth to reveal' setting is on.
- TOTP via `otp` package; refresh every 30 s.
- Open website launches browser; long-press password → large-type view.

## States
- Login, Card (number masked, expiry, CVV reveal), Wi-Fi (SSID, password, QR to share), Secure note.

## Data & state
- `vaultItemProvider(id)` (decrypt on demand), `passwordHealthProvider`.

## Navigation
- From vault list; Edit → 20.

## Acceptance checklist
- [ ] Clipboard cleared after timeout even if app backgrounded (schedule with workmanager/one-off).
- [ ] Visually matches the PNG (spacing, radius, colours, fonts, icons) in light mode; dark mode works from tokens.
- [ ] No overflow at text scale 1.3 and on 360-pt-wide devices; semantics labels on icon buttons.
- [ ] `flutter analyze` clean; widget + golden test added.
