#!/bin/sh
# What FeatureSupport looks for:
#   commands NAME...  the NAMEs installed, a line each
#   backlights        the backlights, then "--", then the keyboard backlights
case $1 in
commands)
  shift
  for name; do
    command -v "$name" >/dev/null 2>&1 && echo "$name"
  done
  true
  ;;
backlights)
  for device in /sys/class/backlight/*; do
    [ -e "$device" ] && echo "${device##*/}"
  done
  echo --
  for device in /sys/class/leds/*kbd_backlight; do
    [ -e "$device" ] && echo "${device##*/}"
  done
  true
  ;;
*)
  exit 2
  ;;
esac
