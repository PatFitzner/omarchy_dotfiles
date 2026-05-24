#!/bin/bash
# Waybar module for monitor-hotplug service status
if systemctl --user is-active --quiet monitor-hotplug.service; then
  echo '{"text": "\udb80\udc54", "tooltip": "Monitor hotplug: ON\nClick to disable", "class": "on"}'
else
  echo '{"text": "\udb80\udc54", "tooltip": "Monitor hotplug: OFF\nClick to enable", "class": "off"}'
fi
