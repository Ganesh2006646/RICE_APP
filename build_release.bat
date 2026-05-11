@echo off
REM Build Release APK with size optimizations
REM - split-per-abi: Produces separate APKs per CPU architecture (~18MB each instead of ~65MB fat APK)
REM - tree-shake-icons: Removes unused Material Icons (default in release)

echo Building Release APK with split-per-abi optimization...
echo.

flutter build apk --release --split-per-abi

echo.
echo Build complete!
echo.
echo APK locations (install the arm64-v8a one for modern phones):
echo   build\app\outputs\flutter-apk\app-arm64-v8a-release.apk  (modern phones)
echo   build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk (old 32-bit phones)
echo   build\app\outputs\flutter-apk\app-x86_64-release.apk     (emulators only)
echo.
echo Tip: For Google Play, use 'flutter build appbundle' instead (even smaller downloads).
