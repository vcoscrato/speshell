#!/bin/sh
# usage: lab/paint.sh NAME OUT  Renders paintings/NAME.frag offscreen at
# WIDTH x HEIGHT (default 3840x2160) and saves it as OUT (.jpg or .png).
set -e
LAB=$(cd "$(dirname "$0")" && pwd)
FRAMES=$(mktemp -d)
trap 'rm -rf "$FRAMES"' EXIT
SCENE="$LAB/PaintingScene.qml" PAINTING="$LAB/../paintings/qsb/$1.qsb" DURATION=0.05 OUT="$FRAMES" \
    QT_FORCE_STDERR_LOGGING=1 timeout 60 quickshell --no-color -p "$LAB/shell.qml" 2>&1 \
    | grep -E "rror|WARN" | grep -v "window masks" >&2 || true
[ -f "$FRAMES/0001.bmp" ] || { echo "paint.sh: $1 did not render" >&2; exit 1; }
mkdir -p "$(dirname "$2")"
magick "$FRAMES/0001.bmp" -quality 92 "$2"
