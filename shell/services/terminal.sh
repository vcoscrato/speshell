#!/bin/sh
# Runs a command in the user's terminal emulator: $TERMINAL, xdg-terminal-exec, or the
# first of the common ones installed; exits 127 without one. `terminal.sh --edit FILE`
# opens FILE in $VISUAL or $EDITOR there, or in the desktop's default application when
# there is no editor or terminal.

in_terminal() {
  if [ -n "${TERMINAL:-}" ] && command -v "${TERMINAL%% *}" >/dev/null 2>&1; then
    # shellcheck disable=SC2086 # $TERMINAL may carry its own arguments.
    exec $TERMINAL -e "$@"
  fi
  if command -v xdg-terminal-exec >/dev/null 2>&1; then
    exec xdg-terminal-exec "$@"
  fi
  for term in kitty foot ghostty alacritty wezterm konsole gnome-terminal xterm; do
    command -v "$term" >/dev/null 2>&1 || continue
    case "$term" in
      kitty | foot) exec "$term" "$@" ;;
      wezterm) exec wezterm start -- "$@" ;;
      gnome-terminal) exec gnome-terminal -- "$@" ;;
      *) exec "$term" -e "$@" ;;
    esac
  done
  # shellcheck disable=SC2016 # The variable's name, not its value.
  echo 'No terminal emulator found. Set $TERMINAL.' >&2
  return 127
}

if [ "${1:-}" = --edit ]; then
  SPESHELL_EDITOR=${VISUAL:-${EDITOR:-}}
  if [ -n "$SPESHELL_EDITOR" ]; then
    export SPESHELL_EDITOR
    # shellcheck disable=SC2016 # Expanded by the inner shell, editor arguments and all.
    in_terminal sh -c 'exec $SPESHELL_EDITOR "$1"' speshell-editor "$2"
  fi
  exec xdg-open "$2"
fi
in_terminal "$@"
