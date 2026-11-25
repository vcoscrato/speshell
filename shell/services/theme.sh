#!/bin/sh
# ThemeService's file work.
#
# theme.sh scan THEMES... -- EFFECTS...
#   For each themes folder, a "theme<TAB>DIR" line for each theme in it, followed by
#   its theme.ini as "ini<TAB>LINE" lines, and a "wall<TAB>PATH" line for each image
#   under it; for each effects folder, an "effects<TAB>DIR" line for each effect in it.
#
# theme.sh palette PATH JSON MODE
#   Writes JSON to PATH unless it holds it already, sets GNOME's color scheme to MODE
#   (light or dark), and has matugen render it into the app themes when it is set up.

scan() {
  while [ "$#" -gt 0 ] && [ "$1" != -- ]; do
    dir=$1
    shift
    [ -d "$dir" ] || continue
    for ini in "$dir"/*/theme.ini; do
      [ -f "$ini" ] || continue
      printf 'theme\t%s\n' "${ini%/theme.ini}"
      awk '{ print "ini\t" $0 }' "$ini"
    done
    find -L "$dir" -mindepth 2 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
      -printf 'wall\t%p\n'
  done
  [ "$#" -gt 0 ] && shift
  for dir; do
    [ -d "$dir" ] || continue
    for effects in "$dir"/*/Effects.qml; do
      [ -f "$effects" ] && printf 'effects\t%s\n' "${effects%/Effects.qml}"
    done
  done
  true
}

palette() {
  path=$1 text=$2 mode=$3
  [ "$(cat "$path" 2>/dev/null)" = "$text" ] && exit 0
  mkdir -p "${path%/*}" && printf '%s\n' "$text" >"$path.next" || exit 1
  if command -v gsettings >/dev/null; then
    gsettings set org.gnome.desktop.interface color-scheme "prefer-$mode"
  fi
  if [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/matugen/config.toml" ] && command -v matugen >/dev/null; then
    matugen json "$path.next" -m "$mode" -q || {
      rm -f "$path.next"
      exit 1
    }
  fi
  mv "$path.next" "$path"
}

command=$1
shift
case "$command" in
  scan) scan "$@" ;;
  palette) palette "$@" ;;
  *) exit 2 ;;
esac
