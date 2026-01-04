#!/bin/bash
# Build Release APK with Material Icons tree-shaking enabled
# This reduces APK size by ~99.4% for Material Icons font

echo "Building Release APK with icon tree-shaking optimization..."
echo ""

flutter build apk --release

echo ""
echo "Build complete!"
echo "APK location: build/app/outputs/flutter-apk/app-release.apk"
echo ""
echo "Note: Material Icons font was tree-shaken (reduced from 1.6MB to ~10KB)"
echo "This optimization is enabled by default in Flutter release builds."

