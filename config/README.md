# config/

Build-time configuration that must stay out of git.

| File | Committed? | What |
|---|---|---|
| `google.example.json` | yes | Template for the Google Drive OAuth client ids |
| `google.json` | **no** (git-ignored) | Your real ids — copy the example and fill it in |

Turn on Google Drive backup & sync:

```bash
cp config/google.example.json config/google.json   # then paste your ids
dart run tool/google/apply_google_config.dart       # validates + writes the iOS URL scheme
flutter run --dart-define-from-file=config/google.json
```

`GOOGLE_SERVER_CLIENT_ID` is the **Web application** client id (Android needs it).
`GOOGLE_IOS_CLIENT_ID` is the **iOS** client id. The Android client needs no id in
the app — Google matches it by package name + SHA-1. Full walkthrough:
[docs/google_drive_setup.md](../docs/google_drive_setup.md).

Without `google.json` the app still builds and runs; Drive shows "not set up in this
build" and local backups keep working.
