#!/usr/bin/env bash

set -e

case "${PACKER_BUILD_NAME}" in
  pi) ADDITIONAL_PACKAGES=(
        'pi-bluetooth'
      )
   ;;
  *)  ADDITIONAL_PACKAGES=(
      )
   ;;
esac

apt-get install tmux augeas-tools lockfile-progs xmlstarlet ipcalc chrony isc-dhcp-server python-dbus python-setuptools "${ADDITIONAL_PACKAGES[*]}"

# disable installed services for imd management
systemctl disable chrony
systemctl disable isc-dhcp-server
