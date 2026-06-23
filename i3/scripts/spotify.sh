#!/usr/bin/env bash
#
# spotify.sh — open Spotify on workspace 10 and start playing.
# Bound to $mod+s in the i3 config. The `assign [class="Spotify"]` rule there
# pins the window to workspace 10, so this just switches there, launches Spotify
# if it isn't already running, then starts playback.
#
# Auto-play on a COLD start is best-effort: right after launch Spotify has no
# play context yet, so `playerctl play` can be a no-op. We wait for its MPRIS
# interface to appear, then send play a couple of times as it finishes loading.
set -u

WS=10

# Hop to the Spotify workspace (the i3 `assign` rule keeps the window here).
i3-msg "workspace number $WS" >/dev/null 2>&1

if pgrep -x spotify >/dev/null 2>&1; then
  # Already running — just make sure it's playing.
  playerctl --player=spotify play >/dev/null 2>&1
  exit 0
fi

# Cold start. Launch detached so it outlives this script.
setsid spotify >/dev/null 2>&1 &

# Wait up to ~20s for Spotify's MPRIS player to register, then start playback.
for _ in $(seq 1 40); do
  if playerctl --player=spotify status >/dev/null 2>&1; then
    playerctl --player=spotify play >/dev/null 2>&1
    sleep 1
    playerctl --player=spotify play >/dev/null 2>&1   # retry once it's fully loaded
    break
  fi
  sleep 0.5
done
