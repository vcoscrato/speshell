#!/bin/sh
# The Wayland sessions the login screen offers: for each desktop entry, a "file<TAB>PATH"
# line, then the lines greeter.qml reads.
for f in /usr/share/wayland-sessions/*.desktop; do
  [ -f "$f" ] || continue
  printf 'file\t%s\n' "$f"
  grep -E '^(Name|Exec|DesktopNames|NoDisplay|Hidden)=' "$f"
done
