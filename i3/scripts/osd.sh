#!/usr/bin/env bash
# GNOME-like OSD for volume / brightness / media on i3.
# Drives wpctl (PipeWire), brightnessctl and playerctl, and shows an
# on-screen progress bar via dunst (notify-send -h int:value:).
set -euo pipefail

SINK="@DEFAULT_AUDIO_SINK@"
SOURCE="@DEFAULT_AUDIO_SOURCE@"

# Stable notification IDs so popups replace each other (single GNOME-style OSD).
VOL_ID=4001
MIC_ID=4002
BRI_ID=4003

# notify $id $icon $summary $value(0-100, optional)
notify() {
    local id="$1" icon="$2" summary="$3" value="${4:-}"
    command -v notify-send >/dev/null || return 0   # OSD optional, never fatal
    if [ -n "$value" ]; then
        notify-send -a osd -u low -r "$id" -i "$icon" \
            -h "int:value:$value" -h "string:x-dunst-stack-tag:$id" "$summary" || true
    else
        notify-send -a osd -u low -r "$id" -i "$icon" \
            -h "string:x-dunst-stack-tag:$id" "$summary" || true
    fi
}

osd_volume() {
    local raw vol muted pct icon
    raw=$(wpctl get-volume "$SINK")          # e.g. "Volume: 0.55 [MUTED]"
    vol=$(printf '%s' "$raw" | awk '{print $2}')
    pct=$(awk -v v="$vol" 'BEGIN{printf "%d", v*100 + 0.5}')
    if printf '%s' "$raw" | grep -q MUTED; then
        notify "$VOL_ID" audio-volume-muted "Volume" 0
        return
    fi
    if   [ "$pct" -le 0 ];  then icon=audio-volume-muted
    elif [ "$pct" -le 33 ]; then icon=audio-volume-low
    elif [ "$pct" -le 66 ]; then icon=audio-volume-medium
    else                         icon=audio-volume-high
    fi
    notify "$VOL_ID" "$icon" "Volume" "$pct"
}

osd_mic() {
    local raw icon
    raw=$(wpctl get-volume "$SOURCE")
    if printf '%s' "$raw" | grep -q MUTED; then
        icon=microphone-sensitivity-muted
        notify "$MIC_ID" "$icon" "Microphone muted"
    else
        icon=microphone-sensitivity-high
        notify "$MIC_ID" "$icon" "Microphone on"
    fi
}

osd_brightness() {
    local pct icon
    pct=$(brightnessctl -m | awk -F, '{print $4}' | tr -d '%')
    if   [ "$pct" -le 33 ]; then icon=display-brightness-low
    elif [ "$pct" -le 66 ]; then icon=display-brightness-medium
    else                         icon=display-brightness-high
    fi
    notify "$BRI_ID" "$icon" "Brightness" "$pct"
}

case "${1:-}" in
    vol-up)     wpctl set-mute "$SINK" 0; wpctl set-volume -l 1.0 "$SINK" 5%+; osd_volume ;;
    vol-down)   wpctl set-volume "$SINK" 5%-; osd_volume ;;
    vol-mute)   wpctl set-mute "$SINK" toggle; osd_volume ;;
    mic-mute)   wpctl set-mute "$SOURCE" toggle; osd_mic ;;
    bri-up)     brightnessctl set 5%+; osd_brightness ;;
    bri-down)   brightnessctl set 5%-; osd_brightness ;;
    play)       playerctl play-pause ;;
    next)       playerctl next ;;
    prev)       playerctl previous ;;
    stop)       playerctl stop ;;
    *) echo "usage: osd.sh {vol-up|vol-down|vol-mute|mic-mute|bri-up|bri-down|play|next|prev|stop}" >&2; exit 1 ;;
esac
