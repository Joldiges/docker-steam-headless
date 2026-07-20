#!/usr/bin/env bash

set -u

log=/var/log/bolt-install.log

if flatpak info --system com.adamcake.Bolt >/dev/null 2>&1; then
    exit 0
fi

echo "Installing Bolt in the background..." >>"${log}"
flatpak install --system --noninteractive -y flathub com.adamcake.Bolt >>"${log}" 2>&1
status=$?
echo "Bolt installation exited with status ${status}" >>"${log}"
exit "${status}"
