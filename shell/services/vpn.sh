#!/bin/bash
# VpnService's work with NetworkManager, openconnect, and the secret store, where
# Speshell keeps a profile's secrets labelled "<name> VPN · <field>" under its uuid.
#
# vpn.sh prepare UUID
#   What connecting needs, as key=value lines: the profile's service type, data, and
#   user, and the user, auth group, password, and fields saved for it.
#
# vpn.sh openconnect UUID PROTOCOL GATEWAY USER AUTHGROUP FORM-ENTRY...
#   Logs in with openconnect and brings the profile up with the cookie it gets. The
#   first line of stdin is a typed password (empty: the saved one), and later lines
#   answer its prompts.
#
# vpn.sh nmcli UUID FRESH
#   Brings the profile up through nmcli with the saved secrets (none when FRESH is 1);
#   nmcli asks for anything they don't cover.
#
# vpn.sh store UUID NAME
#   Saves the field and value lines that stdin holds in pairs.

prepare() {
  local uuid=$1
  show() { nmcli -e no -g "$1" connection show uuid "$uuid" 2>/dev/null; }
  saved() { secret-tool lookup speshell-vpn "$uuid" field "$1" 2>/dev/null; }
  echo "service=$(show vpn.service-type)"
  echo "data=$(show vpn.data)"
  echo "user=$(show vpn.user-name)"
  echo "savedUser=$(saved user)"
  echo "savedAuthgroup=$(saved authgroup)"
  saved password >/dev/null && echo savedPassword=yes
  echo "savedFields=$(secret-tool search --all speshell-vpn "$uuid" 2>/dev/null | grep -c '^label = .* · .*\..*')"
}

openconnect_up() {
  exec 2>&1
  local uuid=$1 protocol=$2 gateway=$3 user=$4 group=$5 password login status feeder entry
  shift 5
  local args=(--protocol="$protocol")
  [ -z "$user" ] || args+=(--user="$user")
  [ -z "$group" ] || args+=(--authgroup="$group")
  for entry; do args+=(--form-entry="$entry"); done
  IFS= read -r password
  [ -n "$password" ] || password=$(secret-tool lookup speshell-vpn "$uuid" field password)
  exec 3< <(
    printf '%s\n' "$password"
    exec cat
  )
  feeder=$!
  login=$(openconnect --authenticate --non-inter --passwd-on-stdin "${args[@]}" "$gateway" <&3)
  status=$?
  exec 3<&-
  kill "$feeder" 2>/dev/null
  [ "$status" -eq 0 ] || exit 1
  # openconnect --authenticate prints KEY='value' lines, quoted for a shell; they are
  # read here, never run.
  local key value cookie='' host='' url='' fingerprint='' resolve=''
  while IFS='=' read -r key value; do
    value=${value#\'}
    value=${value%\'}
    value=${value//\'\\\'\'/\'}
    case "$key" in
      COOKIE) cookie=$value ;;
      HOST) host=$value ;;
      CONNECT_URL) url=$value ;;
      FINGERPRINT) fingerprint=$value ;;
      RESOLVE) resolve=$value ;;
    esac
  done <<<"$login"
  {
    printf 'vpn.secrets.cookie:%s\n' "$cookie"
    printf 'vpn.secrets.gateway:%s\n' "${url:-$host}"
    printf 'vpn.secrets.gwcert:%s\n' "$fingerprint"
    [ -z "$resolve" ] || printf 'vpn.secrets.resolve:%s\n' "$resolve"
  } | nmcli connection up uuid "$uuid" passwd-file /dev/stdin
}

nmcli_up() {
  local uuid=$1 saved=''
  # shellcheck disable=SC2016 # awk's own variables.
  [ "$2" = 1 ] || saved=$(secret-tool search --all speshell-vpn "$uuid" 2>/dev/null | awk '
    /^label = / { n = split($0, part, " · "); field = n > 1 ? part[n] : "" }
    /^secret = / && field ~ /\./ { print field ":" substr($0, 10) }')
  nmcli --ask connection up uuid "$uuid" passwd-file <(printf '%s\n' "$saved") 2>&1
}

store() {
  local uuid=$1 name=$2 field value
  while IFS= read -r field && IFS= read -r value; do
    printf '%s' "$value" | secret-tool store --label="$name VPN · $field" speshell-vpn "$uuid" field "$field"
  done
}

command=$1
shift
case "$command" in
  prepare) prepare "$@" ;;
  openconnect) openconnect_up "$@" ;;
  nmcli) nmcli_up "$@" ;;
  store) store "$@" ;;
  *) exit 2 ;;
esac
