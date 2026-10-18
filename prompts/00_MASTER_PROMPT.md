# FocusFlow — Master Build Prompt (paste this first into Claude Code)

> Working name: **FocusFlow** (rename later — see name ideas in README). Replace the name in one place: `lib/core/constants/app_info.dart`.

You are building **FocusFlow**, a production-quality, offline-first, all-in-one productivity app for **Android and iOS** using **Flutter**. It combines five spaces — **Notes, Tasks, Reminders, Habits and a Password Vault** — plus Insights, a Calendar, Archive/Trash, a comprehensive Settings area, and **Google Drive backup/sync with Google Sign-In** and local backups.

The visual design is final and provided as PNG mockups in `/design` (one per screen, 390×844 pt @3x). Every screen also has its own prompt file in `/prompts/screens`. **Match the mockups pixel-close** (spacing, radii, colours, typography, icon choice). When a mockup and a prompt disagree, the prompt wins for behaviour, the mockup wins for visuals.

---

## 1. Tech stack (use exactly these unless a package is abandoned)

| Concern | Package |
|---|---|
| State management | `flutter_riverpod` + `riverpod_annotation` (code-gen) |
| Routing | `go_router` (StatefulShellRoute for the 4 tabs) |
| Local database | `drift` + `sqlite3_flutter_libs` (single DB, typed DAOs, migrations) |
| Vault encryption | `cryptography` (AES-256-GCM, Argon2id KDF), `flutter_secure_storage` for the wrapped data key |
| Biometrics | `local_auth` |
| Notifications | `flutter_local_notifications` + `timezone` + `flutter_timezone` (exact alarms on Android 12+, request permission) |
| Google auth & Drive | `google_sign_in` + `googleapis` (Drive v3) + `extension_google_sign_in_as_googleapis_auth`; scope **`drive.appdata`** only (app-private folder) |
| Files / share | `path_provider`, `file_picker`, `share_plus`, `archive` (zip), `pdf` |
| Background backup | `workmanager` (Android) / BGTaskScheduler via `workmanager` (iOS) |
| Rich text notes | `flutter_quill` (Delta JSON stored in DB) |
| OCR “Quick Scan” | `google_mlkit_text_recognition` + `image_picker` |
| Charts | `fl_chart` |
| Fonts / icons | `google_fonts` (Lexend Deca, Nunito Sans), `font_awesome_flutter` (icons in mockups are Font Awesome 6) |
| Misc | `uuid`, `intl`, `freezed` + `json_serializable`, `collection`, `flutter_animate`, `haptic_feedback`, `screen_protector` (block screenshots in vault), `otp` (TOTP codes) |
| Testing | `flutter_test`, `mocktail`, `integration_test`, golden tests with `alchemist` |

Minimum: Flutter 3.24+, Dart 3.5+, Android minSdk 24, iOS 14.

## 2. Architecture

Feature-first clean architecture:

```
lib/
  main.dart / app.dart
  core/            theme/ (tokens, ThemeData light+dark), widgets/ (design-system components),
                   router/, db/ (drift database, tables, migrations), crypto/, notifications/,
                   sync/ (drive + local backup engine), utils/, constants/
  features/
    onboarding/ auth/ home/ quick_add/ library/ search/
    notes/ tasks/ reminders/ habits/ vault/
    archive/ insights/ calendar/ notifications_center/ settings/ backup/
      each: data/ (dao, repository impl) domain/ (entities, repository interface) presentation/ (screens, widgets, providers)
```

Rules: UI never talks to Drift directly → providers → repositories → DAOs. All repositories return `Stream`s for lists so every screen is live. No business logic in widgets.

## 3. Shared data model (every module)

Every item table (`notes`, `tasks`, `reminders`, `habits`, `vault_items`) includes these **common columns**:

