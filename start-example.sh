chmod u+x dist/simple-profiles-manager
chmod u+x dist/Modrinth_App_v0.10.24_amd64.AppImage

WEBKIT_DISABLE_DMABUF_RENDERER=1 GDK_BACKEND=x11 dist/simple-profiles-manager -a minecraft -t "Minecraft - Modrinth" -p dist/Modrinth_App_v0.10.24_amd64.AppImage -e MODRINTH_OFFLINE_USERNAME