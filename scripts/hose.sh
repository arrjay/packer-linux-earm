#!/bin/sh

set -e

# install pijuice-base
apt-get install -qq -y pijuice-base

# install nut for ups fun...
# pijuice support is coming - see https://github.com/networkupstools/nut/pull/730
apt-get install -qq -y nut nut-monitor apg
printf 'MODE=%s\n' 'netserver' > /etc/nut/nut.conf

# configure that entire stack
# ups.conf is the ups service drivers
cat <<_EOF_> /etc/nut/ups.conf
maxretry = 3

[a]
  driver = usbhid-ups
  port = auto
  serial = CR7FX2008290
[b]
  driver = usbhid-ups
  port = auto
  serial = QAJHS2000664
_EOF_

# upsd.conf is the network ups control plane
cat <<_EOF_> /etc/nut/upsd.conf
LISTEN 0.0.0.0 3493
LISTEN :: 3493
_EOF_

# upsd.users is for ~the children~ authentication
cat <<_EOF_> /etc/nut/upsd.users
[root]
  password = $UPS_ROOT_PASSWORD
  actions = set fsd
  instcmds = all
  upsmon master

[upsmon]
  password = $UPS_UPSMON_PASSWORD
  upsmon slave
_EOF_

# self-monitoring (upsmon.conf) and scheduled commands (upssched.conf) tbd

# set the hostname
printf '%s\n' 'hose' > /etc/hostname

# enable the serial port
printf 'enable_uart=%s\n' '1' >> /boot/config.txt

# configure i2c clock overlay
printf 'dtoverlay=%s\n' 'i2c-rtc,ds1307' >> /boot/config.txt
