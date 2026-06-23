#!/usr/bin/env bash
# powermenu.sh — rofi power menu for the polybar powermenu module.
#
# No sudo: systemctl poweroff/reboot/suspend go through logind for the active
# session; lock uses ~/.config/i3/scripts/lock.sh (blurred-wallpaper i3lock);
# logout exits the i3 session.
set -u

lock="  Lock"
logout="  Logout"
suspend="  Suspend"
reboot="  Reboot"
shutdown="  Shutdown"

chosen=$(printf '%s\n' "$lock" "$suspend" "$logout" "$reboot" "$shutdown" \
  | rofi -dmenu -i -p "Power" -theme-str 'window {width: 15%;} listview {lines: 5;}')

case "$chosen" in
  "$lock")     ~/.config/i3/scripts/lock.sh ;;
  "$suspend")  systemctl suspend ;;
  "$logout")   i3-msg exit ;;
  "$reboot")   systemctl reboot ;;
  "$shutdown") systemctl poweroff ;;
esac
