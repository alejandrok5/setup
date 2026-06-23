#!/usr/bin/env bash
#
# install.sh — (re)install the multi-monitor / hotplug / rotation / lid setup.
#
# Rebuilds everything in README "External monitors": the autorandr hotplug + lid
# fallbacks (system, sudo), the postswitch hook and rotate.sh (user), the picom
# full-repaint fix, and checks the i3 rotate-mode binding + polybar lock.
# Idempotent — safe to re-run.
#
# EDID-matched profiles (mobile / extend-* / dock-*) are machine-specific and are
# NOT installed here — save them per displays-cheatsheet.md after running this.
#
# Usage:  ~/setup/displays/install.sh
# The system steps use sudo and will prompt for your password.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; }

echo "== display setup: user scripts =="

# 1) User scripts (no sudo) -------------------------------------------------
install -Dm755 "$HERE/postswitch" "$HOME/.config/autorandr/postswitch"
ok "autorandr postswitch  -> ~/.config/autorandr/postswitch"
install -Dm755 "$HERE/rotate.sh"  "$HOME/.config/i3/scripts/rotate.sh"
ok "rotate.sh             -> ~/.config/i3/scripts/rotate.sh"

# 2) picom: full-frame repaints (use-damage = false) ------------------------
# Without this the glx backend leaves the wallpaper "cut"/stale on a rotated
# output. libconfig errors on a DUPLICATE key, so only add the line if absent.
PICOM="$HOME/.config/picom.conf"
if [ -f "$PICOM" ]; then
  if grep -qE '^[[:space:]]*use-damage' "$PICOM"; then
    if grep -qE '^[[:space:]]*use-damage[[:space:]]*=[[:space:]]*false' "$PICOM"; then
      ok "picom use-damage = false (already set)"
    else
      warn "picom 'use-damage' is set to non-false — change it to false in $PICOM"
    fi
  else
    {
      printf '\n# Full-frame repaints: fixes the wallpaper being left "cut"/stale on a\n'
      printf '# rotated output with the glx backend (added by displays/install.sh).\n'
      printf 'use-damage = false;\n'
    } >> "$PICOM"
    ok "picom use-damage = false (appended to picom.conf)"
  fi
else
  warn "no ~/.config/picom.conf — install picom (setup.txt) then re-run"
fi

# 3) System hotplug + lid fallbacks (sudo) ----------------------------------
# The shipped autorandr units fall back to '--default default' (a profile that
# does not exist), so a monitor with no saved profile stayed blank and the lid
# never turned off eDP. Swap the fallback to the built-in 'horizontal'.
echo "== display setup: system fallbacks (sudo) =="
sudo install -Dm644 "$HERE/systemd/autorandr.service.d/override.conf" \
     /etc/systemd/system/autorandr.service.d/override.conf
ok "hotplug fallback  -> /etc/systemd/system/autorandr.service.d/override.conf"
sudo install -Dm644 "$HERE/systemd/autorandr-lid-listener.service.d/override.conf" \
     /etc/systemd/system/autorandr-lid-listener.service.d/override.conf
ok "lid fallback      -> /etc/systemd/system/autorandr-lid-listener.service.d/override.conf"
sudo systemctl daemon-reload
sudo systemctl restart autorandr-lid-listener.service
ok "systemd reloaded + lid-listener restarted"

# 4) Hand-maintained config checks ------------------------------------------
echo "== checks =="
I3="$HOME/.config/i3/config"
if [ -f "$I3" ] && grep -q 'mode "rotate"' "$I3"; then
  ok "i3 rotate mode (\$mod+o) present"
else
  warn "i3 rotate mode missing — paste displays/i3-rotate-mode.conf into ~/.config/i3/config, then reload i3"
fi

LAUNCH="$HOME/.config/polybar/launch.sh"
if [ -f "$LAUNCH" ] && grep -q 'flock' "$LAUNCH"; then
  ok "polybar launch.sh has the flock (no duplicate bars on rapid switches)"
else
  warn "polybar launch.sh has no flock — concurrent switches can spawn duplicate bars (see README 'External monitors')"
fi

for unit in autorandr autorandr-lid-listener; do
  val="$(systemctl show "$unit" -p ExecStart --value 2>/dev/null | grep -o -- '--default [a-z]*' || true)"
  [ "$val" = "--default horizontal" ] && ok "$unit fallback: $val" || warn "$unit fallback: ${val:-unknown}"
done

cat <<'EOF'

Done. Next:
  • Save EDID profiles for your setups (see displays-cheatsheet.md), e.g.:
      autorandr --save mobile                       # laptop only
      arandr -> arrange -> autorandr --save dual-extend
      (lid shut) autorandr --save dock-1            # clamshell
  • Reload i3 to pick up the rotate binding:  $mod+Shift+r
EOF
