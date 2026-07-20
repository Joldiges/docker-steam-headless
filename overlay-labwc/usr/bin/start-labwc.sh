#!/usr/bin/env bash
set -e
source /usr/bin/common-functions.sh

runtime_dir="${XDG_RUNTIME_DIR:-/tmp/.X11-unix/run}"
export XDG_RUNTIME_DIR="${runtime_dir}"
mkdir -p "${runtime_dir}"
chmod 700 "${runtime_dir}"

rm -f "${runtime_dir}/wayland-0" "${runtime_dir}/wayland-0.lock"
rm -f /tmp/.started-desktop

# labwc and Steam need a per-user D-Bus session even without a login manager.
rm -f /tmp/.dbus-desktop-session.env
export_desktop_dbus_session
export WAYLAND_DISPLAY=wayland-0
unset DISPLAY
export XDG_CURRENT_DESKTOP=labwc
export XDG_SESSION_TYPE=wayland
unset WLR_LIBINPUT_NO_DEVICES
dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_RUNTIME_DIR 2>/dev/null || true

mkdir -p "${HOME}/.config/waybar" "${HOME}/.config/labwc"
[ -f "${HOME}/.config/waybar/config.jsonc" ] || cp -f /templates/home_directory_template/.config/waybar/config.jsonc "${HOME}/.config/waybar/config.jsonc"
[ -f "${HOME}/.config/waybar/style.css" ] || cp -f /templates/home_directory_template/.config/waybar/style.css "${HOME}/.config/waybar/style.css"
[ -f "${HOME}/.config/labwc/menu.xml" ] || cp -f /templates/home_directory_template/.config/labwc/menu.xml "${HOME}/.config/labwc/menu.xml"

for _ in $(seq 1 30); do
    [ -S /run/seatd.sock ] && break
    sleep 0.2
done

labwc -d &
labwc_pid=$!

for _ in $(seq 1 60); do
    [ -S "${runtime_dir}/${WAYLAND_DISPLAY}" ] && break
    sleep 0.5
done

if [ ! -S "${runtime_dir}/${WAYLAND_DISPLAY}" ]; then
    echo "FATAL: labwc did not create ${runtime_dir}/${WAYLAND_DISPLAY}"
    exit 11
fi

# Configure the headless output before clients (especially Sunshine) inspect it.
# With the pixman renderer this is also the reliable point at which wlroots can
# allocate the requested buffer without a real DRM connector.
output="${DISPLAY_OUTPUT:-HEADLESS-1}"
mode="${DISPLAY_SIZEW:-2560}x${DISPLAY_SIZEH:-1600}@${DISPLAY_REFRESH:-120}Hz"
if ! wlr-randr --output "${output}" --custom-mode "${mode}" --on; then
    echo "WARNING: unable to apply headless mode ${mode} on ${output}; keeping compositor default"
fi
if [ -n "${DISPLAY_SCALE:-}" ]; then
    wlr-randr --output "${output}" --scale "${DISPLAY_SCALE}" || \
        echo "WARNING: unable to apply display scale ${DISPLAY_SCALE}"
fi

touch /tmp/.started-desktop

wait "${labwc_pid}"
