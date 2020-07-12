#!/bin/sh

set -e

apt-get -qq -y install pi-bluetooth tmux augeas-tools lockfile-progs xmlstarlet ipcalc chrony isc-dhcp-server

# disable installed services for imd management
systemctl disable chrony
systemctl disable isc-dhcp-server
