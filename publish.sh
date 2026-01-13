#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DIST_DIR="$SCRIPT_DIR/dist"

# Run build first
echo "=== Running build ==="
"$SCRIPT_DIR/build.sh"

echo ""
echo "=== Publish to SteamDeck Sala ==="
echo "Do you want to publish to SteamDeck Sala? (y/n)"
read -r response

if [ "$response" != "y" ]; then
    echo "Publish cancelled."
    exit 0
fi

# Find the AppImage file
APPIMAGE=$(ls "$DIST_DIR"/Modrinth_App_*.AppImage 2>/dev/null | head -1)
if [ -z "$APPIMAGE" ]; then
    echo "ERROR: No AppImage found in $DIST_DIR"
    exit 1
fi

# Check Simple Profiles Manager binary
SPM_BINARY="$DIST_DIR/simple-profiles-manager"
if [ ! -f "$SPM_BINARY" ]; then
    echo "ERROR: simple-profiles-manager binary not found in $DIST_DIR"
    exit 1
fi

# SteamDeck IPs to try
STEAMDECK_IPS="192.168.1.239 192.168.1.86 192.168.1.146"
STEAMDECK_USER="deck"
REMOTE_DIR="~/Games/minecraft-modrinth"

# Try each IP until one works
CONNECTED_IP=""
for IP in $STEAMDECK_IPS; do
    echo "Trying to connect to $IP..."
    if ssh -o ConnectTimeout=5 -o BatchMode=yes "$STEAMDECK_USER@$IP" "echo connected" 2>/dev/null; then
        CONNECTED_IP="$IP"
        echo "Connected to $IP"
        break
    fi
done

if [ -z "$CONNECTED_IP" ]; then
    echo "ERROR: Could not connect to any SteamDeck IP"
    exit 1
fi

echo ""
echo "=== Copying files to SteamDeck ==="

# Create remote directory if it doesn't exist
ssh "$STEAMDECK_USER@$CONNECTED_IP" "mkdir -p $REMOTE_DIR"

# Copy AppImage with fixed name
echo "Copying AppImage..."
scp "$APPIMAGE" "$STEAMDECK_USER@$CONNECTED_IP:$REMOTE_DIR/Modrinth_App.AppImage"

# Copy Simple Profiles Manager
echo "Copying simple-profiles-manager..."
scp "$SPM_BINARY" "$STEAMDECK_USER@$CONNECTED_IP:$REMOTE_DIR/simple-profiles-manager"

# Set executable permissions
echo "Setting executable permissions..."
ssh "$STEAMDECK_USER@$CONNECTED_IP" "chmod +x $REMOTE_DIR/Modrinth_App.AppImage $REMOTE_DIR/simple-profiles-manager"

echo ""
echo "=== Publish completed successfully! ==="
echo "Files deployed to $STEAMDECK_USER@$CONNECTED_IP:$REMOTE_DIR"
ssh "$STEAMDECK_USER@$CONNECTED_IP" "ls -lh $REMOTE_DIR/"
