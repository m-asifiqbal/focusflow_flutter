# Screen 22 — Vault security dashboard

**Design file:** `design/22_security_dashboard.png`  ·  **Route:** `/vault/security`  ·  **Feature folder:** `lib/features/vault/`
**Read first:** `prompts/00_MASTER_PROMPT.md`, `prompts/01_DESIGN_SYSTEM.md`

> Prompt for Claude Code: *"Implement Screen 22 — Vault security dashboard in Flutter exactly as shown in `design/22_security_dashboard.png`, following the spec below and the shared design-system widgets. Wire it to real Riverpod providers and the Drift repositories (no mock data except in widget tests). Add a widget test and a golden test."*

## Purpose
Password health overview with actionable issues.

## Layout (top → bottom)
1. Title 'Security' + 'Last scan: today, 8:02 AM'.
2. Health ring 168 (score 85, 'HEALTH SCORE') + '+6 since last week' pill.
3. 4 tiles: Breached 1 (rose), Reused 3 (orange), Weak 2 (amber), Strong 18 (emerald).
4. NEEDS ATTENTION · 4 + 'Fix all': rows with tinted icon tile, category label, item name, reason, action pill (Change / Fix / Update).
5. PROTECTION: Breach monitoring switch, 2FA coverage 14 / 24.

## Interactions & behaviour
- Score = weighted (strength 40%, uniqueness 25%, breach 25%, age 10%).
- Change → opens website + editor side by side flow; Fix all walks items one by one.
- Pull to rescan (HIBP range API, opt-in).

## States
- All good state: big check + 'Your vault is in great shape'.

## Data & state
- `securityReportProvider` computed in isolate.

## Navigation
- Inner vault tab.

## Acceptance checklist
- [ ] Only SHA-1 prefixes (5 chars) ever leave the device.
- [ ] Visually matches the PNG (spacing, radius, colours, fonts, icons) in light mode; dark mode works from tokens.
- [ ] No overflow at text scale 1.3 and on 360-pt-wide devices; semantics labels on icon buttons.
- [ ] `flutter analyze` clean; widget + golden test added.
