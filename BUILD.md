# ALERT — Build location matters

**The AppImage MUST be built directly on the Steam Deck to work.**

Building on another machine (e.g. desktop Manjaro/Arch with newer glibc) and copying the AppImage to the Steam Deck **will not work**. The resulting AppImage links against a glibc version newer than the one shipped by SteamOS, and the app will crash at startup with no log output (only `Initialized tracing subscriber. Loading Modrinth App!` and `Initializing app...` reach the launcher log before the segfault).

## Why

- SteamOS glibc: 2.41
- Build machine glibc: 2.43 (or newer on rolling Arch-based distros)

webkit2gtk and its transitive dependencies compiled against glibc 2.43 use symbols absent in 2.41, causing an immediate segfault. Bundling webkit2gtk into the AppImage does **not** solve this — glibc itself cannot be safely bundled (it is tightly coupled with the dynamic loader and the kernel).

## How to build correctly

Build on the Steam Deck itself:

```bash
# from your dev machine, trigger the remote build:
pnpm run build:steamdeck:remote

# or, sshed into the Steam Deck:
cd /home/deck/Applications/modrinth-offline-app
git pull
./build-steamdeck.sh
```

`build-steamdeck.sh` handles SteamOS specifics: it disables `/usr` read-only, initializes the pacman keyring if needed, installs all required GTK / webkit2gtk-4.1 dev libraries, and reinstalls them after each SteamOS update (which strips them).

## When to use `build.sh` / `publish.sh`

Only for **local testing on your dev machine**. The AppImage they produce is not portable to the Steam Deck.
