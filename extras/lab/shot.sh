#!/bin/sh
# usage: lab/shot.sh THEME [SHOT...]  (SHOT: a panel id, `launcher`, or `bar`; none: every
# panel this machine has, and the launcher)
# Renders the real bar offscreen in THEME, with each panel open in turn, into
# ~/.cache/speshell-lab/shots/THEME/<shot>.png, cropped to the panel, and a contact
# sheet of them all in THEME-sheet.png. Uses your config.ini (SHOT_CONFIG names another)
# with a fresh data directory, so your theme, notes, and app themes stay untouched.
# SHOT_QUERY is typed into the launcher; SHOT_MEDIA=1 shows the playing track, hidden
# by default since its cover is someone else's art; SHOT_SAMPLES=1 fills the
# notifications with made-up ones.
set -e
LAB=$(cd "$(dirname "$0")" && pwd)
LAB_OUT=${LAB_OUT:-${XDG_CACHE_HOME:-$HOME/.cache}/speshell-lab}
THEME=${1:-cosmos}
[ $# -gt 0 ] && shift
SPESHELL_DIR=${SPESHELL_DIR:-$(cd "$LAB/../.." && pwd)}
SHOT_CONFIG=${SHOT_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/speshell/config.ini}
WORK="$LAB_OUT/shot"
OUT="$LAB_OUT/shots/$THEME"

# Quickshell imports only from the shell's own directory, and resolves the shipped
# themes beside it, so the shot runs from a copy of the tree with the scene at its root.
rm -rf "$WORK" "$OUT" && mkdir -p "$WORK/tree" "$WORK/config/speshell" "$WORK/data/speshell" "$WORK/bin" "$OUT/full"
tar -C "$SPESHELL_DIR" --exclude=.git -cf - . | tar -C "$WORK/tree" -xf -
cp "$LAB/shot/ShotShell.qml" "$WORK/tree/shot.qml"
# The bar's window is never mapped, so its dropdowns and effects are told they show.
for binding in "shown: root.visible" "presented: root.visible"; do
    grep -q "$binding" "$WORK/tree/bar/Bar.qml" || { echo "shot.sh: Bar.qml no longer has '$binding'" >&2; exit 1; }
done
sed -i -e "s/shown: root.visible/shown: true/" -e "s/presented: root.visible/presented: true/" "$WORK/tree/bar/Bar.qml"
[ -f "$SHOT_CONFIG" ] && cp "$SHOT_CONFIG" "$WORK/config/speshell/config.ini"
printf '{"theme":"%s"}\n' "$THEME" > "$WORK/data/speshell/theme.json"
# A theme change sets the desktop's light or dark; keep it from reaching the session.
printf '#!/bin/sh\nexit 0\n' > "$WORK/bin/gsettings" && chmod +x "$WORK/bin/gsettings"

LOG="$WORK/shot.log"
PATH="$WORK/bin:$PATH" XDG_CONFIG_HOME="$WORK/config" XDG_DATA_HOME="$WORK/data" THEME="$THEME" SHOTS="$*" SHOT_QUERY="${SHOT_QUERY:-}" SHOT_MEDIA="${SHOT_MEDIA:-}" SHOT_SAMPLES="${SHOT_SAMPLES:-}" \
    OUT="$OUT/full" QT_FORCE_STDERR_LOGGING=1 timeout 120 quickshell --no-color -p "$WORK/tree/shot.qml" >"$LOG" 2>&1 || true
grep -E "WARN|ERROR|rror:" "$LOG" | grep -vE "window masks|Registration|notification|quickshell.dbus" || true

grep -o 'crop [a-z]* [0-9]* [0-9]* [0-9]* [0-9]*' "$LOG" | while read -r _ name x y w h; do
    magick "$OUT/full/$name.png" -crop "${w}x${h}+${x}+${y}" +repage "$OUT/$name.png"
done
ls "$OUT"/*.png >/dev/null 2>&1 || { echo "shot.sh: nothing rendered; see $LOG" >&2; exit 1; }
# The bar across the top, then the panels side by side, aligned at the top.
magick "$OUT/bar.png" -crop 1920x60+0+0 +repage "$WORK/bar-strip.png"
magick montage -label '%t' $(ls "$OUT"/*.png | grep -v '/bar.png$') -tile 8x -geometry +8+8 \
    -gravity north -background '#101010' -fill '#c0c0c0' "$WORK/panels.png"
magick "$WORK/bar-strip.png" "$WORK/panels.png" -background '#101010' -gravity west -append +repage "$LAB_OUT/shots/$THEME-sheet.png"
echo "$LAB_OUT/shots/$THEME-sheet.png"
