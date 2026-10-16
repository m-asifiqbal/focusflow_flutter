# CLAUDE.md — FocusFlow

## What this app is
FocusFlow is an offline-first, all-in-one productivity app for Android and iOS: **Notes, Tasks,
Reminders, Habits and a Password Vault**, plus Insights, Calendar, Archive/Trash, Settings, and
optional **Google Drive backup/sync** (scope `drive.appdata` only) with local backups and
import/export. The app works fully without an account.

Design source: `design/NN_*.png` (37 screens, 390×844 pt @3x) and `prompts/` (master prompt,
design system, one prompt per screen). **Prompt wins for behaviour, mockup wins for visuals.**
The product name lives in one place: `lib/core/constants/app_info.dart`.

## Non-negotiable rules
1. **Offline first.** Everything works with no network. The only network code: Google sign-in +
   Drive (features/backup, core/sync), opt-in HIBP breach check (k-anonymity, SHA-1 prefix only),
   and opening URLs the user taps. Never add analytics, ads or other network packages.
2. **Encrypted at rest.** The SQLite file is encrypted (SQLite3MultipleCiphers, key in Keychain/
   Keystore — `core/database/encrypted_database.dart`). Vault secrets are *additionally* AES-256-GCM
   encrypted per item; plaintext secrets never touch the DB, logs, URLs or analytics. Never log
   note contents, PINs, keys or tokens.
3. **One lifecycle for every item**: Active → Archive (`archivedAt`) → Recently Deleted
   (`deletedAt`, purged after 30 days) → gone. Every destructive action shows the Undo snackbar
   (5 s); delete asks for confirmation (`confirmDelete`). Archived/deleted items never appear in
   normal lists, Home, search (unless "Include archived"), notifications or reminders.
4. **No hard-coded colours or sizes in features.** Read `context.ff` (FFColors), `context.text`
   (FFTextStyles), `AppSpacing`/`AppRadii`/`AppSizes`/`AppMotion`, `ModuleStyle`. Dark mode and the
   accent colour must work everywhere for free.
5. **Live data.** UI → providers → repositories → DAOs. Lists are `StreamProvider`s over repository
   streams, so edits anywhere update every screen. No business logic in widgets; no Drift in
   presentation code.
6. **Accessibility.** Semantics label on every icon-only button, min tap target 44×44, no overflow
   at text scale 0.85–1.3 or 360-pt width, RTL-safe (`EdgeInsetsDirectional`, `start/end`).
   Respect reduce motion (`MediaQuery.disableAnimationsOf(context)`).

## Architecture (same structure as Fresh LPG)
Clean architecture + MVVM, feature-first.
```
lib/
  main.dart · bootstrap.dart · app.dart
  core/      constants/ theme/ widgets/ (design system) router/ database/ (drift tables, DAOs)
             items/ (shared item kernel: ItemType, ItemRef, lifecycle/collections repository)
             crypto/ notifications/ sync/ settings/ storage/ platform/ utils/
  shared/    providers/ (core singletons: prefs, db, clock, device id, settings)
  features/<feature>/
    data/          datasource/ repository/ (implementations, mappers)
    domain/        entities/ repository/ (contracts) usecases/ services/ — pure Dart
    presentation/  providers/ notifiers/ state/ screens/ widgets/ + <feature>_routes.dart
```
Features: onboarding, auth, home, quick_add, library, search, notes, tasks, reminders, habits,
vault, archive, insights, calendar, notifications_center, settings, backup.

## Tech stack (do not change without asking)
- Flutter 3.44 / Dart 3.12, Material 3 with a fully custom theme.
- State: **flutter_riverpod 2.6** — `Provider`, `StreamProvider`, `FutureProvider`, `Notifier`,
  `AsyncNotifier`, `.family`, `.autoDispose`. No codegen. (No `StateNotifier` in new code.)
- Routing: go_router 18, `StatefulShellRoute.indexedStack` for the tabs. Paths in
  `core/router/app_routes.dart`; each feature registers its screens in
  `features/<f>/presentation/<f>_routes.dart`.
- DB: drift 2.35 + sqlite3 3.x (sqlite3mc build via pubspec `hooks:`), FTS5 search tables kept in
  sync by triggers. Codegen: `dart run build_runner build` (only drift uses codegen).
