# Qout app

Flutter app (Android first). Feature-first structure: `lib/features/<feature>/{data,domain,presentation}`,
shared code in `lib/core/`, app shell (theme, router) in `lib/app/`.

## Flavors

| Flavor | Application ID | API base URL (default) |
|---|---|---|
| `dev` | `tn.qout.app.dev` | `http://10.0.2.2:8000` (host machine from the Android emulator) |
| `staging` | `tn.qout.app.staging` | `https://api.staging.qout.invalid` (placeholder) |
| `prod` | `tn.qout.app` | `https://api.qout.invalid` (placeholder) |

A flavor is required; the app refuses to start without one. Override the API URL with
`--dart-define=API_BASE_URL=...`, e.g. for a physical phone on the same Wi-Fi:

```sh
flutter run --flavor dev --dart-define=API_BASE_URL=http://192.168.1.20:8000
```

## Commands

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs --force-jit   # after changing freezed models or drift tables
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter run --flavor dev
flutter build apk --debug --flavor dev
```

Generated files (`*.freezed.dart`) are committed, so a fresh clone analyzes and tests
without running build_runner first.
