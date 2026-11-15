#!/bin/sh
# Prepares the notes folder ($1): empties its trash ($3), which only holds a deleted
# note until its undo runs out, and starts the scratchpad ($2) when there is no note.
set -eu

notes_dir=$1 scratchpad=$2 trash_dir=$3
umask 077
mkdir -p -- "$notes_dir" "$trash_dir"
for discarded in "$trash_dir"/*.txt "$trash_dir"/.*.txt; do
  if [ -f "$discarded" ]; then rm -f -- "$discarded"; fi
done
for note in "$notes_dir"/*.txt "$notes_dir"/.*.txt; do
  if [ -f "$note" ]; then exit 0; fi
done
: >"$scratchpad"
