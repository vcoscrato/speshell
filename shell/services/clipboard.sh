#!/bin/sh
# cliphist for ClipboardService:
#   watch                  stores each copy, printing a line once it is stored
#   list COUNT             the newest COUNT entries
#   copy ID                copies entry ID back
#   thumbnails DIR NAME... keeps DIR to the image entries NAME, each "<id>.<extension>",
#                          decoding the missing ones, and prints the NAMEs it has

case $1 in
watch)
  exec wl-paste --watch "$0" store
  ;;
store)
  cliphist store && echo stored
  ;;
list)
  cliphist list | head -n "$2"
  ;;
copy)
  cliphist decode "$2" | wl-copy
  ;;
thumbnails)
  dir=$2
  shift 2
  mkdir -p "$dir" && chmod 700 "$dir" || exit 1
  for name; do
    [ -s "$dir/$name" ] || cliphist decode "${name%%.*}" >"$dir/$name" || rm -f "$dir/$name"
    [ -s "$dir/$name" ] && echo "$name"
  done
  for file in "$dir"/*; do
    [ -e "$file" ] || continue
    case " $* " in
      *" ${file##*/} "*) ;;
      *) rm -f "$file" ;;
    esac
  done
  ;;
*)
  exit 2
  ;;
esac
