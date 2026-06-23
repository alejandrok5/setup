#!/usr/bin/env bash
#
# touchpad.sh — apply libinput touchpad preferences under i3/Xorg.
# Run from i3 via `exec_always` so it re-applies on every (re)start, and is
# safe to run by hand any time. Matches every touchpad by name, so it survives
# device-id changes and works on more than one touchpad.
#
# Settings (macOS-trackpad-like):
#   - Natural (inverted) scrolling.
#   - Tap-to-click on, with the default button map (1-finger = left,
#     2-finger tap = RIGHT click, 3-finger tap = middle).
#   - Click Method = clickfinger, so a 2-finger *physical* press is also a
#     RIGHT click (3-finger = middle). NOTE: this replaces button-areas, so
#     the bottom-right-corner press is no longer right-click — two fingers is.
#     Drop the clickfinger line below if you prefer corner right-click.

set -u

command -v xinput >/dev/null 2>&1 || exit 0

apply() {
  local id="$1"
  xinput set-prop "$id" "libinput Natural Scrolling Enabled" 1 2>/dev/null
  xinput set-prop "$id" "libinput Tapping Enabled" 1 2>/dev/null
  xinput set-prop "$id" "libinput Click Method Enabled" 0 1 2>/dev/null  # clickfinger
}

# Iterate every pointer device whose name looks like a touchpad.
xinput list --id-only 2>/dev/null | while read -r id; do
  name="$(xinput list --name-only "$id" 2>/dev/null)"
  case "$name" in
    *[Tt]ouchpad*) apply "$id" ;;
  esac
done
