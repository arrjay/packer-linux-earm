#!/usr/bin/env bash

set -ex

export DEBIAN_FRONTEND=noninteractive
export LANG=C
PFSRC=/tmp/packer-files

# recursion function for walking around in /tmp, installing to /etc
install_ef () {
  local s d
  while (( "$#" )) ; do
    s="${1}" ; shift
    [[ -e "${s}" ]] || continue
    [[ -d "${s}" ]] && { "${FUNCNAME[0]}" "${s}"/* ; continue ; }
    d="${s#/tmp}"
    install --verbose --mode="${INSTALL_MODE:-0644}" --owner=0 --group=0 -D "${s}" "${TARGET_DIR:-/etc}${d}"
  done
}

apt-get install ucarp

rm -f /etc/systemd/system/networking.service

for source in \
  "${PFSRC}/network" \
 ; do
  [[ -d "${source}" ]] && cp -R "${source}" /tmp
done

install_ef /tmp/network
