# Build Optimization - Material Icons Tree-Shaking

## Overview

Flutter automatically optimizes Material Icons font during release builds by tree-shaking unused icons. This significantly reduces APK size.

## Optimization Details

- **Original Size:** ~1.6 MB (full Material Icons font)
- **Optimized Size:** ~10 KB (only used icons)
- **Reduction:** 99.4%
- **Status:** Enabled by default in release builds

## How It Works

During `flutter build apk --release`, Flutter:
1. Analyzes which Material Icons are actually used in the app
2. Removes unused icons from the font file
3. Includes only the icons that are referenced in the code

## Verification

When building, you'll see output like:
```
Font asset "MaterialIcons-Regular.otf" was tree-shaken, 
reducing it from 1645184 to 10204 bytes (99.4% reduction).
```

## Disabling Tree-Shaking (Not Recommended)

If you need to disable this optimization (not recommended):
```bash
flutter build apk --release --no-tree-shake-icons
```

## Build Scripts

Use the provided build scripts to ensure optimization:
- **Windows:** `build_release.bat`
- **Linux/Mac:** `build_release.sh`

Both scripts run `flutter build apk --release` which automatically enables tree-shaking.

## Impact

- **APK Size:** Reduced by ~1.6 MB
- **Performance:** No impact (only unused icons removed)
- **Functionality:** No impact (all used icons remain available)

