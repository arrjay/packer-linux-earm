#!/usr/bin/env bash

set -e

export DEBIAN_FRONTEND=noninteractive
export LANG=C
PFSRC=/tmp/packer-files

# just for comparison...
df -m

# load any environment things we need and export them
. /etc/environment
export $(awk -F= '{ print $1 }' < /etc/environment)

# recursion function for walking around in /tmp, installing to /etc
install_ef () {
  local s d
  while (( "$#" )) ; do
    s="${1}" ; shift
    [[ -e "${s}" ]] || continue
    [[ -d "${s}" ]] && { "${FUNCNAME[0]}" "${s}"/* ; continue ; }
    d="${s#/tmp}"
    install --verbose --mode="${INSTALL_MODE:-0644}" --owner=0 --group=0 -D "${s}" "/etc${d}"
  done
}

# install system configs from packer file provisioner
for source in \
  "${PFSRC}/etc/skel" \
  "${PFSRC}/systemd" \
  "${PFSRC}/untrustedhost" \
 ; do
  [[ -d "${source}" ]] && cp -R "${source}" /tmp
done

# install from scratch directories into filesystem, clean them back up
for directory in /tmp/systemd /tmp/untrustedhost ; do
  install_ef "${directory}"
  rm -rf "${directory}"
done

for directory in /tmp/skel ; do
  INSTALL_MODE=0755 install_ef "${directory}"
  rm -rf "${directory}"
done
