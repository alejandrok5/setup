#!/usr/bin/env bash
#
# lock.sh — spinning-3D-avatar lock (ikz87 style).
#
# i3lock-color shows ~/.config/i3/lock-image.png (avatar on black) with a clock,
# date and password ring; picom renders the locker window through the 3D-camera
# shader (~/.config/picom/shaders/lock.glsl) — the centre avatar becomes a
# spinning sphere with CRT styling.
#
# The spin only animates while picom re-renders every frame, so we swap to an
# animated compositor (--no-use-damage) while locked and restore the normal,
# battery-friendly one on unlock. i3lock-color also forces a clock repaint
# (--force-clock) to keep damage flowing.
#
#   lock.sh            lock now
#   lock.sh --prepare  no-op (the lock image is pre-generated)
#
# Wired in i3: xss-lock target + the polybar powermenu "Lock". No sudo.
set -u

LOCKER="$HOME/.local/bin/i3lock-color"
IMAGE="$HOME/.config/i3/lock-image.png"
PICOM_CFG="$HOME/.config/picom.conf"
NAME="$(id -un)"

[ "${1:-}" = "--prepare" ] && exit 0
command -v "$LOCKER" >/dev/null 2>&1 || LOCKER="i3lock"   # fallback: plain i3lock

# Catppuccin macchiato (RRGGBBAA). The verify ring is MAUVE (not orange) — the
# shader tells "checking" (a full mauve ring) apart from "typing" (a small mauve
# key-highlight arc) by how much of the ring is mauve. Green is reserved for an
# actual unlock, applied by the shader on the window's destroy fade. No orange.
mauve=c6a0f6ff; red=ed8796ff; text=cad3f5ff; white=ffffffff; clear=00000000

animated_picom() { pkill -x picom 2>/dev/null; sleep 0.2; picom --config "$PICOM_CFG" --no-use-damage --daemon 2>/dev/null; sleep 0.3; }
normal_picom()   { pkill -x picom 2>/dev/null; sleep 0.2; picom --config "$PICOM_CFG" --daemon 2>/dev/null; }

# Multi-monitor: the orb shader assumes ONE screen (it centres the orb on the full
# i3lock window). With an external monitor i3lock spans both, so the orb lands
# between screens and i3lock draws a ring on each. Fix: while locked, switch every
# non-primary output OFF so the X screen is just the primary — orb, ring and image
# then work exactly as single-monitor, and the externals show nothing. Restore on
# unlock; a trap guarantees they come back even if i3lock is killed.
PRIMARY="$(xrandr --query 2>/dev/null | awk '/ connected primary/{print $1; exit}')"
EXTERNALS=()
disable_externals() {
  [ -n "$PRIMARY" ] || return 0          # no primary known: never risk blanking all outputs
  while read -r out; do
    [ "$out" = "$PRIMARY" ] || EXTERNALS+=("$out")
  done < <(xrandr --query 2>/dev/null | awk '/ connected/ && !/disconnected/{print $1}')
  for out in "${EXTERNALS[@]:-}"; do
    [ -n "$out" ] && xrandr --output "$out" --off 2>/dev/null
  done
}
restore_externals() {
  [ "${#EXTERNALS[@]}" -gt 0 ] || return 0
  autorandr --change --default horizontal 2>/dev/null \
    || for out in "${EXTERNALS[@]}"; do xrandr --output "$out" --auto 2>/dev/null; done
}
trap restore_externals EXIT

disable_externals
animated_picom

"$LOCKER" -n --image="$IMAGE" \
  --clock --force-clock \
  --time-str="%H:%M"      --time-size=40  --time-pos="w-120:h-90"     --time-color=$text    --time-font="MesloLGS Nerd Font" \
  --date-str="%a, %b %d"  --date-size=18  --date-pos="w-120:h-55"     --date-color=$text    --date-font="MesloLGS Nerd Font" \
  --greeter-text="$NAME"  --greeter-size=26 --greeter-pos="w/2:h/2+230" --greeter-color=$text --greeter-font="MesloLGS Nerd Font" \
  --indicator --radius=40 --ring-width=16 --ind-pos="w/2:h/2" \
  --inside-color=$clear      --ring-color=$white      --line-uses-ring \
  --insidever-color=$clear   --ringver-color=$mauve \
  --insidewrong-color=$clear --ringwrong-color=$red \
  --keyhl-color=$mauve --bshl-color=$mauve --separator-color=$clear \
  --verif-text="" --wrong-text="" --noinput-text="" --lock-text="" --no-modkey-text 2>/tmp/i3lock-dbg.log

# On unlock the lock window is destroyed; the animated compositor fades it out
# and the shader flashes the orb green during that fade. Give it a moment to
# play before swapping back to the normal compositor.
sleep 0.5
normal_picom
