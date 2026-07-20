#!/usr/bin/env bash

print_header "Configure labwc headless Wayland session"

# Flatpak sandbox namespaces are unavailable during image builds in some
# container engines, so install Bolt when the privileged runtime starts.
if ! flatpak info --system com.adamcake.Bolt >/dev/null 2>&1; then
    flatpak install --system --noninteractive -y flathub com.adamcake.Bolt \
        || echo "WARNING: Bolt installation failed; it can be retried after startup"
fi

# Xwayland refuses to use the shared X socket directory without the sticky bit.
mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix

# The inherited image is Xfce/Xorg-based. Disable those services and replace
# them with a single wlroots headless compositor.
sed -i 's|^autostart.*=.*$|autostart=false|' /etc/supervisor.d/desktop.ini
sed -i 's|^autostart.*=.*$|autostart=false|' /etc/supervisor.d/xorg.ini
# The base image's Xorg init script can re-enable its supervisor entry for a
# primary container. Keep the service inert in this Wayland image.
sed -i 's|^autostart.*=.*$|autostart=false|' /etc/supervisor.d/xorg.ini
sed -i 's|^autorestart.*=.*$|autorestart=false|' /etc/supervisor.d/xorg.ini
sed -i 's|^command=.*$|command=/bin/false|' /etc/supervisor.d/xorg.ini
grep -q '^disabled=' /etc/supervisor.d/xorg.ini \
    && sed -i 's|^disabled=.*$|disabled=true|' /etc/supervisor.d/xorg.ini \
    || sed -i '/^autostart=/a disabled=true' /etc/supervisor.d/xorg.ini

if [ "${MODE}" != "secondary" ] && [ "${ENABLE_SUNSHINE:-}" = "true" ]; then
    sed -i 's|^autostart.*=.*$|autostart=true|' /etc/supervisor.d/labwc.ini
    sed -i 's|^autostart.*=.*$|autostart=true|' /etc/supervisor.d/sunshine.ini
else
    sed -i 's|^autostart.*=.*$|autostart=false|' /etc/supervisor.d/labwc.ini
    sed -i 's|^autostart.*=.*$|autostart=false|' /etc/supervisor.d/sunshine.ini
fi

if [ "${ENABLE_STEAM:-true}" = "true" ]; then
    sed -i 's|^autostart.*=.*$|autostart=true|' /etc/supervisor.d/steam.ini
else
    sed -i 's|^autostart.*=.*$|autostart=false|' /etc/supervisor.d/steam.ini
fi

# Sunshine must wait for the Wayland socket, not for Xorg.
sed -i 's|^command=.*start-sunshine.*$|command=/usr/bin/start-sunshine-labwc.sh|' /etc/supervisor.d/sunshine.ini
sed -i 's|DISPLAY="%(ENV_DISPLAY)s",XDG_RUNTIME_DIR="%(ENV_XDG_RUNTIME_DIR)s"|DISPLAY="",WAYLAND_DISPLAY="wayland-0",XDG_CURRENT_DESKTOP="labwc",XDG_SESSION_TYPE="wayland",XDG_RUNTIME_DIR="%(ENV_XDG_RUNTIME_DIR)s"|' /etc/supervisor.d/sunshine.ini

echo -e "\e[34mDONE\e[0m"
