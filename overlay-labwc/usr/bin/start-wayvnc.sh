#!/usr/bin/env bash

set -euo pipefail
source /usr/bin/common-functions.sh

runtime_dir="${XDG_RUNTIME_DIR:-/tmp/.X11-unix/run}"
export XDG_RUNTIME_DIR="${runtime_dir}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"

for _ in $(seq 1 180); do
    if [ -f /tmp/.started-desktop ] && [ -S "${runtime_dir}/${WAYLAND_DISPLAY}" ]; then
        sleep 2
        [ -f /tmp/.started-desktop ] && [ -S "${runtime_dir}/${WAYLAND_DISPLAY}" ] && break
    fi
    sleep 0.5
done
[ -S "${runtime_dir}/${WAYLAND_DISPLAY}" ] || { echo "FATAL: Wayland socket not available"; exit 11; }

password="${VNC_PASSWORD:-${USER_PASSWORD:-}}"
if [ -z "${password}" ]; then
    echo "FATAL: WEB_UI_MODE=vnc requires VNC_PASSWORD or USER_PASSWORD"
    exit 1
fi

config_dir="${USER_HOME:?}/.config/wayvnc"
mkdir -p "${config_dir}"
chmod 700 "${config_dir}"

if [ ! -s "${config_dir}/tls.key" ] || [ ! -s "${config_dir}/tls.crt" ]; then
    openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
        -subj "/CN=steam-headless-wayvnc" \
        -keyout "${config_dir}/tls.key" -out "${config_dir}/tls.crt" \
        >/dev/null 2>&1
    chmod 600 "${config_dir}/tls.key"
fi

cat >"${config_dir}/config" <<EOF
address=0.0.0.0
port=${VNC_PORT:-5900}
enable_auth=true
username=${VNC_USER:-default}
password=${password}
certificate_file=${config_dir}/tls.crt
private_key_file=${config_dir}/tls.key
EOF
chmod 600 "${config_dir}/config"

exec wayvnc --config="${config_dir}/config" --render-cursor
