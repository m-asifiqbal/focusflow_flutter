# Releasing FocusFlow (Google Play)

## Who signs what

| Key | Lives in | Signs | Get its SHA-1 |
|---|---|---|---|
| **debug** | `%USERPROFILE%\.android\debug.keystore` (the Android SDK makes it) | `flutter run`, profile builds | `keytool -list -v -alias androiddebugkey -keystore %USERPROFILE%\.android\debug.keystore -storepass android` |
| **upload** | your keystore (this machine: `D:\Play_store_apps\FocusAndWrite\focusandwrite-upload.jks`, alias `upload`) | every `--release` APK / AAB you build | `keytool -list -v -alias upload -keystore <the .jks>` |
| **app signing** | Google (Play App Signing, on by default for AABs) | the APKs Play delivers to users | Play Console › Test and release › Setup › **App signing** |

The upload key is permanent: its SHA-1 never changes as long as you keep the
keystore. But users who install from Play get an APK signed with **Google's**
app-signing key, which is a different key with its own SHA-1. Anything that
checks the signing certificate (Google sign-in for Drive backup) must know all
three.

## `android/key.properties`

`android/app/build.gradle.kts` signs the release variant with the key described
in `android/key.properties`. The file is git-ignored (so are `*.jks` and
`*.keystore`) and has four lines:

```properties
storePassword=<password>
keyPassword=<same password: PKCS12 keystores have one>
keyAlias=upload
storeFile=D:/Play_store_apps/FocusAndWrite/focusandwrite-upload.jks
```

Forward slashes in `storeFile`. On another machine copy the `.jks` over and
change that path. Without `key.properties`, release builds are signed with the
**debug** key and cannot be uploaded to Play.

`./gradlew :app:signingReport` (in `android/`) prints which key each variant
uses. `release` must show the upload key's alias and SHA-1.

The folder `D:\Play_store_apps\FocusAndWrite` (this PC) keeps what git does not:
the keystore, `build-inputs\google.json` (a copy of `config/google.json`),
`key.properties.template`, each release's `mapping.txt` under `symbols\` and the
finished builds. Its `README.md` lists every file and the steps to rebuild on a new PC.

> **Back up the `.jks` and its password** (password manager + an offline copy).
> They are all that signs your updates. If they are lost the app is not lost
> (Play App Signing): Play support can reset the upload key from the public
> certificate (`focusandwrite-upload-certificate.pem`, kept next to the `.jks`).

## Build

Bump `version:` in `pubspec.yaml` (`1.0.0+1`: the number after `+` is the
version code, which must grow with every upload), then:

```bash
flutter build appbundle --release --dart-define-from-file=config/google.json
# → build/app/outputs/bundle/release/app-release.aab   (upload this to Play)
flutter build apk --release --dart-define-from-file=config/google.json
# → build/app/outputs/flutter-apk/app-release.apk      (sideload / testers)
```

`config/google.json` carries the Google OAuth client ids
(docs/google_drive_setup.md); without it the build works but Drive says "not
set up in this build".

## Google sign-in (Drive backup) and the signing keys

Google matches the app by package name + signing-certificate SHA-1, and an
Android OAuth client holds **one** SHA-1. So create one **Android** OAuth client
per key, all with package `com.iqballab.focusflow` in the same Cloud project:

1. debug key: for `flutter run`;
2. upload key: for release APKs you build and sideload;
3. Play app-signing key: for anything installed from Play (internal, closed,
   open testing and production). Its SHA-1 exists only after the first upload.

The Web client id in `config/google.json` stays the same for all of them.
A key whose SHA-1 is missing fails sign-in with "developer error" / code 10
on that build only.

## Switching the key on a phone

Android refuses to update an app with a build signed by a different key. A
phone that has a debug-signed (or older release-signed) FocusFlow must
**uninstall it first, which deletes the local database**. Make a backup first
(Settings › Backup & Sync › Back up to device) and restore it afterwards.

## First upload checklist

- [ ] `pubspec.yaml` version and version code
- [ ] `config/google.json` filled in; consent screen set to *In production*
- [ ] real privacy / terms / support URLs in `lib/core/constants/app_info.dart`
- [ ] Play Console declarations for the permissions the app uses: exact alarms
      (`USE_EXACT_ALARM`), foreground service type *special use* (alarm
      guard), battery-optimisation exemption, full-screen intents — wording in
      docs/notifications.md
- [ ] upload the AAB, then copy the **App signing** SHA-1 from Play Console and
      add it as another Android OAuth client (see above)
