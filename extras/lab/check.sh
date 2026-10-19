#!/bin/sh
# usage: lab/check.sh EFFECT...  Renders each effect's scenes and checks their logs: no QML
# errors or warnings, and transitions that finish.
LAB=$(cd "$(dirname "$0")" && pwd)
LAB_OUT=${LAB_OUT:-${XDG_CACHE_HOME:-$HOME/.cache}/speshell-lab}
status=0
for effect in "$@"; do
    for scene in launcher wallpaper controls clock; do
        "$LAB/preview.sh" "$effect" "$scene" >/dev/null 2>&1
        log="$LAB_OUT/$effect-$scene.log"
        problems=$(grep -E "rror|WARN" "$log" | grep -v "window masks")
        if [ -n "$problems" ]; then
            printf 'FAIL %s %s:\n%s\n' "$effect" "$scene" "$problems"
            status=1
        elif [ "$scene" = launcher ] || [ "$scene" = wallpaper ]; then
            if grep -qE "closingFinished|transition finished" "$log"; then
                printf 'ok   %s %s, finished at %ss\n' "$effect" "$scene" \
                    "$(grep -oE '(closingFinished|finished) at [0-9.]+' "$log" | tail -1 | grep -oE '[0-9.]+$')"
            else
                printf 'FAIL %s %s: the transition never finished\n' "$effect" "$scene"
                status=1
            fi
        else
            printf 'ok   %s %s\n' "$effect" "$scene"
        fi
    done
done
exit $status
