#!/usr/bin/env bash
set -e
source /usr/bin/common-functions.sh

_term() {
    kill -INT "${sunshine_pid:-}" 2>/dev/null || true
    sleep 0.5
    kill -TERM "${sunshine_pid:-}" 2>/dev/null || true
}
trap _term SIGTERM SIGINT

runtime_dir="${XDG_RUNTIME_DIR:-/tmp/.X11-unix/run}"
export XDG_RUNTIME_DIR="${runtime_dir}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"

for _ in $(seq 1 180); do
    if [ -f /tmp/.started-desktop ] && [ -S "${runtime_dir}/${WAYLAND_DISPLAY}" ]; then
        # labwc can briefly publish a socket while it is still recovering
        # from an initial compositor restart. Require a stable session.
        sleep 2
        [ -f /tmp/.started-desktop ] && [ -S "${runtime_dir}/${WAYLAND_DISPLAY}" ] && break
    fi
    sleep 0.5
done
[ -S "${runtime_dir}/${WAYLAND_DISPLAY}" ] || { echo "FATAL: Wayland socket not available"; exit 11; }

set_sunshine_option() {
    local key="$1" value="$2"
    [ -n "$value" ] || return 0
    if grep -q -E "^${key}[[:space:]]*=" "${USER_HOME}/.config/sunshine/sunshine.conf"; then
        sed -i -E "s|^${key}[[:space:]]*=.*$|${key} = ${value}|" \
            "${USER_HOME}/.config/sunshine/sunshine.conf"
    else
        printf '\n%s = %s\n' "${key}" "${value}" >> "${USER_HOME}/.config/sunshine/sunshine.conf"
    fi
}

mkdir -p "${USER_HOME:?}/.config/sunshine"
[ -f "${USER_HOME}/.config/sunshine/sunshine.conf" ] || cp -f /templates/sunshine/sunshine.conf "${USER_HOME}/.config/sunshine/sunshine.conf"
[ -f "${USER_HOME}/.config/sunshine/apps.json" ] || cp -f /templates/sunshine/apps.json "${USER_HOME}/.config/sunshine/apps.json"
[ -f "${USER_HOME}/.config/sunshine/sunshine_state.json" ] || echo '{}' > "${USER_HOME}/.config/sunshine/sunshine_state.json"

set_sunshine_option capture "${SUNSHINE_CAPTURE:-wlr}"
encoder="${SUNSHINE_ENCODER:-software}"
# Pixman is intentional for a DRM-less headless output. NVENC cannot import
# pixman buffers on this path; allow explicit hardware selection, but make the
# image's auto/default setting reliable instead of leaving Sunshine in 503 state.
[ "${encoder}" = auto ] && encoder=software
set_sunshine_option encoder "${encoder}"

if [ -n "${SUNSHINE_CSRF_ALLOWED_ORIGINS:-}" ]; then
    csrf_origins=""
    csrf_separator=""
    IFS=',' read -ra csrf_values <<< "${SUNSHINE_CSRF_ALLOWED_ORIGINS}"
    for csrf_origin in "${csrf_values[@]}"; do
        csrf_origin="${csrf_origin#${csrf_origin%%[![:space:]]*}}"
        csrf_origin="${csrf_origin%${csrf_origin##*[![:space:]]}}"
        [ -n "${csrf_origin}" ] || continue
        case "${csrf_origin}" in
            http://*|https://*) ;;
            *) csrf_origin="https://${csrf_origin}" ;;
        esac
        csrf_origins="${csrf_origins}${csrf_separator}${csrf_origin}"
        csrf_separator=','
    done
    [ -n "${csrf_origins}" ] && set_sunshine_option csrf_allowed_origins "${csrf_origins}"
fi

# The inherited app template contains an XFCE-only global preparation command.
# labwc has no XFCE session to minimize, so make preparation a harmless no-op.
sed -i -E 's|^global_prep_cmd[[:space:]]*=.*$|global_prep_cmd = [{"do":"true","undo":"/usr/bin/sunshine-stop"}]|' \
    "${USER_HOME}/.config/sunshine/sunshine.conf"

if [ -n "${SUNSHINE_USER:-}" ] && [ -n "${SUNSHINE_PASS:-}" ]; then
    sunshine "${USER_HOME}/.config/sunshine/sunshine.conf" --creds "${SUNSHINE_USER}" "${SUNSHINE_PASS}"
fi

export_desktop_dbus_session
unset DISPLAY
dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_RUNTIME_DIR 2>/dev/null || true

/usr/bin/dumb-init /usr/bin/sunshine "${USER_HOME}/.config/sunshine/sunshine.conf" &
sunshine_pid=$!
wait "${sunshine_pid}"
