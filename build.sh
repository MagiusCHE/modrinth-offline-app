#!/bin/bash
set -e

# Working directories
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DIST_DIR="$SCRIPT_DIR/dist"
SRC_BASE_DIR="$SCRIPT_DIR/src"
MODRINTH_DIR="$SRC_BASE_DIR/modrinth-core"
SPM_DIR="$SRC_BASE_DIR/simple-profiles-manager"

echo "=== Modrinth Build Script ==="
echo "Script directory: $SCRIPT_DIR"
echo "Dist directory: $DIST_DIR"

# 1. Clone repositories or update if they exist
mkdir -p "$DIST_DIR"
mkdir -p "$SRC_BASE_DIR"

echo ""
echo "=== Step 1a: Clone/Update Modrinth repository ==="
if [ -d "$MODRINTH_DIR/.git" ]; then
    echo "modrinth-core directory exists, reset and pull..."
    cd "$MODRINTH_DIR"
    git reset --hard HEAD
    git clean -fd
    git checkout main
    git pull origin main
else
    rm -rf "$MODRINTH_DIR"
    git clone https://github.com/modrinth/code "$MODRINTH_DIR"
fi

echo ""
echo "=== Step 1b: Clone/Update Simple Profiles Manager repository ==="
if [ -d "$SPM_DIR/.git" ]; then
    echo "simple-profiles-manager directory exists, reset and pull..."
    cd "$SPM_DIR"
    git reset --hard HEAD
    git clean -fd
    git checkout main
    git pull origin main
else
    rm -rf "$SPM_DIR"
    mkdir -p "$SPM_DIR"
    git clone https://github.com/MagiusCHE/simple-profiles-manager "$SPM_DIR"
fi

# 2. Check if Modrinth AppImage already exists
BUILD_MODRINTH=true
EXISTING_APPIMAGE=$(ls "$DIST_DIR"/Modrinth_App_*.AppImage 2>/dev/null | head -1)
if [ -n "$EXISTING_APPIMAGE" ]; then
    echo ""
    echo "Modrinth AppImage already exists: $(basename "$EXISTING_APPIMAGE")"
    echo "Do you want to rebuild it? (y/n)"
    read -r response
    if [ "$response" != "y" ]; then
        BUILD_MODRINTH=false
        echo "Skipping Modrinth build..."
    fi
fi

if [ "$BUILD_MODRINTH" = true ]; then
    # 2a. Apply patch
    echo ""
    echo "=== Step 2: Apply patch ==="
    cd "$MODRINTH_DIR"
    if git apply --check "$SCRIPT_DIR/tools/patch_01.patch" 2>/dev/null; then
        git apply "$SCRIPT_DIR/tools/patch_01.patch"
        echo "Patch applied successfully!"
    else
        echo "Patch already applied or not applicable, continuing..."
    fi

    # 3. Build AppImage
    echo ""
    echo "=== Step 3: Build AppImage ==="
    cd "$MODRINTH_DIR"

    # Clean build cache to avoid stale paths
    echo "Cleaning build cache..."
    cargo clean 2>/dev/null || true

    # Copy .env.prod to .env for build variables
    echo "Configuring production environment..."
    cp packages/app-lib/.env.prod packages/app-lib/.env

    # Install dependencies
    echo "Installing pnpm dependencies..."
    pnpm install

    # Build frontend and Rust backend
    echo "Building app..."
    cd apps/app
    pnpm tauri build --bundles appimage 2>&1 || true

    # Check if AppDir was created
    APPDIR="$MODRINTH_DIR/target/release/bundle/appimage/Modrinth App.AppDir"
    if [ ! -d "$APPDIR" ]; then
        echo "ERROR: AppDir not found. Build failed."
        exit 1
    fi

    cd "$MODRINTH_DIR/target/release/bundle/appimage"

    # Remove old AppImage if exists
    rm -f *.AppImage

    # Fix icon symlink (desktop file expects ModrinthApp.png)
    if [ -f "Modrinth App.AppDir/Modrinth App.png" ] && [ ! -f "Modrinth App.AppDir/ModrinthApp.png" ]; then
        cp "Modrinth App.AppDir/Modrinth App.png" "Modrinth App.AppDir/ModrinthApp.png"
    fi

    # Get the latest git tag for versioning
    GIT_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "unknown")

    # Create AppImage using system appimagetool
    echo "Creating AppImage with appimagetool..."
    ARCH=x86_64 appimagetool "Modrinth App.AppDir" "Modrinth_App_${GIT_TAG}_amd64.AppImage"

    # Copy AppImage to dist directory
    echo ""
    echo "=== Copy Modrinth AppImage to dist ==="
    rm -f "$DIST_DIR"/Modrinth_App_*.AppImage
    cp *.AppImage "$DIST_DIR/"
fi

# 4. Check if Simple Profiles Manager binary already exists
BUILD_SPM=true
if [ -f "$DIST_DIR/simple-profiles-manager" ]; then
    echo ""
    echo "Simple Profiles Manager binary already exists."
    echo "Do you want to rebuild it? (y/n)"
    read -r response
    if [ "$response" != "y" ]; then
        BUILD_SPM=false
        echo "Skipping Simple Profiles Manager build..."
    fi
fi

if [ "$BUILD_SPM" = true ]; then
    echo ""
    echo "=== Step 4: Build Simple Profiles Manager ==="
    cd "$SPM_DIR"

    # Clean build cache to avoid stale paths
    echo "Cleaning build cache..."
    cargo clean 2>/dev/null || true

    cargo build --release

    # Copy binary to dist directory
    echo ""
    echo "=== Copy Simple Profiles Manager binary to dist ==="
    cp target/release/simple-profiles-manager "$DIST_DIR/"
fi

echo ""
echo "=== Build completed successfully! ==="
echo "Files available in: $DIST_DIR"
ls -lh "$DIST_DIR/"