```
id TEXT (uuid v4, PK) · createdAt · updatedAt · archivedAt (nullable) · deletedAt (nullable = soft delete)
isPinned BOOL · isFavorite BOOL · colorHex TEXT? · folderId TEXT? · sortOrder REAL
syncVersion INT · lastSyncedAt? · deviceId
```
Plus a `tags` table and `item_tags` join table (itemId, itemType, tagId), a `folders` table, and an `attachments` table.

Lifecycle used by ALL lists (this is a core requirement):
- **Active** → `archivedAt == null && deletedAt == null`
- **Archive** (hidden from lists/search/reminders/notifications, restorable) → `archivedAt != null`
- **Recently Deleted** (soft delete, auto-purge after 30 days by a daily job) → `deletedAt != null`
- **Permanent delete** only from Recently Deleted (and purges Drive copy on next sync).
- Every destructive action shows an **Undo snackbar** (5 s) and delete asks for confirmation (screen 28).

Module-specific fields:
- **Note**: title, contentDelta (JSON), plainText (for search/FTS), checklist, coverImage?, isLocked (requires vault PIN), wordCount, reminderId?
- **Task**: title, notes, dueDate?, dueTime?, priority (none/low/medium/high), repeatRule (RRULE string), remindOffsetMinutes?, listId, linkedNoteId?, completedAt?, `subtasks` table (id, taskId, title, done, sortOrder)
- **Reminder**: title, note, triggerAt, repeatRule?, alertStyle (notification/alarm), sound, snoozeMinutes, locationTrigger? (lat,lng,radius,onEnter/onExit), linkedItemId/type?, isEnabled, lastFiredAt, completedAt?
- **Habit**: name, icon, colorHex, category, type (build/quit), targetCount, unit, frequency (daily / weekdays mask / x-per-week), reminderTimes[], startDate; `habit_logs` table (habitId, date, count, skipped, note)
- **VaultItem**: type (login/card/wifi/secureNote), title, iconKey, **encryptedPayload BLOB** (username, password, url, totpSecret, notes, customFields JSON — all inside the ciphertext), passwordStrength (cached), passwordUpdatedAt, `vault_history` table (old encrypted passwords)

Enable **SQLite FTS5** over notes/tasks/reminders/habits text for Global Search. Vault items are searchable by title only (plaintext title), never by secrets.

## 4. Security model (Vault)

- On first vault use: user sets a 6-digit master PIN (+ optional biometrics). Derive KEK with **Argon2id** (salt stored), generate random 256-bit DEK, store DEK wrapped by KEK in `flutter_secure_storage`. Biometric unlock unwraps a second copy of the DEK protected by Keychain/Keystore biometric access control.
- Encrypt each vault payload with AES-256-GCM (unique nonce). Decrypted secrets live only in memory while unlocked; auto-lock timer (default 5 min) and lock on app background.
- Clipboard auto-clear (default 30 s). Block screenshots/app-switcher preview inside vault screens.
- Breach check: Have I Been Pwned range API (k-anonymity, SHA-1 prefix only) — opt-in.
- Backups: vault ciphertext is exported as-is; a backup is useless without the PIN. Provide a printable Recovery Kit PDF.

## 5. Sync & Backup (Google Drive + local)

