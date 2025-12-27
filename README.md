# Modrinth Offline App

Build scripts for creating a patched version of the [Modrinth App](https://github.com/modrinth/code) with offline mode support, combined with [Simple Profiles Manager](https://github.com/MagiusCHE/simple-profiles-manager).

## Overview

This project combines two tools to enable offline mode gameplay with the Modrinth App:

1. **Simple Profiles Manager**: A profile management server that allows you to create, store, and select user profiles. When a profile is selected, it sets the `MODRINTH_OFFLINE_USERNAME` environment variable before launching a secondary application.

2. **Patched Modrinth App**: The official Modrinth App with a patch applied to read the `MODRINTH_OFFLINE_USERNAME` environment variable. When this variable is set, the app bypasses Microsoft authentication and uses offline credentials with the specified username.

## How It Works

1. Launch Simple Profiles Manager
2. Create or select a profile (username)
3. Simple Profiles Manager sets the `MODRINTH_OFFLINE_USERNAME` environment variable
4. Simple Profiles Manager launches the Modrinth App
5. The patched Modrinth App detects the environment variable and uses offline mode

This is useful for:
- Playing on offline-mode Minecraft servers
- Using custom authentication systems (like Drasl)
- Testing without requiring a Microsoft account

## The Patch

The patch (`tools/patch_01.patch`) modifies the Modrinth App to:

- Check for the `MODRINTH_OFFLINE_USERNAME` environment variable at runtime
- Generate a deterministic UUID from the username (matching Minecraft's offline UUID format)
- Create fake credentials that bypass the Microsoft authentication flow
- Set token expiry far in the future to prevent refresh attempts

## Building

### Prerequisites

- Git
- Rust and Cargo
- pnpm
- appimagetool (for creating AppImages on Linux)

### Build All

```bash
./build.sh
```

This script will:

1. Clone or update the Modrinth repository from https://github.com/modrinth/code
2. Clone or update Simple Profiles Manager from https://github.com/MagiusCHE/simple-profiles-manager
3. Apply the offline mode patch to Modrinth
4. Build the Modrinth AppImage
5. Build the Simple Profiles Manager binary

Built files will be placed in the `dist/` directory.

## Sources

- Modrinth App: https://github.com/modrinth/code
- Simple Profiles Manager: https://github.com/MagiusCHE/simple-profiles-manager

## License

See [LICENSE](LICENSE) for details.
