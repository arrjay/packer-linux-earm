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

apt-get -o APT::Sandbox::User=root update

apt-get install tmux augeas-tools lockfile-progs xmlstarlet ipcalc chrony isc-dhcp-server \
  python-dbus python-setuptools mtools telnet incron networkd-dispatcher awscli \
  "${ADDITIONAL_PACKAGES[*]}"

# disable installed services for imd management
systemctl disable chrony
systemctl disable isc-dhcp-server

# allow dhcp, dns through the trusted zone in firewalld
firewall-offline-cmd --zone=trusted --add-service=dhcp
firewall-offline-cmd --zone=trusted --add-service=dns
