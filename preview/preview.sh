#!/bin/sh
# usage: preview/preview.sh EFFECT SCENE  (SCENE: launcher | wallpaper | controls | picks | clock)
# Renders offscreen into ~/.cache/speshell-preview/EFFECT-SCENE.mp4 and EFFECT-SCENE-strip.png, and prints
# the transition's lifecycle log. Env: CLOSE_AT, REOPEN_AT, SWITCH_AT, SWITCH_AGAIN_AT, SPEED, WALL_A, WALL_B, THEME_INI,
# SPESHELL_DIR, KEEP_FRAMES=1 to keep the frames in ~/.cache/speshell-preview/EFFECT-SCENE/ (about 700 MB per run), and
# EVERY_FRAME=1 to capture at 60 fps instead of 30.
set -e
SCENES=$(cd "$(dirname "$0")/scenes" && pwd)
PREVIEW_OUT=${PREVIEW_OUT:-${XDG_CACHE_HOME:-$HOME/.cache}/speshell-preview}
EFFECT=$1
SCENE=${2:-launcher}
NAME="$EFFECT-$SCENE"
OUT="$PREVIEW_OUT/$NAME"
SAMPLES="$PREVIEW_OUT/samples"

# Stand-in wallpapers: procedural, so no artwork lives in the repository.
if [ ! -f "$SAMPLES/a.jpg" ]; then
    mkdir -p "$SAMPLES"
    for spec in "a 11 #34507c #101828" "b 23 #d9b98a #4d6f6a"; do
        # shellcheck disable=SC2086 # the spec's words are the arguments
        set -- $spec
        magick -size 1920x1080 gradient:"$3-$4" \( -size 480x270 -seed "$2" plasma:fractal -colorspace gray \
            -auto-level -resize 1920x1080! -blur 0x24 +level 30%,70% \) -compose overlay -composite "$SAMPLES/$1.jpg"
    done
fi
WALL_A=${WALL_A:-$SAMPLES/a.jpg}
WALL_B=${WALL_B:-$SAMPLES/b.jpg}
# Speshell itself, from this checkout by default.
export SPESHELL_DIR="${SPESHELL_DIR:-$(cd "$SCENES/../../shell" && pwd)}"
# The palette: the theme of the same name unless THEME_INI names another theme.ini.
THEME_INI=${THEME_INI:-$SPESHELL_DIR/themes/$EFFECT/theme.ini}

case "$SCENE" in
    launcher) END=$(awk -v c="${CLOSE_AT:-2.2}" -v r="${REOPEN_AT:-0}" -v k="${SPEED:-1}" 'BEGIN { k = k > 0 ? k : 1; print (r > c ? r + 1.6 / k : c + 1.2 / k) }'); CROP="crop=1100:760:410:20," ;;
    wallpaper) END=$(awk -v s="${SWITCH_AT:-0.3}" -v a="${SWITCH_AGAIN_AT:-0}" -v k="${SPEED:-1}" 'BEGIN { k = k > 0 ? k : 1; print (a > s ? a : s) + 2.8 / k }'); CROP="scale=1280:720," ;;
    controls) END=$(awk -v k="${SPEED:-1}" 'BEGIN { k = k > 0 ? k : 1; print 4.4 + 0.6 / k }'); CROP="crop=452:452:0:0,scale=904:904," ;;
    picks) END=$(awk -v k="${SPEED:-1}" 'BEGIN { k = k > 0 ? k : 1; print 3.0 + 0.9 / k }'); CROP="crop=452:332:0:0,scale=904:664," ;;
    clock) END=4.2; CROP="crop=740:480:0:0," ;;
    *) echo "unknown scene: $SCENE" >&2; exit 2 ;;
esac

rm -rf "$OUT" && mkdir -p "$OUT"
LOG="$PREVIEW_OUT/$NAME.log"
EFFECTS_DIR="$SPESHELL_DIR/effects/$EFFECT" SCENE="$SCENES/$(echo "$SCENE" | sed 's/./\U&/')Scene.qml" \
    DURATION="$END" OUT="$OUT" EVERY_FRAME="${EVERY_FRAME:-}" THEME_INI="$THEME_INI" SPEED="${SPEED:-1}" WALL_A="$WALL_A" WALL_B="$WALL_B" \
    SWITCH_AGAIN_AT="${SWITCH_AGAIN_AT:-}" \
    QT_FORCE_STDERR_LOGGING=1 timeout 90 quickshell --no-color -p "$SCENES/shell.qml" >"$LOG" 2>&1 || true
grep -E "closingFinished|transition|ERROR|rror:|WARN" "$LOG" | grep -v "window masks" || true

FPS=$([ -n "${EVERY_FRAME:-}" ] && echo 60 || echo 30)
ffmpeg -loglevel error -y -framerate "$FPS" -i "$OUT/%04d.bmp" -vf "${CROP}format=yuv420p" \
    -c:v libx264 -crf 18 "$PREVIEW_OUT/$NAME.mp4"
# Contact strip at fixed moments (seconds) of each scene.
case "$SCENE" in
    launcher) TIMES="0.25 0.5 1.2 $(awk -v c="${CLOSE_AT:-2.2}" 'BEGIN { print c + 0.15, c + 0.35 }')"
        TILE="-crop 1100x760+410+20 +repage -resize 30%" ;;
    wallpaper) TIMES=$(awk -v s="${SWITCH_AT:-0.3}" -v k="${SPEED:-1}" 'BEGIN { k = k > 0 ? k : 1; print s + 0.3 / k, s + 0.6 / k, s + 1 / k, s + 1.4 / k, s + 1.9 / k }')
        TILE="-resize 18%" ;;
    controls) TIMES="0.6 1.0 1.25 1.6 2.15 2.45 2.95 3.45 4.05 4.45"
        TILE="-crop 452x452+0+0 +repage" ;;
    picks) TIMES="0.33 0.37 0.42 0.5 0.6 0.75 0.95"
        TILE="-crop 260x150+70+16 +repage -scale 200%" ;;
    clock) TIMES="0.5 1.5 3.5"
        TILE="-crop 740x480+0+0 +repage" ;;
esac
set --
for t in $TIMES; do
    set -- "$@" "$(printf '%s/%04d.bmp' "$OUT" "$(awk -v t="$t" -v f="$FPS" 'BEGIN { print int(t * f + 0.5) }')")"
done
# shellcheck disable=SC2086 # TILE is a list of options
magick "$@" $TILE +append "$PREVIEW_OUT/$NAME-strip.png"
[ -n "${KEEP_FRAMES:-}" ] || rm -rf "$OUT"
echo "$PREVIEW_OUT/$NAME.mp4"
