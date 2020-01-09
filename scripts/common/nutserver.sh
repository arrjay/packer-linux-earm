#!/usr/bin/env bash

set -e

# install nut for ups fun...
apt-get install -qq -y nut nut-monitor apg

# generate a new root password every time idk
upw=$(apg -M SNCL -m 21 -n 1)

# configure that entire stack
printf 'MODE=%s\n' 'netserver' > /etc/nut/nut.conf
# ups.conf is the ups service drivers

# upsd.conf is the network ups control plane
cat <<_EOF_> /etc/nut/upsd.conf
LISTEN 0.0.0.0 3493
LISTEN :: 3493
_EOF_

# upsd.users is for ~the children~ authentication
cat <<_EOF_> /etc/nut/upsd.users
[root]
  password = $upw
  actions = set fsd
  instcmds = all
  upsmon master

[upsmon]
  password = $UPS_UPSMON_PASSWORD
  upsmon slave
_EOF_

# save the root pw under /root as well
printf '%s\n' $upw > /root/upsd-pw

# a little systemd housekeeping
mkdir -p /etc/systemd/system/nut-{monitor,driver}.service.d
cat <<_EOF_> /etc/systemd/system/nut-monitor.service.d/10-dependency.conf
[Unit]
After=nut-driver.service
_EOF_

cat <<_EOF_> /etc/systemd/system/nut-driver.service.d/10-sleep.conf
[Service]
# give the ups drivers time to settle
ExecStartPost=/bin/sleep 1
_EOF_
