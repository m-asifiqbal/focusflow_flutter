# Screen 06 — Global Search

**Design file:** `design/06_global_search.png`  ·  **Route:** `/search`  ·  **Feature folder:** `lib/features/search/`
**Read first:** `prompts/00_MASTER_PROMPT.md`, `prompts/01_DESIGN_SYSTEM.md`

> Prompt for Claude Code: *"Implement Screen 06 — Global Search in Flutter exactly as shown in `design/06_global_search.png`, following the spec below and the shared design-system widgets. Wire it to real Riverpod providers and the Drift repositories (no mock data except in widget tests). Add a widget test and a golden test."*

## Purpose
Search across all modules (FTS5) with highlighting, type filters and recent searches.

## Layout (top → bottom)
1. Search bar focused (ring 2px emerald-400) with clear button + 'Cancel'.
2. Type chips with counts: All 14, Notes 5, Tasks 4, Reminders 2, Habits 1 (+Vault).
3. Section 'TOP RESULTS' + 'Sort: Relevance' → grouped result rows: soft module icon tile, title with matched term highlighted (emerald-200 background), meta line (module · folder · time).
4. Section 'RECENT SEARCHES' + 'Clear' → history pills.
5. Section 'SEARCH FILTERS' → Date range, Tag, Priority, Include archived.

## Interactions & behaviour
- Debounce 200 ms; FTS5 prefix match; rank = bm25 + recency boost + pinned boost.
- Vault results show title only with 'unlock to view'; tapping requires unlock.
- Tap result → open item. Recent searches stored (max 10).

## States
- Initial (recent + suggestions), typing (results), no results ('No matches for “x”' + suggest removing filters), error.

## Data & state
- `searchQueryProvider`, `searchResultsProvider(query, filters)` → `SearchRepository` using FTS tables.
- `recentSearchesProvider`.

## Navigation
- Pushed full-screen from Home/Library/any list search icon.

## Acceptance checklist
- [ ] Search over 5k items returns < 100 ms on mid-range device.
- [ ] Archived items excluded unless filter on.
- [ ] Visually matches the PNG (spacing, radius, colours, fonts, icons) in light mode; dark mode works from tokens.
- [ ] No overflow at text scale 1.3 and on 360-pt-wide devices; semantics labels on icon buttons.
- [ ] `flutter analyze` clean; widget + golden test added.
