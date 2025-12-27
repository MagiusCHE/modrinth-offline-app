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
HAS_PACMAN=false
HAS_APT=false

# Detect package manager
if command -v pacman &> /dev/null; then
    HAS_PACMAN=true
    echo "Detected pacman package manager (Arch/Steam Deck)"
elif command -v apt &> /dev/null; then
    HAS_APT=true
    echo "Detected apt package manager (Debian/Ubuntu)"
fi

# Function to install a package automatically
auto_install_pkg() {
    local pacman_pkg="$1"
    local apt_pkg="$2"

    if [ "$HAS_PACMAN" = true ]; then
        echo "    Installing $pacman_pkg with pacman..."
        if sudo pacman -S --noconfirm --needed "$pacman_pkg"; then
            return 0
        else
            echo "    Failed to install $pacman_pkg"
            return 1
        fi
    elif [ "$HAS_APT" = true ]; then
        echo "    Installing $apt_pkg with apt..."
        if sudo apt install -y "$apt_pkg"; then
            return 0
        else
            echo "    Failed to install $apt_pkg"
            return 1
        fi
    else
        return 1
    fi
}

# Function to check if a command exists (and auto-install if possible)
check_command() {
    local cmd="$1"
    local pacman_pkg="$2"
    local apt_pkg="$3"

    if command -v "$cmd" &> /dev/null; then
        echo "[OK] $cmd found: $(command -v "$cmd")"
        return 0
    else
        echo "[MISSING] $cmd not found"
        if [ "$HAS_PACMAN" = true ] || [ "$HAS_APT" = true ]; then
            if auto_install_pkg "$pacman_pkg" "$apt_pkg"; then
                echo "[INSTALLED] $cmd"
                return 0
            fi
        fi
        echo "    Install with: sudo pacman -S $pacman_pkg  OR  sudo apt install $apt_pkg"
        MISSING_DEPS=true
        return 1
    fi
}

# Check git
check_command "git" "git" "git"

# Check C compiler/linker (cc)
check_command "cc" "base-devel" "build-essential"

# Check pkg-config
check_command "pkg-config" "pkgconf" "pkg-config"

# Function to check if a pkg-config library exists (and auto-install if possible)
# $4 = "optional" to make it non-blocking
check_pkg_config() {
    local lib="$1"
    local pacman_pkg="$2"
    local apt_pkg="$3"
    local optional="$4"

    if pkg-config --exists "$lib" 2>/dev/null; then
        echo "[OK] $lib found (pkg-config)"
        return 0
    else
        if [ "$optional" = "optional" ]; then
            echo "[SKIP] $lib not found (optional, some packages don't provide .pc files)"
            return 0
        fi
        echo "[MISSING] $lib development library not found"
        if [ "$HAS_PACMAN" = true ] || [ "$HAS_APT" = true ]; then
            if auto_install_pkg "$pacman_pkg" "$apt_pkg"; then
                # Re-check after installation
                if pkg-config --exists "$lib" 2>/dev/null; then
                    echo "[INSTALLED] $lib"
                    return 0
                else
                    # Package installed but no .pc file - that's ok for some packages
                    echo "[WARN] $pacman_pkg installed but $lib.pc not found (may be ok)"
                    return 0
                fi
            fi
        fi
        echo "    Install with: sudo pacman -S $pacman_pkg  OR  sudo apt install $apt_pkg"
        MISSING_DEPS=true
        return 1
    fi
}

