# Localization

FocusFlow speaks English plus six bundled languages: Bangla (bn), Arabic (ar, right to left), Chinese
Simplified (zh), Hindi (hi), German (de) and Spanish (es). English is always on; the user adds the others in
**Settings › General › Language** (stored in `AppSettings.enabledLanguages`, the one in use in `languageCode`).
Packs are text files inside the app (`assets/l10n/<code>.json`), so adding a language needs no network and works
offline; only the selected pack is read into memory.

## Writing text

```dart
Text(tr('Archive'))
Text(tr('{n} tasks overdue', {'n': count}))
Text(tr('{count, plural, one {# note} other {# notes}}', {'count': n}))
```

* The English text is the key and the fallback. The key must be one plain string literal.
* One key per sentence (word order differs): no concatenating fragments, no `n == 1 ? 'x' : 'xs'`.
* Never call `tr` in a `const`, a `static`/field/top-level initialiser or an enum constructor argument: it would be
  evaluated once and stay in the old language. Use a getter / `switch` / function. Label tables that must stay const
  keep the English literal, are listed in `lib/core/l10n/static_keys.dart` and shown as `tr(entry.label)`.
* Text drawn into PDFs with Latin-only fonts uses `trPrint` (English for Bangla/Arabic/Chinese/Hindi).
* Persisted data (habit categories/units, device names, file formats) stays English in the database and is
  translated only where displayed (see `HabitWords.shown`).
* Logic must never compare against displayed text. Dates come from `DateFormats` (the locale is global); numbers use
  Western digits in every language.

## Tools (`dart run --packages=.dart_tool/package_config.json tool/l10n/<tool>.dart`)

| Tool | What |
|---|---|
| `extract.dart` | Rewrites `assets/l10n/en.json` (the catalogue: every `tr`/`trPrint` key + `static_keys.dart`). `--check` verifies it. |
| `audit.dart [prefix]` | Lists user-facing-looking literals that are not translated. Literals that are not text (ids, SQL…) go in `tool/l10n/ignore/*.txt` (`path<TAB>text`). |
| `wrap_strings.dart` | The one-off codemod that did the first pass; idempotent. |

Workflow for a new string: write it with `tr`, run `extract.dart`, add the key to the six packs, run
`flutter test --no-pub test/core/l10n`. `catalog_test` fails when a key is missing from a pack, a placeholder
differs, or a plural block uses categories the language does not have (Arabic: zero one two few many other;
Chinese: other; the rest: one other).

## Switching at runtime

`LanguageController.select` loads the pack, activates it (`L10n.activate`, `Intl.defaultLocale`), saves the
setting and rebuilds the whole tree once (`rebuildEverything`, a hot-reload style reassemble: state is kept).
Providers that cache worded text watch `languageCode` so they recompute. Notification fingerprints include the
language (not for English), so scheduled reminders are re-sent in the new language.

## Known limits

* The translations were produced by Claude, not by native speakers — have each reviewed before a public release.
* Android launcher shortcut titles and the app name are static (English).
* Printed documents (recovery kit, notes PDF) stay English for Bangla/Arabic/Chinese/Hindi until a font with those
  glyphs is bundled.
* Search keywords and quick-capture parsing ("tomorrow 5pm") understand English only.
