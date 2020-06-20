#!/bin/sh

set -e

# rewire sources.list
cat <<_EOF_>/etc/apt/sources.list
deb http://hose.g.bbxn.us/apt/raspbian buster main contrib non-free rpi
# Uncomment line below then 'apt-get update' to enable 'apt-get source'
deb-src http://hose.g.bbxn.us/apt/raspbian buster main contrib non-free rpi
_EOF_

# HACK: I hate archive.rpi..
cat <<_EOF_>/etc/apt/sources.list.d/raspi.list
#deb http://archive.raspberrypi.org/debian/ buster main
deb http://hose.g.bbxn.us/apt/raspberrypi/debian/ buster main
# Uncomment line below then 'apt-get update' to enable 'apt-get source'
#deb-src http://archive.raspberrypi.org/debian/ buster main
_EOF_

apt-get -o APT::Sandbox::User=root update

apt-get -qq -y dist-upgrade
