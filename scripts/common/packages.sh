#!/bin/sh

set -e

apt-get -qq -y install pi-bluetooth tmux augeas-tools lockfile-progs xmlstarlet ipcalc chrony

# disable chrony
systemctl disable chrony

# drop makestep snippet
mkdir -p /etc/untrustedhost/chrony
printf 'makestep %s %s' '1' '-1' > /etc/untrustedhost/chrony/makestep.conf
