#!/usr/bin/env bash

### imd-specific shell bits

# builds on core
. /usr/lib/untrustedhost/shellib/core.bash

getaddrsv4() {
  local prefix
  prefix=$1
  local co="/etc/untrustedhost/netxml/${prefix}.xml"
  [[ -f "${co}" ]] || { err "missing ${co}" ; return 1 ; }
  local v4candidates=($(xmlstarlet sel -t -v 'address/@ipv4' "${co}"))
  local addr ; res=()
  for addr in "${v4candidates[@]}" ; do
    local net=''
    net="$(ipcalc "${addr}"|awk '$1 == "Network:" { print $2 }')"
    case "${net}" in
      */31) : ;;
      *)    err "non/31 ipv4 range supplied" ; exit 1 ;;
    esac
    [[ "${net}" == "${addr}" ]] && res=("${res[@]}" "${net}")
  done
  printf '%s\n' "${res[@]}"
}