- Crypto: `cryptography` (AES-256-GCM, Argon2id), `flutter_secure_storage`, `local_auth`.
- Notifications: flutter_local_notifications + timezone + flutter_timezone.
- Drive: google_sign_in 7 + googleapis (Drive v3) + extension_google_sign_in_as_googleapis_auth.
- Editor: flutter_quill (Delta JSON). Charts: fl_chart. Icons: **Font Awesome Free 6.7.2, vendored**
  (the mockups' icon set): fonts in `assets/fonts/fontawesome/`, constants in
  `lib/core/theme/fa_icons.dart` (`FontAwesomeIcons.*` are plain `IconData`; regenerate with
  `tool/fa_icons/generate.dart`). Do NOT add `font_awesome_flutter` back: 10.x doesn't compile on
  Flutter 3.44 (`IconData` is final) and 11.x ships FA 7 glyphs.
- Fonts are bundled: `LexendDeca` (headings/numbers/buttons), `NunitoSans` (body).
- Tests: flutter_test, mocktail. DB tests use a temp-file `AppDatabase` keyed with
  `EncryptedDatabase.applyKey` (in-memory DBs can't be keyed — see
  test/core/database/app_database_test.dart).

## Conventions
- Imports: always `package:focusflow/...`.
- Strings: English, inline in widgets (no l10n layer yet). Sentence case, as in the mockups.
- Times: show in local time; store DateTimes via drift (unix seconds); pure days as `yyyy-MM-dd`
  (`DateUtilsX.dayKey`). Week start comes from settings (`AppSettings.weekStartsOn`).
  Exception: `tasks.due_date` is a *floating day* — write/compare it only via
  `DateUtilsX.toStoredDay` / `fromStoredDay` (UTC midnight of the date), so tasks never move a day
  when the time zone changes. Day differences: `DateUtilsX.daysBetween` (never `Duration.inDays`
  on local midnights — DST).
- Ids: uuid v4 (`newId(ref)` / `const Uuid().v4()`).
- Every write sets `updatedAt = clock.now()`, increments `syncVersion`, sets `deviceId`.
- DAOs write with insert / update / `insertOnConflictUpdate` (UPSERT), never raw REPLACE.
- Navigation: `context.push(AppRoutes.x)` for drill-ins, `context.go` for tab roots.
- Widgets: build screens from `lib/core/widgets/` (FF* design system). Feature-specific widgets
  live in `features/<f>/presentation/widgets/`.
- Repositories: read them via `lib/shared/providers/repository_providers.dart`.
- Destructive item actions (archive / delete / restore / delete forever) ALWAYS go through
  `lib/shared/item_actions/item_lifecycle_actions.dart` (confirmation + Undo snackbar), from any
  screen, sheet or multi-select bar.
- Motion: screen pushes slide in/out (theme-level `FFPageTransitionsBuilder`, both platforms,
  swipe-back); tab switches fade (`FFAnimatedBranchContainer`). For element → details, wrap the
  list card in `FFOpenOriginTracker` (core/widgets) — the page then grows out of the tapped card
  and closes back into it. Navigation code stays a plain `context.push`.
  The container takes its card/page colours from the tapped card's own theme (the always-dark vault
  must not grow a light page) and lands on the card's *live* position; container pages also swipe
  back from the leading edge (`ContainerBackGesture`, needs routes built by `withMaterialPages`/`FFPage`).
- Sheets: `showFFBottomSheet` / `FFBottomSheet` float — 12 pt from the side edges, clear of the home
  indicator, all four corners rounded. Don't add bottom safe-area padding or full-bleed backgrounds
  inside; use `FFBottomSheet.inset` for custom horizontal padding.
- Back button (Android): `AppShell` owns it at the tab roots — another tab → Home, Home → "Exit?"
  dialog. Pushed pages, sheets and dialogs close first. iOS has no back button, nothing is intercepted.
- Comments: a header block per file (what / why), doc comments on public APIs; explain *why*.
- Keep files < ~400 lines; split widgets into `widgets/`.

## Commands
```bash
flutter pub get
dart run build_runner build          # after changing drift tables/DAOs
flutter analyze
flutter test
flutter run -d "iPhone 17 Pro"
```
Xcode 27: a universal (arm64+x86_64) simulator build fails in `lipo -verify_arch`, so
`ios/Flutter/{Debug,Release}.xcconfig` pin `ARCHS[sdk=iphonesimulator*] = arm64` — keep those lines;
`flutter build ios --simulator` and `flutter run -d <simulator>` both work.
Android: `compileSdk` is pinned to ≥ 37 (permission_handler_android requires it) and
android/build.gradle.kts applies the Kotlin Gradle plugin to `screen_protector` (it skips KGP on
AGP 9, but this project keeps `android.builtInKotlin=false` for workmanager_android).
`dart format` only the files you changed (a directory-wide run reformats generated/vendored files).
Tests: `settle()` in the screen harness keeps pumping until late provider disposals (Drift closes a
dropped stream with a zero-length timer) are flushed — end screen tests with it. `captureFilmstrip`
(test/helpers/filmstrip.dart) writes a contact sheet of a transition's frames for eyeballing motion.
`test/helpers/test_container.dart` gives a fully wired ProviderContainer over a keyed temp
DB + FakeClock; `test/helpers/screen_harness.dart` pumps the real app / a screen with the bundled
fonts and `captureScreen` writes `build/screens/<name>.png` at the mockups' exact size (1170×2532)
for side-by-side comparison with `design/NN_*.png`. (Helpers must not end in `_test.dart`.)
Google Drive needs OAuth client ids at build time: fill `config/google.json` (git-ignored, from
`config/google.example.json`), run `dart run tool/google/apply_google_config.dart` (validates + writes
the iOS URL scheme), then `flutter run --dart-define-from-file=config/google.json`
(see docs/google_drive_setup.md). Without them, Drive shows "not set up in this build" and local
backups still work.