# Check GTK/Tauri dependencies (only if pkg-config is available)
if command -v pkg-config &> /dev/null; then
    echo ""
    echo "--- Checking Tauri/GTK development libraries ---"

    # GLib 2.0 / GIO dependencies (required for glib-2.0 and gio-2.0 to work properly)
    check_pkg_config "libffi" "libffi" "libffi-dev"
    check_pkg_config "zlib" "zlib" "zlib1g-dev"
    check_pkg_config "mount" "util-linux-libs" "libmount-dev"
    check_pkg_config "sysprof-capture-4" "libsysprof-capture" "libsysprof-4-dev"
    check_pkg_config "libpcre2-8" "pcre2" "libpcre2-dev"

    # Compression libraries (some don't have .pc files on Arch, mark as optional)
    check_pkg_config "libbz2" "bzip2" "libbz2-dev" "optional"
    check_pkg_config "libpng" "libpng" "libpng-dev"
    check_pkg_config "libbrotlidec" "brotli" "libbrotli-dev"
    check_pkg_config "liblzma" "xz" "liblzma-dev"
    check_pkg_config "libzstd" "zstd" "libzstd-dev"

    # Text rendering dependencies (required by pango/gtk)
    check_pkg_config "harfbuzz" "harfbuzz" "libharfbuzz-dev"
    check_pkg_config "freetype2" "freetype2" "libfreetype-dev"
    check_pkg_config "fontconfig" "fontconfig" "libfontconfig-dev"
    check_pkg_config "fribidi" "fribidi" "libfribidi-dev"
    check_pkg_config "graphite2" "graphite" "libgraphite2-dev"
    check_pkg_config "expat" "expat" "libexpat1-dev"
    check_pkg_config "libthai" "libthai" "libthai-dev"
    check_pkg_config "datrie-0.2" "libdatrie" "libdatrie-dev"

    # Cairo dependencies (libjpeg often doesn't have .pc on Arch)
    check_pkg_config "pixman-1" "pixman" "libpixman-1-dev"
    check_pkg_config "libjpeg" "libjpeg-turbo" "libjpeg-dev" "optional"
    check_pkg_config "libtiff-4" "libtiff" "libtiff-dev"

    # Cairo and Pango
    check_pkg_config "cairo" "cairo" "libcairo2-dev"
    check_pkg_config "pango" "pango" "libpango1.0-dev"

    # X11 dependencies (for GTK X11 backend)
    check_pkg_config "x11" "libx11" "libx11-dev"
    check_pkg_config "xext" "libxext" "libxext-dev"
    check_pkg_config "xrender" "libxrender" "libxrender-dev"
    check_pkg_config "xcb" "libxcb" "libxcb1-dev"
    check_pkg_config "xau" "libxau" "libxau-dev"
    check_pkg_config "xdmcp" "libxdmcp" "libxdmcp-dev"
    check_pkg_config "xi" "libxi" "libxi-dev"
    check_pkg_config "xrandr" "libxrandr" "libxrandr-dev"
    check_pkg_config "xcursor" "libxcursor" "libxcursor-dev"
    check_pkg_config "xfixes" "libxfixes" "libxfixes-dev"
    check_pkg_config "xcomposite" "libxcomposite" "libxcomposite-dev"
    check_pkg_config "xdamage" "libxdamage" "libxdamage-dev"
    check_pkg_config "xinerama" "libxinerama" "libxinerama-dev"
    check_pkg_config "xft" "libxft" "libxft-dev"

    # Wayland dependencies (for GTK Wayland backend)
    check_pkg_config "wayland-client" "wayland" "libwayland-dev"
    check_pkg_config "xkbcommon" "libxkbcommon" "libxkbcommon-dev"

    # OpenGL/EGL dependencies
    check_pkg_config "epoxy" "libepoxy" "libepoxy-dev"
    check_pkg_config "egl" "libglvnd" "libegl1-mesa-dev"
    check_pkg_config "gl" "mesa" "libgl1-mesa-dev"

    # GLib 2.0
    check_pkg_config "glib-2.0" "glib2" "libglib2.0-dev"

    # ATK
    check_pkg_config "atk" "atk" "libatk1.0-dev"

    # GDK Pixbuf
    check_pkg_config "gdk-pixbuf-2.0" "gdk-pixbuf2" "libgdk-pixbuf2.0-dev"
    check_pkg_config "shared-mime-info" "shared-mime-info" "shared-mime-info"

    # GTK 3
    check_pkg_config "gtk+-3.0" "gtk3" "libgtk-3-dev"

    # WebKit2GTK
    check_pkg_config "webkit2gtk-4.1" "webkit2gtk-4.1" "libwebkit2gtk-4.1-dev"

    # libsoup (HTTP library for WebKit)
    check_pkg_config "libsoup-3.0" "libsoup3" "libsoup-3.0-dev"

    # OpenSSL
    check_pkg_config "openssl" "openssl" "libssl-dev"

    echo ""
fi

# Check Rust/Cargo (manual install required)
if ! command -v cargo &> /dev/null; then
    echo "[MISSING] cargo not found"
    echo "    Install with: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    MISSING_DEPS=true
else
    echo "[OK] cargo found: $(command -v cargo)"
