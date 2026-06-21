# Build Notes — Smart City Survey System

Native **Android** app (Flutter) for offline field engineering surveys:
Project → Site → Survey, satellite-map site diagrams with pins, photos, GPS,
and A4 PDF report export (single site + project-level merged / per-site).

## Toolchain (verified working)

| Tool | Version |
|------|---------|
| Flutter | 3.27 (Dart 3.6.1) |
| Kotlin Gradle plugin | **2.2.0** (`android/settings.gradle`) |
| Android Gradle Plugin | 8.1.0 |
| Gradle | 8.3 |
| JDK | 17 |
| compileSdk / minSdk | 35 / 23 |

Verified: `flutter analyze` (0 issues) · `flutter test` (6/6) ·
`flutter build apk --debug` → `build/app/outputs/flutter-apk/app-debug.apk`.

## Why some dependencies are pinned

The default Flutter 3.27 Android toolchain (AGP 8.1, Kotlin 1.8, compileSdk 35)
is older than what the *latest* versions of several plugins demand. Rather than
upgrade the whole toolchain (AGP/Gradle/SDK downloads), the following minimal
pins keep everything building on the current setup:

- **geolocator: ^13.0.0** — geolocator 14's `geolocator_android` 5.0.3 calls
  `Color.toARGB32()`, which doesn't exist in this Flutter SDK. 13.x uses the
  same Dart API we rely on (`LocationSettings`, `getCurrentPosition`).
- **connectivity_plus: 6.0.5** — 7.x pulls `androidx.core:core:1.18.0`, which
  requires AGP 8.9.1 + compileSdk 36. 6.0.5 keeps the same `List<ConnectivityResult>`
  API and drops that requirement.
- **androidx.core pinned to 1.13.1** (`android/app/build.gradle`
  `resolutionStrategy.force`) — `share_plus` pulls `androidx.core-ktx:1.16.0`
  which requires AGP 8.6+. 1.13.1 is compatible with AGP 8.1 and these plugins
  don't use 1.16-only APIs.
- **Kotlin plugin → 2.2.0** — `share_plus` 12 is compiled with Kotlin 2.2, so
  the project's Kotlin compiler must be ≥ 2.2.0 to read its metadata.

### If you later upgrade Flutter (≥ 3.29)
Most of the above can be reverted: bump AGP (≥ 8.6) + compileSdk (≥ 36) and the
`force`/downgrades become unnecessary. Re-run `flutter pub upgrade` and remove
the `resolutionStrategy` block in `android/app/build.gradle`.

## Run

```bash
flutter pub get
flutter run -d <android-device-or-emulator>   # live run
# or install the built APK:
adb install build/app/outputs/flutter-apk/app-debug.apk
```

`adb`/`emulator` live in `~/Library/Android/sdk/{platform-tools,emulator}`.

## Manual smoke test (on a device)

Templates → (default seeded) → create/edit a template ·
New Project (pick template) → New Site → Capture GPS · drop pins on satellite
diagram + Save snapshot · add photos · fill Survey Form · Export PDF.
Project list → "Export all sites" → merged PDF / per-site PDFs.
Toggle airplane mode to confirm everything except fresh map tiles works offline.
