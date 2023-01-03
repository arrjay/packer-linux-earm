#!/usr/bin/env bash

set -e

case "${PACKER_BUILD_NAME}" in
  pi) ADDITIONAL_PACKAGES=(
        'pi-bluetooth' 'incron' 'ucarp' 'pijuice-base'
      )
   ;;
  *)  ADDITIONAL_PACKAGES=(
      )
   ;;
esac

apt-get -o APT::Sandbox::User=root update

apt-get install tmux augeas-tools lockfile-progs xmlstarlet ipcalc ntp ntpdate isc-dhcp-server \
  python3-dbus python3-setuptools mtools telnet networkd-dispatcher awscli putty-tools \
  modemmanager hostapd etherwake gpiod uptimed uhubctl tftpd-hpa \
  gawk bison libffi-dev libgdbm-dev libncurses5-dev libsqlite3-dev libtool libyaml-dev sqlite3 libgmp-dev \
  "${ADDITIONAL_PACKAGES[@]}"

# disable installed services for imd management
systemctl disable ntp
systemctl disable isc-dhcp-server
systemctl disable hostapd
systemctl disable tftpd-hpa

# allow dhcp, dns through the trusted zone in firewalld
firewall-offline-cmd --zone=trusted --add-service=dhcp
firewall-offline-cmd --zone=trusted --add-service=dns
firewall-offline-cmd --zone=trusted --add-service=tftp
