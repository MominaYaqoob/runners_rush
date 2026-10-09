# Runners Rush

A landscape endless runner built with Flutter and Flame. Jump over ground hazards and flying obstacles, collect coins, unlock characters and backgrounds, and chase a local high score.

**Package:** `com.runnersrush.runners_rush`

## Features

- Endless run with rising speed, ground and flying obstacles, coins, and shields
- Male / female characters with shop unlocks and themed backgrounds
- Glass HUD screens (home, pause, game over, shop, settings)
- Local high score, recent runs, daily reward, and settings persistence
- Sound effects, background music, optional vibration
- AdMob integration (consent / UMP, app open, interstitial, rewarded, Settings native ad)
- In-app Privacy Policy and Terms of Service

## Requirements

- Flutter SDK (stable; project SDK constraint is in `pubspec.yaml`)
- Android Studio / Xcode tooling for device or emulator builds

## How to run

```bash
flutter pub get
flutter run
```

Useful checks:

```bash
flutter analyze
flutter test
```

Landscape orientation is preferred (the app requests landscape at startup).

## Release build (Android)

Release signing requires `android/key.properties` (this file is gitignored). Create it next to `android/app/`:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=YOUR_KEY_ALIAS
storeFile=../path/to/your-upload-keystore.jks
```

`storeFile` is resolved relative to `android/app/`.

Then build:

```bash
flutter build appbundle --release
# or
flutter build apk --release
```

Without `android/key.properties`, release assemble/bundle tasks fail on purpose (no debug-signing fallback).

## Project layout (high level)

- `lib/game/` — Flame game loop and entities
- `lib/screens/` — UI screens
- `lib/ads/` — AdMob helpers and Settings native ad
- `lib/services/` — audio, settings, shop, scores, etc.
- `assets/images/`, `assets/sounds/` — art and audio

## CI

GitHub Actions workflow `.github/workflows/ci.yml` runs `flutter pub get`, `flutter analyze`, and `flutter test` on push and pull requests.
