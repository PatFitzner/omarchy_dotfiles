#!/bin/bash
# Disable the laptop panel whenever any external monitor is connected;
# re-enable it when none are.
#
# A sleep is required before switching to let the NVIDIA driver finish
# initializing the new output — without it the GPU can crash.

LAPTOP="eDP-2"
LAPTOP_MODE="2560x1600@240,auto,1.25"

apply() {
  sleep 2
  if hyprctl monitors -j | jq -e '[.[] | select(.name != "'"$LAPTOP"'")] | length > 0' >/dev/null 2>&1; then
    hyprctl keyword monitor "$LAPTOP,disable"
  else
    hyprctl keyword monitor "$LAPTOP,$LAPTOP_MODE"
  fi
}

# Initial state on launch
apply

# React to hotplug events from Hyprland's IPC
socat -U - "UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" |
while read -r line; do
  case $line in
    monitoradded*|monitorremoved*) apply ;;
  esac
done
