#!/usr/bin/env bash
set -e
source /usr/bin/common-functions.sh

runtime_dir="${XDG_RUNTIME_DIR:?}"
for _ in $(seq 1 180); do
    if [ -f /tmp/.started-desktop ] && [ -S "${runtime_dir}/${WAYLAND_DISPLAY:-wayland-0}" ]; then
        sleep 2
        [ -f /tmp/.started-desktop ] && [ -S "${runtime_dir}/${WAYLAND_DISPLAY:-wayland-0}" ] && break
    fi
    sleep 0.5
done
[ -S "${runtime_dir}/${WAYLAND_DISPLAY:-wayland-0}" ] || exit 11

export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
export XDG_CURRENT_DESKTOP=labwc
export XDG_SESSION_TYPE=wayland
# Steam's client still uses X11/CEF in this session. labwc's persistent
# Xwayland server is :0 unless it advertises another display.
for _ in $(seq 1 30); do
    x_socket="$(find /tmp/.X11-unix -maxdepth 1 -type s -name 'X[0-9]*' -printf '%f\n' 2>/dev/null | sort -V | tail -1 || true)"
    [ -n "$x_socket" ] && break
    sleep 1
done
# The inherited image may contain a stale DISPLAY such as :55. Prefer the
# Xwayland socket actually created by the current labwc session.
if [ -n "${x_socket:-}" ]; then
    export DISPLAY=":${x_socket#X}"
else
    export DISPLAY="${DISPLAY:-:0}"
fi
export DISPLAY="${DISPLAY:-:0}"
export_desktop_dbus_session
dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_RUNTIME_DIR 2>/dev/null || true

exec /usr/games/steam ${STEAM_ARGS:-}