fi

# Check Node.js/npm
check_command "npm" "nodejs" "nodejs"

# Check pnpm (install via npm if missing)
if ! command -v pnpm &> /dev/null; then
    echo "[MISSING] pnpm not found"
    if command -v npm &> /dev/null; then
        echo "    Installing pnpm via npm..."
        if npm install -g pnpm; then
            echo "[INSTALLED] pnpm"
        else
            echo "    Install with: npm install -g pnpm  OR  curl -fsSL https://get.pnpm.io/install.sh | sh -"
            MISSING_DEPS=true
        fi
    else
        echo "    Install with: npm install -g pnpm  OR  curl -fsSL https://get.pnpm.io/install.sh | sh -"
        MISSING_DEPS=true
    fi
else
    echo "[OK] pnpm found: $(command -v pnpm)"
fi

# Check appimagetool (download if missing)
if ! command -v appimagetool &> /dev/null; then
    echo "[MISSING] appimagetool not found"
    echo "    Downloading appimagetool..."
    if wget -q https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage -O /tmp/appimagetool && \
       chmod +x /tmp/appimagetool && \
       sudo mv /tmp/appimagetool /usr/local/bin/appimagetool; then
        echo "[INSTALLED] appimagetool"
    else
        echo "    Failed to install. Download manually from: https://github.com/AppImage/appimagetool/releases"
        MISSING_DEPS=true
    fi
else
    echo "[OK] appimagetool found: $(command -v appimagetool)"
fi

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

    # Create a wrapper script for pkg-config that forces the correct path
    # This ensures pkg-config always uses our paths regardless of how it's called
    PKG_CONFIG_WRAPPER="$MODRINTH_DIR/pkg-config-wrapper.sh"
    cat > "$PKG_CONFIG_WRAPPER" << 'WRAPPER_EOF'
#!/bin/bash
export PKG_CONFIG_PATH="/usr/lib/pkgconfig:/usr/share/pkgconfig:/usr/lib64/pkgconfig"
export PKG_CONFIG_ALLOW_SYSTEM_CFLAGS=1
export PKG_CONFIG_ALLOW_SYSTEM_LIBS=1
unset PKG_CONFIG_LIBDIR
unset PKG_CONFIG_SYSROOT_DIR
exec /usr/bin/pkg-config "$@"
WRAPPER_EOF
    chmod +x "$PKG_CONFIG_WRAPPER"

    # Set all PKG_CONFIG environment variables
    export PKG_CONFIG_PATH="/usr/lib/pkgconfig:/usr/share/pkgconfig:/usr/lib64/pkgconfig"
    export PKG_CONFIG_ALLOW_SYSTEM_CFLAGS=1
    export PKG_CONFIG_ALLOW_SYSTEM_LIBS=1
    unset PKG_CONFIG_LIBDIR
    unset PKG_CONFIG_SYSROOT_DIR

    # Set target-specific variables that Cargo's pkg-config crate looks for
    export PKG_CONFIG_PATH_x86_64_unknown_linux_gnu="$PKG_CONFIG_PATH"
    export PKG_CONFIG_PATH_x86_64-unknown-linux-gnu="$PKG_CONFIG_PATH"
    export HOST_PKG_CONFIG_PATH="$PKG_CONFIG_PATH"

    # Tell Cargo to use our wrapper instead of system pkg-config
    export PKG_CONFIG="$PKG_CONFIG_WRAPPER"

    echo "PKG_CONFIG_PATH for build: $PKG_CONFIG_PATH"
    echo "PKG_CONFIG wrapper: $PKG_CONFIG"

    # Verify gtk+-3.0 is findable before building
    if ! "$PKG_CONFIG_WRAPPER" --exists gtk+-3.0; then
        echo "ERROR: gtk+-3.0 still not found by pkg-config wrapper. Check installation."
        exit 1
    fi
    echo "gtk+-3.0 verification: $("$PKG_CONFIG_WRAPPER" --modversion gtk+-3.0)"
    echo "gtk+-3.0 cflags: $("$PKG_CONFIG_WRAPPER" --cflags gtk+-3.0 | head -c 100)..."

    # Run build with wrapper
    pnpm tauri build --bundles appimage 2>&1 || true

    # Cleanup wrapper
    rm -f "$PKG_CONFIG_WRAPPER"

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
