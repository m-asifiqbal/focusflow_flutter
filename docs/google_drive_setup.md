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
| **Android** | package `com.iqballab.focusflow` + SHA-1 of each signing key (debug, upload, Play app signing) | picked up automatically by package + SHA-1 |
| **iOS** | bundle id `com.iqballab.focusflow` | `GOOGLE_IOS_CLIENT_ID` + its reversed id |

Get the debug SHA-1 with
`keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android`.
Get the Play signing SHA-1 from Play Console → App integrity.

## 3. iOS URL scheme

Create `ios/Flutter/GoogleSignIn.xcconfig`. It is git-ignored, and both
Debug.xcconfig and Release.xcconfig include it if it exists:

```
GOOGLE_REVERSED_CLIENT_ID = com.googleusercontent.apps.1234567890-abcdef
```

The value is the iOS client's *reversed* client id, from the iOS client's
plist download. Info.plist registers it as a URL scheme, and Google sign-in
returns to the app through that scheme.

## 4. Build / run with the ids

```bash
flutter run -d "iPhone 17 Pro" \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=1234567890-web.apps.googleusercontent.com \
  --dart-define=GOOGLE_IOS_CLIENT_ID=1234567890-ios.apps.googleusercontent.com

flutter build appbundle --dart-define=GOOGLE_SERVER_CLIENT_ID=… --dart-define=GOOGLE_IOS_CLIENT_ID=…
```

A `--dart-define-from-file=google.json` file works too. Keep it out of git.

Availability (`GoogleConfig.isConfigured`): Android needs
`GOOGLE_SERVER_CLIENT_ID`, and iOS needs `GOOGLE_IOS_CLIENT_ID`.

## How it behaves

- **Sign in** (Welcome/Sign in, Settings, Backup & Sync): `GoogleSignIn.instance.initialize`
  → `authenticate` → `authorizationClient.authorizeScopes([drive.appdata])`.
  If the user declines Drive consent, the app doesn't sign in.
- **Sign in with Apple** (iOS only) gives a profile only, with no Drive.
- **Sync now** works in these steps:
  1. Build a `.ffbackup`. It's encrypted with the stored backup key when
     "Encrypt backups" is on.
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
- **Sign out** forgets the profile, and local data stays. **Delete account
  & Drive data** deletes every file in appDataFolder and revokes the grant
  (`disconnect`).

## Testing without Google

The sync tests (`test/core/sync/`) use an in-memory `FakeDriveStore` and
fake sign-in gateways, so they need no network, plugins or client ids.
