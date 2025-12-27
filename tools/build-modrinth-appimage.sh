#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "=== Building Modrinth App AppImage ==="

# Build frontend and Rust backend
echo "Building app..."
cd apps/app
pnpm tauri build --bundles appimage 2>&1 || true

# Check if AppDir was created
APPDIR="../../target/release/bundle/appimage/Modrinth App.AppDir"
if [ ! -d "$APPDIR" ]; then
	echo "ERROR: AppDir not found. Build failed."
	exit 1
fi

cd "../../target/release/bundle/appimage"

# Remove old AppImage if exists
rm -f *.AppImage

# Fix icon symlink (desktop file expects ModrinthApp.png)
if [ -f "Modrinth App.AppDir/Modrinth App.png" ] && [ ! -f "Modrinth App.AppDir/ModrinthApp.png" ]; then
	cp "Modrinth App.AppDir/Modrinth App.png" "Modrinth App.AppDir/ModrinthApp.png"
fi

# Get the latest git tag for versioning
GIT_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "unknown")

# Create AppImage using system appimagetool (skips linuxdeploy's old strip)
echo "Creating AppImage with appimagetool..."
ARCH=x86_64 appimagetool "Modrinth App.AppDir" "Modrinth_App_${GIT_TAG}_amd64.AppImage"

echo ""
echo "=== AppImage created successfully ==="
ls -lh *.AppImage
