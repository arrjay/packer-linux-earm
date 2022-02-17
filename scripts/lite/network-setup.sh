#!/usr/bin/env bash

set -e

export DEBIAN_FRONTEND=noninteractive
export LANG=C
PFSRC=/tmp/packer-files

# load any environment things we need and export them
. /etc/environment
export $(awk -F= '{ print $1 }' < /etc/environment)

# replace networking - parts of this are also accomplished from 0_init
#  moving files
[[ -e /etc/resolvconf.conf ]] && {
  sed -i -e '/^\(resolvconf=\).*/{s//\1NO/;:a;n;ba;q}' \
         -e '$aresolvconf=NO' \
   /etc/resolvconf.conf
}
systemctl mask networking.service
systemctl mask dhcpcd.service
rm -f /etc/network/interfaces
systemctl enable systemd-networkd.service
systemctl enable systemd-resolved.service
systemctl mask systemd-networkd-wait-online.service
systemctl enable ssh.service

# disable ipv6, install firewall bits
apt-get install augeas-tools iptables firewalld
augtool set /files/etc/sysctl.conf/net.ipv6.conf.default.disable_ipv6 1
