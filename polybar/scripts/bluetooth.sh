#!/usr/bin/env bash
# bluetooth.sh — polybar status (and click-to-toggle) for Bluetooth via bluetoothctl.
#
#   no args     print a single status field for the polybar module
#   --toggle    power Bluetooth on/off (bound to click-left)
set -u

ICON=""        # powered, no device connected
ICON_CONN=""  # a device is connected
ICON_OFF=""    # powered off (shown dimmed)

# Catppuccin macchiato colors (kept here so the script is self-contained).
C_ON="#8aadf4"        # blue
C_CONNECTED="#a6da95" # green
C_OFF="#6e738d"       # overlay0

command -v bluetoothctl >/dev/null 2>&1 || { echo ""; exit 0; }

powered() { bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; }

if [ "${1:-}" = "--toggle" ]; then
  if powered; then bluetoothctl power off >/dev/null 2>&1
  else bluetoothctl power on >/dev/null 2>&1; fi
  exit 0
fi

if ! powered; then
  echo "%{F$C_OFF}$ICON_OFF%{F-}"
  exit 0
fi

# Count connected devices; show the first device's name if any are connected.
connected=$(bluetoothctl devices Connected 2>/dev/null)
if [ -n "$connected" ]; then
  name=$(echo "$connected" | head -1 | cut -d" " -f3-)
  echo "%{F$C_CONNECTED}$ICON_CONN%{F-} ${name}"
else
  echo "%{F$C_ON}$ICON%{F-}"
fi
