#!/bin/sh
# PowerService's work.
#
# system.sh version DIR
#   Speshell's version: the revision of the checkout at DIR, or the package's.
#
# system.sh relaunch PID QUICKSHELL-ARGS...
#   Waits for the Speshell running as PID to exit, then starts a new one: through
#   speshell.service when that runs it, else with the same Quickshell binary and the
#   arguments given.

version() {
  if command -v git >/dev/null 2>&1 && git -C "$1" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf 'r%s.g%s\n' "$(git -C "$1" rev-list --count HEAD)" "$(git -C "$1" rev-parse --short=7 HEAD)"
  elif package=$(pacman -Q speshell-git 2>/dev/null || pacman -Q speshell 2>/dev/null); then
    version=${package#* }
    printf '%s\n' "${version%-*}"
  else
    echo Unknown
  fi
}

relaunch() {
  pid=$1
  shift
  launcher=$(readlink -f "/proc/$pid/exe" 2>/dev/null || command -v quickshell || echo quickshell)
  while kill -0 "$pid" 2>/dev/null; do sleep 0.05; done
  sleep 0.1
  # This script runs in the unit's group, as Speshell's child, which the unit leaves be.
  if grep -q '/speshell\.service$' /proc/self/cgroup 2>/dev/null; then
    exec systemctl --user restart speshell.service
  fi
  exec "$launcher" --daemonize "$@"
}

command=$1
shift
case "$command" in
  version) version "$@" ;;
  relaunch) relaunch "$@" ;;
  *) exit 2 ;;
esac
