#!/bin/sh
# Prints Speshell's config and data directories, a line each, making them, and then
# config.ini, which starts as a copy of the example config ($1) on the first run.

example=$1
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/speshell"
data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/speshell"
ini="$config_dir/config.ini"

mkdir -p "$config_dir" "$data_dir" || exit 1
printf '%s\n%s\n' "$config_dir" "$data_dir"
# A link counts as there, so a dangling one is reported rather than replaced.
if [ ! -e "$ini" ] && [ ! -L "$ini" ]; then
  cp "$example" "$ini" 2>/dev/null
fi
if [ -e "$ini" ] || [ -L "$ini" ]; then
  exec cat "$ini"
fi
exec cat "$example"
