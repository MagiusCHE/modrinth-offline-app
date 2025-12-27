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

# =============================================================================
# PKG_CONFIG_PATH Setup (for Steam Deck and other non-standard setups)
# =============================================================================
# Auto-detect common pkg-config paths
DETECTED_PKG_PATHS=""

# Common locations for .pc files (order matters - more specific first)
for pc_dir in \
    "/usr/lib/pkgconfig" \
    "/usr/share/pkgconfig" \
    "/usr/lib64/pkgconfig" \
    "/usr/lib/x86_64-linux-gnu/pkgconfig" \
    "/usr/local/lib/pkgconfig" \
    "/usr/local/lib64/pkgconfig"; do
    if [ -d "$pc_dir" ]; then
        if [ -n "$DETECTED_PKG_PATHS" ]; then
            DETECTED_PKG_PATHS="$DETECTED_PKG_PATHS:$pc_dir"
        else
            DETECTED_PKG_PATHS="$pc_dir"
        fi
    fi
done

if [ -n "$DETECTED_PKG_PATHS" ]; then
    # Append to existing PKG_CONFIG_PATH if set, otherwise set it
    if [ -n "$PKG_CONFIG_PATH" ]; then
        export PKG_CONFIG_PATH="$DETECTED_PKG_PATHS:$PKG_CONFIG_PATH"
    else
        export PKG_CONFIG_PATH="$DETECTED_PKG_PATHS"
    fi
    echo "PKG_CONFIG_PATH: $PKG_CONFIG_PATH"
fi

# Unset PKG_CONFIG_LIBDIR if set, as it overrides PKG_CONFIG_PATH
unset PKG_CONFIG_LIBDIR

# =============================================================================
# Dependency Check
# =============================================================================
echo ""
echo "=== Checking dependencies ==="

MISSING_DEPS=false

# Function to check if a command exists
check_command() {
    local cmd="$1"
    local install_hint="$2"

    if command -v "$cmd" &> /dev/null; then
        echo "[OK] $cmd found: $(command -v "$cmd")"
        return 0
    else
        echo "[MISSING] $cmd not found"
        echo "    Install with: $install_hint"
        MISSING_DEPS=true
        return 1
    fi
}

# Check git
check_command "git" "sudo pacman -S git  OR  sudo apt install git"

# Check C compiler/linker (cc)
check_command "cc" "sudo pacman -S base-devel  OR  sudo apt install build-essential"

# Check pkg-config
check_command "pkg-config" "sudo pacman -S pkgconf  OR  sudo apt install pkg-config"

# Function to check if a pkg-config library exists
check_pkg_config() {
    local lib="$1"
    local install_hint="$2"

    if pkg-config --exists "$lib" 2>/dev/null; then
        echo "[OK] $lib found (pkg-config)"
        return 0
    else
        echo "[MISSING] $lib development library not found"
        echo "    Install with: $install_hint"
        MISSING_DEPS=true
        return 1
    fi
}

