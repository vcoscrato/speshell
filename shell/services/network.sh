#!/bin/bash
# network.sh join SSID KIND
#   Joins the Wi-Fi network SSID as a new profile of its own; KIND is open or the
#   key management (wpa-psk, sae, ...), and the first line of stdin holds the
#   password of a wpa-psk or sae network. A profile that fails to connect is deleted.
exec 2>&1

join() {
  local ssid=$1 kind=$2 uuid psk
  uuid=$(cat /proc/sys/kernel/random/uuid)
  set -- type wifi con-name "$ssid" connection.uuid "$uuid" ssid "$ssid"
  [ "$kind" = open ] || set -- "$@" wifi-sec.key-mgmt "$kind"
  nmcli connection add "$@" >/dev/null || exit 1
  if [ "$kind" = wpa-psk ] || [ "$kind" = sae ]; then
    IFS= read -r psk
    printf 'set 802-11-wireless-security.psk %s\nsave persistent\nquit\n' "$psk" \
      | nmcli connection edit uuid "$uuid" >/dev/null
  fi
  nmcli -w 45 connection up uuid "$uuid" && exit 0
  nmcli connection delete uuid "$uuid" >/dev/null
  exit 1
}

case "$1" in
  join) join "$2" "$3" ;;
  *) exit 2 ;;
esac
