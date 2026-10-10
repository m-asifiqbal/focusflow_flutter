# FocusFlow — Design System Prompt

Implement these tokens in `lib/core/theme/` (`app_colors.dart`, `app_typography.dart`, `app_spacing.dart`, `app_theme.dart`) and build the reusable widgets in `lib/core/widgets/`. Never hard-code colours or sizes inside feature screens — always read from tokens / `Theme.of(context)` / a `ThemeExtension<FFColors>`.

Design language (kept from the original FocusFlow UX Pilot designs, refined): **calm mint canvas, emerald primary, soft white cards with very soft green-tinted shadows, generous rounding, bold friendly headings, iOS-style grouped settings, one colour per module, deep-emerald "secure mode" for the Vault.**

## Colours

| Token | Light | Dark | Use |
|---|---|---|---|
| `canvas` | `#F0FDFA` | `#06231C` | Screen background (all screens except Vault & Note editor) |
| `surface` | `#FFFFFF` | `rgba(255,255,255,.04)` + 1px border `rgba(255,255,255,.10)` | Cards, grouped lists |
| `primary` | `#059669` (emerald-600) | `#34D399` | Buttons, active tab, links, switches |
| `primaryGradient` | `#10B981 → #059669 → #0F766E` (top-left → bottom-right) | same | Hero cards, FAB, primary buttons |
| `primarySoft` | `#D1FAE5` | `rgba(52,211,153,.15)` | Icon tiles, tags, selected chips bg |
| `ink` | `#064E3B` (emerald-950-ish) | `#FFFFFF` | Primary text |
| `inkMuted` | `ink @ 45–55%` | `#D1FAE5 @ 50–60%` | Secondary text, meta |
| `inkFaint` | `ink @ 25–40%` | white @ 35% | Chevrons, section labels |
| `divider` | `ink @ 6%` | white @ 6% | Row separators (inset 60px from left) |
| `danger` | `#F43F5E` / soft `#FFF1F2` | `#FDA4AF` | Delete, breached |
| `warning` | `#F59E0B` / soft `#FEF3C7` | `#FCD34D` | Weak password |
| `vaultCanvas` | `#05382C` | `#05382C` | Vault screens (always dark) |
| `vaultTabBar` | `#042A21 @95%` | — | Vault inner tab bar |

**Module colours** (icon tiles, accents, left borders, chart series):

| Module | Solid | Soft | Ink | FA icon |
|---|---|---|---|---|
| Notes | `#10B981` | `#D1FAE5` | `#047857` | `note-sticky` |
| Tasks | `#3B82F6` | `#DBEAFE` | `#1D4ED8` | `check-double` |
| Reminders | `#F97316` | `#FFEDD5` | `#C2410C` | `bell` |
| Habits | `#6366F1` | `#E0E7FF` | `#4338CA` | `repeat` |
| Vault | `#F59E0B` | `#FEF3C7` | `#B45309` | `shield-halved` |
| Quick Scan | `#F43F5E` | `#FFE4E6` | `#BE123C` | `camera` |

Priority: High `#EF4444`, Medium `#F59E0B`, Low `#10B981` (shown as a 4px left bar on task rows and dot in chips).
Tag palette (bg/fg): Ideas `#D1FAE5/#047857`, Work `#DBEAFE/#1D4ED8`, Personal `#FCE7F3/#BE185D`, Finance `#FEF3C7/#B45309`, Design `#EDE9FE/#6D28D9`, Health `#D1FAE5/#047857`, High `#FEE2E2/#B91C1C`.
Note card colours: white, `#D1FAE5`, `#FEF3C7`, `#DBEAFE`, `#FCE7F3`, `#EDE9FE` (+ dark variants at 15% opacity).

## Typography

- **Headings / numbers / buttons**: Lexend Deca (600/700). **Body**: Nunito Sans (400/600/700/800).
- Large title 30/1.15 w700 (-0.5 tracking) · Screen nav title 16 w600 · Section title 19 w600 · Card title 15–15.5 w600 · Body 15–15.5 w400 lh 1.6 · Meta 12–12.5 w600 · Section label 11.5 w800 UPPERCASE tracking 0.12em at inkFaint · Tag 10 w800 UPPERCASE · Big stat 22–26 w700 · Hero ring number 44 w700.

## Spacing, radius, elevation

- 4-pt grid. Screen horizontal padding **24** (lists/cards) or **20** (grouped settings). Gap between cards 12. Section top padding 24–28.
- Radius: chips/pill 999 · buttons 16 · inputs/search 16 · cards **22** · hero cards 26–28 · bottom sheets 34 (top) · icon tiles 9–14 · dialogs 30.
- Shadow (cards): `0 6 24 -12 rgba(6,78,59,.18)`. Hero/FAB: `0 20 40 -18 rgba(5,150,105,.75)`. No hard drop shadows anywhere.
- Heights: primary button 56 · secondary 50–52 · search 52 · list row min 60 · chip 36 · tab bar ~84 incl. safe area · FAB 60 with 4px ring in canvas colour, raised 28px above the bar.

## Components to build (`lib/core/widgets/`)

`FFScaffold` (canvas + safe area + optional bottom bar) · `FFLargeHeader(title, subtitle, actions)` · `FFNavHeader(left, title, subtitle, right)` (3-column, centred title) · `FFRoundIconButton` (44, white, soft shadow; dark & accent variants) · `FFSearchField` · `FFChipBar` (horizontally scrollable, active = filled emerald) · `FFCard` · `FFGroupedList` + `FFListRow(leadingTile, title, subtitle, value, trailing: chevron|switch|widget)` · `FFIconTile(solid|soft)` · `FFTag` · `FFSwitch` (iOS-style 51×31 emerald) · `FFCheckCircle(color)` · `FFProgressRing(percent, size, stroke, color, child)` · `FFPrimaryButton` (gradient) / `FFSecondaryButton` / `FFDangerButton` · `FFBottomSheet` (handle, 34 radius, backdrop blur 3 + emerald-950 @45%) · `FFDialog` · `FFSnackbar` (dark emerald, action in emerald-400 e.g. UNDO) · `FFEmptyState(illustration, title, body, cta)` · `FFSkeleton` · `FFBottomNav` (Home, Library, FAB, Insights, Settings; active = emerald + dot) · `FFSwipeActions` · `FFSectionLabel` · `FFStatTile` · `FFHeatmap` · `FFSegmented` (pill segmented control).

## Motion

Durations 180–260 ms, `Curves.easeOutCubic`. Sheet slide-up + backdrop fade. Checkbox completion: scale bounce + haptic light. Habit ring fills animate. Card press: scale 0.98. Respect "Reduce motion" setting.

## Dark mode

Derive from tokens (see `design/37_home_dark.png`): canvas `#06231C`, surfaces white @4% with 10% border, text white, muted emerald-100 @ 50%, accents keep module colours, primary `#34D399`.