# Check GTK/Tauri dependencies (only if pkg-config is available)
if command -v pkg-config &> /dev/null; then
    echo ""
    echo "--- Checking Tauri/GTK development libraries ---"

    # GLib 2.0 / GIO dependencies (required for glib-2.0 and gio-2.0 to work properly)
    check_pkg_config "libffi" "sudo pacman -S libffi  OR  sudo apt install libffi-dev"
    check_pkg_config "zlib" "sudo pacman -S zlib  OR  sudo apt install zlib1g-dev"
    check_pkg_config "mount" "sudo pacman -S util-linux-libs  OR  sudo apt install libmount-dev"
    check_pkg_config "sysprof-capture-4" "sudo pacman -S libsysprof-capture  OR  sudo apt install libsysprof-4-dev"
    check_pkg_config "libpcre2-8" "sudo pacman -S pcre2  OR  sudo apt install libpcre2-dev"

    # Compression libraries
    check_pkg_config "libbz2" "sudo pacman -S bzip2  OR  sudo apt install libbz2-dev"
    check_pkg_config "libpng" "sudo pacman -S libpng  OR  sudo apt install libpng-dev"
    check_pkg_config "libbrotlidec" "sudo pacman -S brotli  OR  sudo apt install libbrotli-dev"
    check_pkg_config "liblzma" "sudo pacman -S xz  OR  sudo apt install liblzma-dev"
    check_pkg_config "libzstd" "sudo pacman -S zstd  OR  sudo apt install libzstd-dev"

    # Text rendering dependencies (required by pango/gtk)
    check_pkg_config "harfbuzz" "sudo pacman -S harfbuzz  OR  sudo apt install libharfbuzz-dev"
    check_pkg_config "freetype2" "sudo pacman -S freetype2  OR  sudo apt install libfreetype-dev"
    check_pkg_config "fontconfig" "sudo pacman -S fontconfig  OR  sudo apt install libfontconfig-dev"
    check_pkg_config "fribidi" "sudo pacman -S fribidi  OR  sudo apt install libfribidi-dev"
    check_pkg_config "graphite2" "sudo pacman -S graphite  OR  sudo apt install libgraphite2-dev"
    check_pkg_config "expat" "sudo pacman -S expat  OR  sudo apt install libexpat1-dev"
    check_pkg_config "libthai" "sudo pacman -S libthai  OR  sudo apt install libthai-dev"
    check_pkg_config "datrie-0.2" "sudo pacman -S libdatrie  OR  sudo apt install libdatrie-dev"

    # Cairo dependencies
    check_pkg_config "pixman-1" "sudo pacman -S pixman  OR  sudo apt install libpixman-1-dev"
    check_pkg_config "libjpeg" "sudo pacman -S libjpeg-turbo  OR  sudo apt install libjpeg-dev"
    check_pkg_config "libtiff-4" "sudo pacman -S libtiff  OR  sudo apt install libtiff-dev"

    # Cairo and Pango
    check_pkg_config "cairo" "sudo pacman -S cairo  OR  sudo apt install libcairo2-dev"
    check_pkg_config "pango" "sudo pacman -S pango  OR  sudo apt install libpango1.0-dev"

    # X11 dependencies (for GTK X11 backend)
    check_pkg_config "x11" "sudo pacman -S libx11  OR  sudo apt install libx11-dev"
    check_pkg_config "xext" "sudo pacman -S libxext  OR  sudo apt install libxext-dev"
    check_pkg_config "xrender" "sudo pacman -S libxrender  OR  sudo apt install libxrender-dev"
    check_pkg_config "xcb" "sudo pacman -S libxcb  OR  sudo apt install libxcb1-dev"
    check_pkg_config "xau" "sudo pacman -S libxau  OR  sudo apt install libxau-dev"
    check_pkg_config "xdmcp" "sudo pacman -S libxdmcp  OR  sudo apt install libxdmcp-dev"
    check_pkg_config "xi" "sudo pacman -S libxi  OR  sudo apt install libxi-dev"
    check_pkg_config "xrandr" "sudo pacman -S libxrandr  OR  sudo apt install libxrandr-dev"
    check_pkg_config "xcursor" "sudo pacman -S libxcursor  OR  sudo apt install libxcursor-dev"
    check_pkg_config "xfixes" "sudo pacman -S libxfixes  OR  sudo apt install libxfixes-dev"
    check_pkg_config "xcomposite" "sudo pacman -S libxcomposite  OR  sudo apt install libxcomposite-dev"
    check_pkg_config "xdamage" "sudo pacman -S libxdamage  OR  sudo apt install libxdamage-dev"
    check_pkg_config "xinerama" "sudo pacman -S libxinerama  OR  sudo apt install libxinerama-dev"
    check_pkg_config "xft" "sudo pacman -S libxft  OR  sudo apt install libxft-dev"

    # Wayland dependencies (for GTK Wayland backend)
    check_pkg_config "wayland-client" "sudo pacman -S wayland  OR  sudo apt install libwayland-dev"
    check_pkg_config "xkbcommon" "sudo pacman -S libxkbcommon  OR  sudo apt install libxkbcommon-dev"

    # OpenGL/EGL dependencies
    check_pkg_config "epoxy" "sudo pacman -S libepoxy  OR  sudo apt install libepoxy-dev"
    check_pkg_config "egl" "sudo pacman -S libglvnd  OR  sudo apt install libegl1-mesa-dev"
    check_pkg_config "gl" "sudo pacman -S mesa  OR  sudo apt install libgl1-mesa-dev"

    # GLib 2.0
    check_pkg_config "glib-2.0" "sudo pacman -S glib2  OR  sudo apt install libglib2.0-dev"

    # ATK
    check_pkg_config "atk" "sudo pacman -S atk  OR  sudo apt install libatk1.0-dev"

    # GDK Pixbuf
    check_pkg_config "gdk-pixbuf-2.0" "sudo pacman -S gdk-pixbuf2  OR  sudo apt install libgdk-pixbuf2.0-dev"
    check_pkg_config "shared-mime-info" "sudo pacman -S shared-mime-info  OR  sudo apt install shared-mime-info"

    # GTK 3
    check_pkg_config "gtk+-3.0" "sudo pacman -S gtk3  OR  sudo apt install libgtk-3-dev"

    # WebKit2GTK
    check_pkg_config "webkit2gtk-4.1" "sudo pacman -S webkit2gtk-4.1  OR  sudo apt install libwebkit2gtk-4.1-dev"

    # libsoup (HTTP library for WebKit)
    check_pkg_config "libsoup-3.0" "sudo pacman -S libsoup3  OR  sudo apt install libsoup-3.0-dev"

    # OpenSSL
    check_pkg_config "openssl" "sudo pacman -S openssl  OR  sudo apt install libssl-dev"

    echo ""
fi

# Check Rust/Cargo
check_command "cargo" "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"

# Check Node.js/npm
check_command "npm" "
    # Using nvm (recommended):
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    source ~/.bashrc
    nvm install --lts

    # Or using package manager:
    sudo pacman -S nodejs npm  OR  sudo apt install nodejs npm"

# Check pnpm
check_command "pnpm" "npm install -g pnpm  OR  curl -fsSL https://get.pnpm.io/install.sh | sh -"

# Check appimagetool
check_command "appimagetool" "
    # Download from: https://github.com/AppImage/appimagetool/releases
    wget https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage
    chmod +x appimagetool-x86_64.AppImage
    sudo mv appimagetool-x86_64.AppImage /usr/local/bin/appimagetool"

# Exit if any dependencies are missing
if [ "$MISSING_DEPS" = true ]; then
    echo ""
    echo "ERROR: Missing dependencies. Please install them and try again."
    echo "After installing, you may need to restart your terminal or run: source ~/.bashrc"
    exit 1
fi

echo ""
echo "All dependencies found!"

# =============================================================================
# Build Process
# =============================================================================

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

    # Ensure PKG_CONFIG_PATH is set for Cargo build
    export PKG_CONFIG_PATH="/usr/lib/pkgconfig:/usr/share/pkgconfig:/usr/lib64/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
    unset PKG_CONFIG_LIBDIR
    echo "PKG_CONFIG_PATH for build: $PKG_CONFIG_PATH"

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
