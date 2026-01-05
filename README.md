# RiceAgent

Full-stack agent app for rice-mill orders.

## Structure
- `mobile/flutter_app`: Flutter Android app (Offline-first)

## Prerequisites
- Flutter SDK
- Android Studio / Android SDK


## Mobile App Setup

1. Navigate to `mobile/flutter_app`.
2. Run `flutter pub get` to install dependencies.
3. Run `dart run build_runner build` to generate Drift database code (`database.g.dart`).
4. Run `flutter run` to start the app on an emulator/device.

### Building Release APK

**Windows:**
```bash
cd mobile/flutter_app
build_release.bat
```

**Linux/Mac:**
```bash
cd mobile/flutter_app
chmod +x build_release.sh
./build_release.sh
```

**Manual Build (Universal APK):**
```bash
flutter build apk --release
```

**Optimized Build (Split per ABI - Recommended):**
```bash
flutter build apk --release --split-per-abi
```

### APK Size Optimization

The app is optimized for smaller APK size with:
- **Code shrinking (R8/ProGuard)** - Removes unused code
- **Resource shrinking** - Removes unused resources
- **Split APKs per architecture** - Each device downloads only what it needs

| APK Type | Size |
|----------|------|
| Universal APK | ~63MB |
| **arm64-v8a** (most devices) | **~25MB** |
| armeabi-v7a (older devices) | ~23MB |
| x86_64 (emulators) | ~26MB |

**Output Location:** `build/app/outputs/flutter-apk/`

## Adding Data (Customers & Rice Varieties)

The app stores data locally in SQLite. Add data using the built-in screens:

| Data Type | How to Add |
|-----------|------------|
| **Customers** | Home → Customers → (+) Add Customer |
| **Rice Varieties** | Home → Rice Varieties → (+) Add Variety |

No database editing required - everything is managed through the app UI!