- Google Sign-In (optional — app fully works offline). Request only `https://www.googleapis.com/auth/drive.appdata`.
- Backup format **`.ffbackup`** = zip { `manifest.json` (schemaVersion, appVersion, createdAt, deviceId, counts, checksum), `db.json` (all tables), `settings.json` (the app's settings and view preferences — optional, `hasSettings` in the manifest), `attachments/` } and optionally encrypted with the master-PIN key. Restoring brings the settings back too (Replace: the backup's; Merge: only what is still default here; never the account / device-bound fields, never turns App lock off).
- Sync strategy v1: snapshot backup + **last-write-wins by `updatedAt` per item** on restore/merge, keeping `syncVersion`. Show conflicts count in Backup & Sync screen. Keep last N backups (default 10) in appDataFolder.
- Auto backup via `workmanager` (daily at chosen time, Wi-Fi only option). Manual “Sync now” / “Restore”.
- Local backup to app documents dir + “Save to device” via `file_picker` (SAF on Android). Import: `.ffbackup`, JSON, CSV (tasks/notes), Google Keep (Takeout), Bitwarden CSV (vault), Loop Habit CSV.

## 6. Navigation map

Bottom tab bar (4 tabs + centre FAB): **Home · Library · [+] · Insights · Settings**. The centre FAB always opens the **Quick Add sheet** (screen 04).

```
Splash → Onboarding(01) → Sign in(02) → Home(03)
Home → Search(06), Notification center(27), Calendar(26), any item
Library(05) → Notes(07) / Tasks(10) / Reminders(12) / Habits(14) / Vault(17→18) / Archive(23) / Recently Deleted(24) / Pinned / Favourites / Tags
Notes(07) → Note editor(08) ; long-press any card/row → Item actions sheet(09)
Tasks(10) → Task editor(11) ; Reminders(12) → Reminder editor(13)
Habits(14) → Habit detail(16) → Habit editor(15)
Vault: Locked(17) → List(18) → Detail(19) → Editor(20); inner tab bar: Vault · Generator(21) · Favourites · Security(22)
Settings(30) → Notifications(31) / Appearance(32) / Vault security(33) / Backup & Sync(34) / Import & Export(35) / Account(36)
```
Deep links: `focusflow://item/{type}/{id}` (used by notification taps).

## 7. Universal list behaviours (apply to Notes, Tasks, Reminders, Habits, Vault)

1. Large title header + subtitle with live counts; search field; horizontal filter chips; sort control.
2. Pull-to-refresh triggers sync if signed in.
3. **Swipe** row/card: left → Archive (slate) + Delete (rose); right → Pin / Complete (module-dependent). Configurable in Settings › Gestures.
4. **Long-press** → Item actions sheet (09): Pin, Favourite, Duplicate, Colour, Tags/Folder, Set reminder, Share/Export, Lock (notes), Archive, Delete.
5. **Multi-select** mode ("Select" button) with bottom action bar: Archive, Delete, Move, Tag, Pin.
6. Empty state (screen 29 pattern), loading skeletons (shimmer cards shaped like real rows), error banner with retry.
7. Drag-to-reorder where sort = Manual.
8. Every list is a `StreamProvider` — changes from editors/sync appear instantly.

## 8. Quality bar / Definition of Done (each screen)

- Matches mockup in light mode; dark mode derived from tokens (see screen 37) — no hard-coded colours in widgets.
- Works at text scale 0.85–1.3 without overflow; supports RTL layout safely.
- Semantics labels on every icon button; min tap target 44×44.
- No jank: lists use `ListView.builder`/`SliverList`, images cached.
- Unit tests for repositories & crypto, widget test per screen, golden test vs mockup for key screens.
- `flutter analyze` clean with `very_good_analysis` lints.

## 9. Build order (one Claude Code session per phase)

1. **Foundation** — project, packages, theme tokens & design-system widgets (`01_DESIGN_SYSTEM.md`), router with shell & placeholder screens, Drift DB with all tables + migrations, repository layer.
2. **Notes** (07, 08, 09) + Library (05) + Archive/Trash (23, 24, 28) — establishes the shared list/lifecycle pattern.
3. **Tasks** (10, 11) + **Reminders** (12, 13) + notification engine.
4. **Habits** (14, 15, 16).
5. **Vault** (17–22) + crypto + Vault security settings (33).
6. **Home** (03), Quick Add (04), Global search (06), Calendar (26), Notification center (27), Insights (25).
7. **Settings** (30–32, 36), Onboarding & Sign-in (01, 02).
8. **Backup & Sync** (34, 35) — Google Drive + local + import/export.
9. Dark mode pass (37), empty/loading/error states (29), accessibility, tests, release config.

For each phase say: *"Read `/prompts/00_MASTER_PROMPT.md`, `/prompts/01_DESIGN_SYSTEM.md` and the screen prompts NN–NN, look at the matching PNGs in `/design`, then implement them."*
