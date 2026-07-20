#!/usr/bin/env bash
###
# File: start-sunshine.sh
# Project: bin
# File Created: Tuesday, 4th October 2022 8:22:17 pm
# Author: Josh.5 (jsunnex@gmail.com)
# -----
# Last Modified: Wednesday, 27th November 2024 3:54:19 pm
# Modified By: Josh5 (jsunnex@gmail.com)
###
set -e
source /usr/bin/common-functions.sh

# CATCH TERM SIGNAL:
_term() {
    kill -INT "$sunshine_pid" 2>/dev/null
    sleep 0.5
    counter=0
    while kill -0 "$sunshine_pid"; do
        kill -TERM "$sunshine_pid" 2>/dev/null
        counter=$((counter + 1))
        [ "$counter" -gt 8 ] && break
        sleep 0.5
    done
    counter=0
    while kill -0 "$sunshine_pid"; do
        kill -KILL "$sunshine_pid" 2>/dev/null
        counter=$((counter + 1))
        [ "$counter" -gt 4 ] && break
        sleep 0.5
    done
}
trap _term SIGTERM SIGINT


# CONFIGURE:
# Install default configurations
mkdir -p "${USER_HOME:?}/.config/sunshine"
if [ ! -f "${USER_HOME:?}/.config/sunshine/sunshine.conf" ]; then
    cp -vf /templates/sunshine/sunshine.conf "${USER_HOME:?}/.config/sunshine/sunshine.conf"
fi
if [ ! -f "${USER_HOME:?}/.config/sunshine/apps.json" ]; then
    cp -vf /templates/sunshine/apps.json "${USER_HOME:?}/.config/sunshine/apps.json"
fi
if [ ! -f "${USER_HOME:?}/.config/sunshine/sunshine_state.json" ]; then
    echo "{}" > "${USER_HOME:?}/.config/sunshine/sunshine_state.json"
fi

# The primary display is a normal Xorg dummy screen.  Sunshine's automatic
# capture selection can prefer KMS when no physical output exists, so make
# X11 capture explicit while retaining environment overrides for advanced
# deployments.
set_sunshine_option() {
    local option="${1:?}"
    local value="${2:?}"
    local config="${USER_HOME:?}/.config/sunshine/sunshine.conf"
    if grep -qE "^[[:space:]]*${option}[[:space:]]*=" "${config}"; then
        sed -i -E "s|^[[:space:]]*${option}[[:space:]]*=.*$|${option} = ${value}|" "${config}"
    else
        printf '\n%s = %s\n' "${option}" "${value}" >> "${config}"
    fi
}

case "${SUNSHINE_CAPTURE:-x11}" in
    auto|'') ;;
    nvfbc|kms|wlr|kwin|x11)
        set_sunshine_option capture "${SUNSHINE_CAPTURE}"
        ;;
    *)
        echo "WARNING: ignoring unsupported SUNSHINE_CAPTURE='${SUNSHINE_CAPTURE}'"
        ;;
esac

if [ "${SUNSHINE_CAPTURE:-x11}" = "x11" ]; then
    # The dummy driver provides a complete X screen but not a physical RandR
    # monitor.  -1 tells Sunshine to capture the whole screen.
    set_sunshine_option output_name -1
fi

case "${SUNSHINE_ENCODER:-software}" in
    auto|'') ;;
    nvenc|quicksync|amdvce|vaapi|vulkan|software)
        set_sunshine_option encoder "${SUNSHINE_ENCODER}"
        ;;
    *)
        echo "WARNING: ignoring unsupported SUNSHINE_ENCODER='${SUNSHINE_ENCODER}'"
        ;;
esac

# Reset the default username/password
if ([ "X${SUNSHINE_USER:-}" != "X" ] && [ "X${SUNSHINE_PASS:-}" != "X" ]); then
    /usr/bin/sunshine "${USER_HOME:?}/.config/sunshine/sunshine.conf" --creds "${SUNSHINE_USER:?}" "${SUNSHINE_PASS:?}"
fi
# If we are running the SHUI, then force the same user upon sunshine
if ([ "X${WEBUI_USER:-}" != "X" ] && [ "X${WEBUI_PASS:-}" != "X" ]); then
    /usr/bin/sunshine "${USER_HOME:?}/.config/sunshine/sunshine.conf" --creds "${WEBUI_USER:?}" "${WEBUI_PASS:?}"
fi
# Remove any auto-start scripts from user's .local dir
if [ -f "${USER_HOME:?}/.config/autostart/Sunshine.desktop" ]; then
    rm -fv "${USER_HOME:?}/.config/autostart/Sunshine.desktop"
fi


# EXECUTE PROCESS:
# Wait for the X server to start
wait_for_x

# Start a session bus instance of dbus-daemon
wait_for_desktop_dbus_session
export_desktop_dbus_session

# Wait for the desktop to start
wait_for_desktop

# Start the sunshine server
/usr/bin/dumb-init /usr/bin/sunshine "${USER_HOME:?}/.config/sunshine/sunshine.conf" &
sunshine_pid=$!


# WAIT FOR CHILD PROCESS:
wait "$sunshine_pid"
