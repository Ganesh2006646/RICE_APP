# RiceAgent

Full-stack agent app for rice-mill orders — **Windows + Android only**.

## Structure
- `mobile/flutter_app`: Flutter app (Offline-first, SQLite/Drift)

## Prerequisites
- Flutter SDK
- Android Studio / Android SDK

## Setup

1. Navigate to `mobile/flutter_app`.
2. Run `flutter pub get` to install dependencies.
3. Run `dart run build_runner build` to generate Drift database code.
4. Run `flutter run` to start the app.

## Building Release APK

**Windows:**
```bash
cd mobile/flutter_app
build_release.bat
```

**Manual Build (Split per ABI - Recommended):**
```bash
flutter build apk --release --split-per-abi
```

## APK Size

| APK Type | Size |
|----------|------|
| **arm64-v8a** (most devices) | **~25MB** |
| armeabi-v7a (older devices) | ~23MB |
| x86_64 (emulators) | ~26MB |

## Data Management

The app stores data locally in SQLite. Add data using the built-in screens:

| Data Type | How to Add |
|-----------|------------|
| **Customers** | Home → Customers → (+) Add Customer |
| **Rice Varieties** | Home → Rice Varieties → (+) Add Variety |

## Excel Import Formats

You can bulk-upload data via Excel (.xlsx or .xls).

### 1. Customers
| Recommended Header | Also Accepts | Default Col |
| :--- | :--- | :--- |
| **Shop Name** | Name, Party | A |
| **Place** | City | B |
| **Phone** | Mobile, Cell | C |
| **GST** | TIN | D |

### 2. Products (Rice Varieties)
| Recommended Header | Also Accepts | Default Col |
| :--- | :--- | :--- |
| **Name** | Variety | A |
| **Price** | Rate, Cost | B |
| **GST** | Tax | C |
| **SKU** | Code | D |
