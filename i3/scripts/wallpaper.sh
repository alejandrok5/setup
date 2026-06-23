#!/usr/bin/env bash
#
# wallpaper.sh — set the desktop background under i3/Xorg.
# Run from i3 via `exec_always` so it re-applies on every (re)start, and is
# safe to run by hand any time. Uses feh, the standard lightweight i3 setter.
#
# --bg-fill scales the image to cover the whole screen (cropping overflow),
# which keeps it correct across monitor/resolution changes (dock/undock).
# To swap the wallpaper, just replace ~/.config/i3/wallpaper.jpg.

set -u

WALLPAPER="$HOME/.config/i3/wallpaper.jpg"

command -v feh >/dev/null 2>&1 || { echo "wallpaper.sh: feh not installed (sudo apt install feh)" >&2; exit 0; }
[ -f "$WALLPAPER" ] || { echo "wallpaper.sh: no wallpaper at $WALLPAPER" >&2; exit 0; }

feh --bg-fill "$WALLPAPER"
