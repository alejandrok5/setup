#!/usr/bin/env bash
# launch.sh — (re)start polybar under i3/Xorg.
#
# Run from i3 (exec_always). Kills any running bars, resolves the CPU
# temperature sensor, then starts one "main" bar per connected monitor.
set -u

CONFIG="$HOME/.config/polybar/config.ini"

# --- serialize concurrent invocations --------------------------------------
# postswitch (autorandr hotplug / rotate.sh / lid events) and i3's exec_always
# can fire launch.sh at nearly the same instant. If two runs both pass the
# "stop existing" step while no polybar is up yet, each then launches a full set
# of bars -> duplicate bars on every monitor. An exclusive lock makes a second
# run wait for the first to finish, then cleanly relaunch for the latest layout.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/polybar-launch.lock"
flock -w 10 9 || exit 0

# --- stop any running instances --------------------------------------------
polybar-msg cmd quit >/dev/null 2>&1 || killall -q polybar
# Wait until they're actually gone so the new ones bind the IPC sockets.
for _ in $(seq 1 20); do
  pgrep -u "$UID" -x polybar >/dev/null || break
  sleep 0.1
done

# --- resolve the CPU temperature sensor ------------------------------------
# hwmon numbers shuffle across reboots, so find k10temp (AMD) by name instead
# of hardcoding hwmonN. acpitz is unreliable on this machine, so prefer k10temp;
# fall back to thermal_zone0 only if k10temp is absent.
POLYBAR_CPU_TEMP_PATH=""
for h in /sys/class/hwmon/hwmon*; do
  [ -r "$h/name" ] || continue
  if [ "$(cat "$h/name")" = "k10temp" ]; then
    # temp1_input = Tctl on k10temp; first temp*_input is fine.
    for t in "$h"/temp*_input; do
      [ -r "$t" ] && { POLYBAR_CPU_TEMP_PATH="$t"; break; }
    done
    [ -n "$POLYBAR_CPU_TEMP_PATH" ] && break
  fi
done
[ -z "$POLYBAR_CPU_TEMP_PATH" ] && [ -r /sys/class/thermal/thermal_zone0/temp ] \
  && POLYBAR_CPU_TEMP_PATH="/sys/class/thermal/thermal_zone0/temp"
export POLYBAR_CPU_TEMP_PATH

# --- launch one bar per connected monitor ----------------------------------
if command -v xrandr >/dev/null 2>&1; then
  mapfile -t MONS < <(xrandr --query | awk '/ connected/{print $1}')
else
  MONS=()
fi

if [ "${#MONS[@]}" -gt 0 ]; then
  for m in "${MONS[@]}"; do
    MONITOR="$m" polybar --reload --config="$CONFIG" main >/dev/null 2>&1 &
  done
else
  polybar --reload --config="$CONFIG" main >/dev/null 2>&1 &
fi

echo "polybar launched (temp sensor: ${POLYBAR_CPU_TEMP_PATH:-none})"
