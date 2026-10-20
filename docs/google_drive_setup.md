# Google Drive backup & sync — setup

FocusFlow works fully offline. Google Drive backup/sync is optional. To
turn it on, a build needs OAuth client ids from a Google Cloud project. A
build without them shows "Google Drive is not set up in this build", but
local backups, Save to device and import/export still work.

## What the app accesses

- **Scope:** `https://www.googleapis.com/auth/drive.appdata`, and nothing
  else. Sign-in itself adds only the basic `email`/`profile`.
- **Where:** the hidden *appDataFolder* of the user's Drive. Users can't see
  it in drive.google.com, and other apps can't read it. It holds:
  - `focusflow-<yyyyMMdd-HHmmss>-<device>.ffbackup`: one file per backup.
    Small metadata (device, time, item count, encrypted?) is stored in Drive
    `appProperties`, so the history list never downloads whole backups.
  - `focusflow-devices.json`: the linked devices list and the shared KDF
    salt for "Encrypt backups". Every device that uses the same backup PIN
    derives the same key, so it can merge the other devices' encrypted
    backups.
- **Tokens:** the app never stores them. google_sign_in keeps its own
  credentials and gives out short-lived access tokens on demand. The
  keychain holds only the profile (provider, email, name, photo URL) under
  `account.profile`.

## 1. Google Cloud project

1. Go to <https://console.cloud.google.com/> and create (or pick) a project.
2. **APIs & Services → Library → Google Drive API → Enable.**
3. **OAuth consent screen:** choose External. Fill in the app name
   (FocusFlow), a support email and links to the privacy policy and terms.
   Under **Scopes**, add `.../auth/drive.appdata`. While the app is in
   *Testing*, add your testers' Google accounts. `drive.appdata` is a
   non-sensitive scope, so publishing needs no security assessment.

## 2. OAuth clients

Create these under **APIs & Services → Credentials → Create credentials →
OAuth client ID**:

| Client type | Settings | Used as |
|---|---|---|
| **Web application** | none | `GOOGLE_SERVER_CLIENT_ID` (Android requires it, for Credential Manager) |
| **Android**, one per signing key | package `com.iqballab.focusflow` + **one** SHA-1 each: debug, upload, Play app signing (see docs/release.md) | picked up automatically by package + SHA-1 |
| **iOS** | bundle id `com.iqballab.focusflow` | `GOOGLE_IOS_CLIENT_ID` + its reversed id |

Get the debug SHA-1 with
`keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android`.
Get the Play signing SHA-1 from Play Console → App integrity.

## 3. Put the ids in one file

```bash
cp config/google.example.json config/google.json     # git-ignored
# paste the Web client id → GOOGLE_SERVER_CLIENT_ID
# paste the iOS client id → GOOGLE_IOS_CLIENT_ID
dart run tool/google/apply_google_config.dart
```

The script validates both ids and writes `ios/Flutter/GoogleSignIn.xcconfig`
(git-ignored) with `GOOGLE_REVERSED_CLIENT_ID`: the iOS id reversed, which
Info.plist registers as the URL scheme Google sign-in returns to. Re-run it
whenever the ids change. Android needs no file: its OAuth client is matched
by package name + SHA-1.

## 4. Run / build with the ids

```bash
flutter run --dart-define-from-file=config/google.json
flutter build appbundle --dart-define-from-file=config/google.json
flutter build ipa --dart-define-from-file=config/google.json
```

IDE: pick the **"main.dart (Google Drive)"** run configuration (Android
Studio) or **"FocusFlow (Google Drive)"** (VS Code, `.vscode/launch.json`).
The plain configurations keep working without `config/google.json`.

Availability (`GoogleConfig.isConfigured`): Android needs
`GOOGLE_SERVER_CLIENT_ID`, and iOS needs `GOOGLE_IOS_CLIENT_ID`. Without
them the app builds and runs; Drive says "not set up in this build".

### Checklist to hand over

- [ ] Google Drive API enabled in the Cloud project
- [ ] OAuth consent screen: External, scope `.../auth/drive.appdata`, test users added
- [ ] Android OAuth clients (package `com.iqballab.focusflow`), one per key: the debug
      key, the upload key and — after the first Play upload — the Play app-signing key
- [ ] Web OAuth client id → `GOOGLE_SERVER_CLIENT_ID`
- [ ] iOS OAuth client (bundle id `com.iqballab.focusflow`) id → `GOOGLE_IOS_CLIENT_ID`

## How it behaves

- **Sign in** (Welcome/Sign in, Settings, Backup & Sync): `GoogleSignIn.instance.initialize`
  → `authenticate` → `authorizationClient.authorizeScopes([drive.appdata])`.
  If the user declines Drive consent, the app doesn't sign in.
