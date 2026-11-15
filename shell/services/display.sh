#!/bin/bash
# Runs hyprctl once for each display's command, given as hyprctl's arguments with "--"
# between commands, and stops at the first one Hyprland refuses, printing its reason to
# stderr: hyprctl writes it to stdout.
set -eu
command=()
for arg in "$@" --; do
    if [ "$arg" != -- ]; then
        command+=("$arg")
        continue
    fi
    if [ ${#command[@]} -gt 0 ] && ! output=$(hyprctl "${command[@]}"); then
        printf '%s\n' "${output#error: }" >&2
        exit 1
    fi
    command=()
done
