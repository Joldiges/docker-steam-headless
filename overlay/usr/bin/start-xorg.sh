#!/usr/bin/env bash
###
# File: start-xorg.sh
# Project: bin
# File Created: Tuesday, 11th January 2022 8:28:52 pm
# Author: Josh.5 (jsunnex@gmail.com)
# -----
# Last Modified: Friday, 6th October 2022 9:21:00 pm
# Modified By: Josh.5 (jsunnex@gmail.com)
###
set -e
source /usr/bin/common-functions.sh

# CATCH TERM SIGNAL:
_term() {
    kill -TERM "$xorg_pid" 2>/dev/null
}
trap _term SIGTERM SIGINT


# EXECUTE PROCESS:
# Wait for udev
if [ $(grep autostart /etc/supervisor.d/udev.ini 2> /dev/null) == "autostart=true" ]; then
    wait_for_udev
fi
# Run X server
/usr/bin/Xorg \
    -ac \
    -noreset \
    -novtswitch \
    -sharevts \
    +extension RANDR \
    +extension RENDER \
    +extension GLX \
    +extension XVideo \
    +extension DOUBLE-BUFFER \
    +extension SECURITY \
    +extension DAMAGE \
    +extension X-Resource \
    -extension XINERAMA -xinerama \
    +extension Composite +extension COMPOSITE \
    -dpms \
    -s off \
    -nolisten tcp \
    -iglx \
    -verbose \
    vt7 "${DISPLAY:?}" &
xorg_pid=$!

# The dummy driver rejects reduced-blanking modes during initial Xorg config
# parsing, but accepts them through RandR once the server is running.  Add and
# select the configured mode here so headless clients get the requested size
# and refresh rate (including modes such as 2560x1600@120).
if [ "${FORCE_X11_DUMMY_CONFIG:-false}" = "true" ] \
    && command -v cvt >/dev/null 2>&1 \
    && [ -n "${DISPLAY_SIZEW:-}" ] \
    && [ -n "${DISPLAY_SIZEH:-}" ] \
    && [ -n "${DISPLAY_REFRESH:-}" ]; then
    wait_for_x
    dummy_output=$(xrandr -q | awk '/ connected/ { print $1; exit }')
    modeline=$(cvt -r "${DISPLAY_SIZEW}" "${DISPLAY_SIZEH}" "${DISPLAY_REFRESH}" 2>/dev/null | sed -n 2p || true)
    modeline="${modeline#Modeline }"
    mode_name=$(printf '%s\n' "${modeline}" | awk -F '"' 'NF >= 2 { print $2 }')
    if [ -n "${dummy_output}" ] && [ -n "${modeline}" ] && [ -n "${mode_name}" ]; then
        xrandr --newmode "${mode_name}" ${modeline##*\"} 2>/dev/null || true
        xrandr --addmode "${dummy_output}" "${mode_name}" 2>/dev/null || true
        xrandr --output "${dummy_output}" --primary --mode "${mode_name}" 2>/dev/null || true
    fi
fi


# WAIT FOR CHILD PROCESS:
wait "$xorg_pid"
