#!/usr/bin/env bash

print_header "Configure labwc headless Wayland session"

# The base image uses a shared D-Bus session file under /tmp.  Its first
# version can be created by root, but labwc/Steam/Sunshine run as the desktop
# user and must be able to replace it on every compositor restart.
rm -f /tmp/.dbus-desktop-session.env
install -o "${PUID:-1000}" -g "${PGID:-1000}" -m 600 /dev/null /tmp/.dbus-desktop-session.env

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

# The inherited image's X11 VNC service cannot capture this Wayland desktop.
# Use the optional wayvnc service below instead.
for service in vnc.ini vnc-audio.ini; do
    if [ -f "/etc/supervisor.d/${service}" ]; then
        sed -i 's|^autostart=.*$|autostart=false|' "/etc/supervisor.d/${service}"
        sed -i 's|^autorestart=.*$|autorestart=false|' "/etc/supervisor.d/${service}"
    fi
done

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

if [ "${WEB_UI_MODE:-none}" = "vnc" ]; then
    sed -i 's|^autostart=.*$|autostart=true|' /etc/supervisor.d/wayvnc.ini
else
    sed -i 's|^autostart=.*$|autostart=false|' /etc/supervisor.d/wayvnc.ini
fi

echo -e "\e[34mDONE\e[0m"
