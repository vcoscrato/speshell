# shellcheck shell=bash
# Shared by Speshell's tools, which Speshell runs with its theme and [Tools]
# settings in SPESHELL_* variables (see services/ToolsService.qml). Run by hand,
# they fall back to plain defaults.

runtime_dir="${XDG_RUNTIME_DIR:-/tmp}/speshell"
mkdir -p "$runtime_dir"

# Prints the area the user drags out, as "X,Y WxH", or nothing when they cancel.
select_region() {
  slurp -b "${SPESHELL_SELECT_SHADE:-#00000066}" -c "${SPESHELL_SELECT_BORDER:-#ffffffff}" \
    -s "${SPESHELL_SELECT_FILL:-#ffffff22}" -B "${SPESHELL_SELECT_BOXES:-#ffffff22}" -w 2 2>/dev/null || true
}

# The focused monitor, for tools that take the whole screen: from Speshell, else
# from Hyprland when run by hand.
focused_output() {
  if [[ -n "${SPESHELL_OUTPUT:-}" ]]; then
    printf '%s' "$SPESHELL_OUTPUT"
  elif command -v hyprctl >/dev/null 2>&1; then
    hyprctl activeworkspace -j 2>/dev/null | sed -n 's/^ *"monitor": *"\([^"]*\)".*/\1/p'
  fi
}

# A toast through Speshell's notifications, kept out of their history. Each extra
# argument is an ID=LABEL action; it then waits and prints the one picked, if any.
notify() {
  local summary="$1" body="${2:-}" action
  shift 2 || shift $#
  local -a args=(-e -a Speshell)
  for action in "$@"; do
    args+=(-A "$action")
  done
  notify-send "${args[@]}" "$summary" "$body" 2>/dev/null || true
}

# The text cut to one short line, for a toast.
preview() {
  local text
  text="$(printf '%s' "$1" | tr -s '[:space:]' ' ')"
  ((${#text} <= 120)) && printf '%s' "$text" || printf '%s…' "${text:0:120}"
}

# Has Speshell probe the tools' processes now instead of on its next poll.
# Detached and delayed so it sees them as they are after the caller moves on.
refresh_activity() {
  command -v speshell >/dev/null 2>&1 || return 0
  setsid -f sh -c 'sleep 0.1; exec speshell activity refresh' >/dev/null 2>&1 || true
}

# A file in the user's XDG folder ($1, e.g. PICTURES) under $2, named $3 plus the time.
timestamped_file() {
  local base folder="${1,,}"
  base="$(xdg-user-dir "$1" 2>/dev/null || true)"
  [[ -n "$base" && "$base" != "$HOME" ]] || base="$HOME/${folder^}"
  mkdir -p "$base/$2"
  printf '%s/%s/%s_%s' "$base" "$2" "$3" "$(date +%Y-%m-%d_%H-%M-%S)"
}

# A toast that offers to open $3, a file or URL, with the desktop's default app.
notify_open() {
  if command -v xdg-open >/dev/null 2>&1; then
    if [[ "$(notify "$1" "$2" "open=Open")" == open ]]; then
      setsid -f xdg-open "$3" >/dev/null 2>&1 || true
    fi
  else
    notify "$1" "$2"
  fi
}
