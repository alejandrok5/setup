#!/usr/bin/env bash
#
# rotate.sh — rotate ONE output and re-tile ALL active outputs in a left-to-right
# row so nothing overlaps, then re-apply wallpaper + polybar for the new geometry.
# Installed to ~/.config/i3/scripts/rotate.sh by displays/install.sh.
#
# Why re-tile everything (not just the rotated output): rotating changes an
# output's width/height. If we only repositioned the rotated one, a THIRD
# monitor could fall outside the resized framebuffer and get collapsed onto
# another output's coordinates — the two screens then "mirror" each other.
# Re-laying out every active output in a stable order avoids that.
#
# Usage: rotate.sh <output|auto> <normal|left|right|inverted>
set -eu

TARGET="${1:?usage: rotate.sh <output|auto> <normal|left|right|inverted>}"
DIR="${2:?usage: rotate.sh <output|auto> <normal|left|right|inverted>}"

PRIMARY="$(xrandr --query | awk '/ connected primary/ {print $1; exit}')"

# Resolve "auto" -> first connected non-primary output (the external).
if [ "$TARGET" = "auto" ]; then
  TARGET="$(xrandr --query | awk '/ connected/ && !/ primary/ {print $1; exit}')"
  [ -n "$TARGET" ] || TARGET="$PRIMARY"
fi

# Active outputs (those with a +x+y geometry), in current left-to-right order.
mapfile -t ORDER < <(
  xrandr --query | awk '
    / connected/ {
      name=$1; x=""
      for (i=1;i<=NF;i++) if ($i ~ /^[0-9]+x[0-9]+\+[-0-9]+\+[-0-9]+$/) { split($i,a,"+"); x=a[2]+0 }
      if (x!="") print x"\t"name      # only currently-active outputs
    }' | sort -n | cut -f2
)

# Current rotation of an output (normal|left|right|inverted). The rotation, when
# not normal, is the token immediately BEFORE the "(normal left inverted ...)"
# capability list; that list itself must be ignored.
cur_rot() {
  xrandr --query | awk -v o="$1" '
    $1==o {
      for (i=1;i<=NF;i++) if ($i ~ /^\(/) {
        p=$(i-1)
        if (p=="left"||p=="right"||p=="inverted") print p; else print "normal"
        exit
      }
      print "normal"
    }'
}

# Build a single xrandr call: leftmost at 0x0, each next --right-of the previous.
# Target gets the requested rotation; everything else keeps its own.
args=(); prev=""
for o in "${ORDER[@]}"; do
  [ "$o" = "$TARGET" ] && rot="$DIR" || rot="$(cur_rot "$o")"
  if [ -z "$prev" ]; then
    args+=(--output "$o" --auto --rotate "$rot" --pos 0x0)
  else
    args+=(--output "$o" --auto --rotate "$rot" --right-of "$prev")
  fi
  [ "$o" = "$PRIMARY" ] && args+=(--primary)
  prev="$o"
done

xrandr "${args[@]}"

# Re-paint wallpaper + re-place bars for the new geometry.
exec "$HOME/.config/autorandr/postswitch"
