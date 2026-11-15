#!/bin/sh
# Hyprland's monitors, workspaces, and clients, as JSON each, with a record separator
# (\036) between them.
hyprctl -j monitors
printf '\036'
hyprctl -j workspaces
printf '\036'
hyprctl -j clients
