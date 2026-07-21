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
    "${DISPLAY:?}" &
xorg_pid=$!

# The dummy driver rejects reduced-blanking modes during initial Xorg config
# parsing, but accepts them through RandR once the server is running.  Add and
# select the configured mode here so headless clients get the requested size
# and refresh rate (including modes such as 2560x1600@120).
if [ -f /etc/X11/xorg.conf ] \
    && grep -qE '^[[:space:]]*Driver[[:space:]]+"dummy"' /etc/X11/xorg.conf \
    && command -v cvt >/dev/null 2>&1 \
    && [ -n "${DISPLAY_SIZEW:-}" ] \
    && [ -n "${DISPLAY_SIZEH:-}" ] \
    && [ -n "${DISPLAY_REFRESH:-}" ]; then
    wait_for_x
    dummy_output=$(xrandr -q | awk '/ connected/ { print $1; exit }')

    # Populate the dummy output with useful display profiles so XFCE's
    # display settings and the streaming client can select both the common
    # resolutions and the requested refresh rates. These are added through
    # RandR after Xorg starts because the dummy driver's static config cannot
    # express every resolution/refresh-rate combination cleanly.
    profile_resolutions=(
        3840x2160 3440x1440 2560x1600 2560x1440 2560x1080
        1920x1200 1920x1080 1680x1050 1600x900 1280x800
        1280x720 1024x768 1024x576
    )
    profile_refresh_rates=(15 30 60 90 120 140 144 165)
    if [ -n "${dummy_output}" ]; then
        for profile_resolution in "${profile_resolutions[@]}"; do
            profile_width="${profile_resolution%x*}"
            profile_height="${profile_resolution#*x}"
            for profile_refresh in "${profile_refresh_rates[@]}"; do
                profile_modeline=$(cvt "${profile_width}" "${profile_height}" "${profile_refresh}" 2>/dev/null | sed -n 2p || true)
                profile_modeline="${profile_modeline#Modeline }"
                profile_mode_name=$(printf '%s\n' "${profile_modeline}" | awk -F '"' 'NF >= 2 { print $2 }')
                if [ -n "${profile_modeline}" ] && [ -n "${profile_mode_name}" ]; then
                    xrandr --newmode "${profile_mode_name}" ${profile_modeline##*\"} 2>/dev/null || true
                    xrandr --addmode "${dummy_output}" "${profile_mode_name}" 2>/dev/null || true
                fi
            done
        done
    fi

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
