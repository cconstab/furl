#!/bin/bash

echo "🚀 FURL App - Store Publication Builder"
echo "======================================="

cd "$(dirname "$0")"

# Apply Android fixes first
echo "🔧 Applying Android compatibility fixes..."
bash fix_namespaces.sh

echo ""
echo "📱 Building Release APK..."
flutter build apk --release

if [ $? -eq 0 ]; then
    echo "✅ Release APK built successfully!"
    echo "📁 Location: build/app/outputs/flutter-apk/app-release.apk"
    
    # Get file size
    if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
        SIZE=$(ls -lh build/app/outputs/flutter-apk/app-release.apk | awk '{print $5}')
        echo "📊 APK Size: $SIZE"
    fi
else
    echo "❌ Release APK build failed!"
    exit 1
fi

echo ""
echo "📱 Building App Bundle (recommended for Play Store)..."
flutter build appbundle --release

if [ $? -eq 0 ]; then
    echo "✅ App Bundle built successfully!"
    echo "📁 Location: build/app/outputs/bundle/release/app-release.aab"
    
    # Get file size
    if [ -f "build/app/outputs/bundle/release/app-release.aab" ]; then
        SIZE=$(ls -lh build/app/outputs/bundle/release/app-release.aab | awk '{print $5}')
        echo "📊 AAB Size: $SIZE"
    fi
else
    echo "❌ App Bundle build failed!"
    exit 1
fi

echo ""
echo "🎉 Build Complete!"
echo "=================="
echo ""
echo "📦 Files ready for store submission:"
echo "  • APK: build/app/outputs/flutter-apk/app-release.apk"
echo "  • AAB: build/app/outputs/bundle/release/app-release.aab"
echo ""
echo "📋 Next steps:"
echo "  1. Test the release build on device"
echo "  2. Take screenshots for store listing"
echo "  3. Create store description and metadata"
echo "  4. Submit to Google Play Console"
echo ""
echo "📖 See STORE_PUBLICATION_CHECKLIST.md for detailed steps"