- **Sign in with Apple** (iOS only) gives a profile only, with no Drive.
- **Sync now** works in these steps:
  1. Build a `.ffbackup`. It's encrypted with the stored backup key when
     "Encrypt backups" is on. It carries the app's settings too
     (`settings.json`) and the profile picture (`profile-photo.jpg`), so a
     manual **Restore** on a new phone brings back the configuration and
     the picture as well as the data. Replace restores the backup's
     picture. Merge restores it only when the phone has none. The
     automatic merge in step 5 never applies another device's settings or
     picture.
  2. Upload it.
  3. Keep this device's last *N* backups and delete the older ones.
  4. Update the devices manifest.
  5. Merge each other device's newest backup when it is newer than the one
     merged last time (last write wins per item).
  
  Errors show as these messages: *You're offline*, *Your Google sign-in
  expired. Sign in again*, *Your Google Drive is full*. If Drive rejects a
  token (401), the app drops it and retries once with a token it gets
  without showing the user anything.
- **Automatic backup** (workmanager):
  - Android: a periodic 24 h job starts at the chosen time. It requires an
    unmetered network when "Wi-Fi only" is on.
  - iOS: a BGProcessingTask, scheduled again on every launch.
  - Either way, the job checks again that the backup is due and that the
    network allows it, and it runs without user interaction.
  - A maintenance job runs about every 12 h. It purges Recently Deleted and
    runs the automatic local backup.
  - An overdue backup also runs when the app opens.
  - The background isolate opens the encrypted database with the key from
    the keychain. If there is no key, it does nothing and never creates
    one.
- **Sync when app opens** (on by default, Backup & Sync › Automatic
  backup): a cold start, or coming back after at least a minute away,
  runs a sync without user interaction. It needs a Google Drive account, the
  network that "Wi-Fi only" allows, and no sync in the last 2 minutes. If
  the device is offline, it skips without showing an error. Every backup
  stores a SHA-256 of its data, settings and profile picture in its
  appProperties (`contentHash`). When this device's newest backup already
  has the current state, the sync on open uploads and prunes nothing. It only merges other devices' newer backups,
  so opening the app often doesn't push older restore points out of
  "Keep last N". *Sync now* and the scheduled backup always upload.
- **Sign out** forgets the profile, and local data stays. **Delete account
  & Drive data** deletes every file in appDataFolder and revokes the grant
  (`disconnect`).

## Go-live checklist

The code is finished; what is missing is configuration that only the
account owner can create. In order:

1. **`config/google.json` does not exist yet**, so every build so far says
   "not set up in this build". Create the Google Cloud project, the Drive API,
   the consent screen and the three OAuth clients (sections 1–2 above), then
   `cp config/google.example.json config/google.json` and paste the Web and
   iOS client ids.
2. **Register the SHA-1 of every key that signs a build**: one *Android*
   OAuth client per key (the form takes a single SHA-1), all with package
   `com.iqballab.focusflow`. Google matches the app by package + SHA-1; a
   mismatch fails sign-in with a generic error (code 10 / "developer error"),
   only on that build:
   * debug builds — Windows:
     `keytool -list -v -alias androiddebugkey -keystore %USERPROFILE%\.android\debug.keystore -storepass android -keypass android`
     (`keytool` is in `<Android Studio>\jbr\bin`), or `cd android` then
     `gradlew signingReport`;
   * release builds — signed with the **upload key** from `android/key.properties`
     (docs/release.md); without that file they fall back to the debug key (see
     `android/app/build.gradle.kts`). `gradlew signingReport` shows which;
   * Play Store — add the *upload* key SHA-1 and, after the first upload, the
     *app signing* key SHA-1 from Play Console › App integrity.
3. **Build with the ids.** A plain `flutter build apk` / Android Studio "Run"
   does not pass them. Use
   `flutter build apk --release --dart-define-from-file=config/google.json`,
   or in Android Studio: Run › Edit configurations › *Additional run args*
   `--dart-define-from-file=config/google.json` (the repo also ships the
   "FocusFlow (Google Drive)" VS Code configuration).
4. **Consent screen status.** While it is *Testing*, only the listed test
   users can sign in and Google expires their grant after 7 days. Set it to
   **In production** when you ship: `drive.appdata` is a non-sensitive scope,
   so no verification review is needed. The consent screen needs working
   privacy-policy and terms URLs — `AppInfo.privacyUrl` / `termsUrl` are
   placeholders (`https://focusflow.app/…`) that must exist before then.
5. **iOS only:** run `dart run tool/google/apply_google_config.dart` on the Mac
   (it writes `ios/Flutter/GoogleSignIn.xcconfig`), then build with the same
   `--dart-define-from-file`.
6. **Smoke test on a real device**, two accounts or two devices: sign in →
   *Sync now* → the history row appears → on the second device sign in with
   the same account → *Restore*. With "Encrypt backups" on, both devices need
   the same backup PIN.

## Testing without Google

The sync tests (`test/core/sync/`) use an in-memory `FakeDriveStore` and
fake sign-in gateways, so they need no network, plugins or client ids.
