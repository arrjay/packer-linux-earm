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

apt-get update

# HACK: rpt6 (maybe 5?) Does Not Work with my AP.
curl -L -o /tmp/firmware-brcm80211.deb https://hose.g.bbxn.us/apt/raspberrypi/debian/pool/main/f/firmware-nonfree/firmware-brcm80211_20190114-1+rpt4_all.deb
dpkg -i /tmp/firmware-brcm80211.deb
apt-mark hold firmware-brcm80211
rm /tmp/firmware-brcm80211.deb

apt-get -qq -y dist-upgrade
