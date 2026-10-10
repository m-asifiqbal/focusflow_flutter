# Screen 18 — Vault — item list

**Design file:** `design/18_vault_list.png`  ·  **Route:** `/vault`  ·  **Feature folder:** `lib/features/vault/`
**Read first:** `prompts/00_MASTER_PROMPT.md`, `prompts/01_DESIGN_SYSTEM.md`

> Prompt for Claude Code: *"Implement Screen 18 — Vault — item list in Flutter exactly as shown in `design/18_vault_list.png`, following the spec below and the shared design-system widgets. Wire it to real Riverpod providers and the Drift repositories (no mock data except in widget tests). Add a widget test and a golden test."*

## Purpose
Browse all vault items by category with strength badges, quick copy and breach alert.

## Layout (top → bottom)
1. Header subtitle 'Unlocked · auto-locks in 4:59' (live countdown).
2. Search field (dark).
3. Category cards horizontal: Logins 16, Cards 3, Wi-Fi 2, Secure notes 3.
4. Breach banner (rose 10%): '1 password found in a data breach' + 'Fix now'.
5. Chips: All 24, Favourites, Work, Personal, Finance.
6. Section 'A – Z' + Sort.
7. Grouped dark list rows: brand icon tile 44 (fetch favicon or letter avatar on brand colour), title + heart if favourite, username (muted), status badge (STRONG emerald / WEAK amber / REUSED orange / BREACHED rose), copy button.

## Interactions & behaviour
- Copy button → copies password, toast 'Password copied · clears in 30s', haptic. Long-press → copy username / open URL / edit / archive / delete.
- Tap → detail (19). Swipe → Favourite / Archive / Delete. Alphabet scrubber on right for long lists.

## States
- Empty vault: 'Add your first password' + Import from Bitwarden/1Password CSV.

## Data & state
- `vaultItemsProvider(filter)` (decrypts only title/username for list, rest on demand).

## Navigation
- Inner vault tabs; + → editor (20).

## Acceptance checklist
- [ ] Auto-lock timer resets on interaction.
- [ ] Visually matches the PNG (spacing, radius, colours, fonts, icons) in light mode; dark mode works from tokens.
- [ ] No overflow at text scale 1.3 and on 360-pt-wide devices; semantics labels on icon buttons.
- [ ] `flutter analyze` clean; widget + golden test added.
