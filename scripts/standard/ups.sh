#!/usr/bin/env bash

set -e

# prereq - install mdns-publisher
pushd /usr/src
git clone https://github.com/carlosefr/mdns-publisher
cd mdns-publisher
python setup.py build
python setup.py install
popd

# install nut for ups fun...
apt-get install nut nut-monitor apg
systemctl disable nut-monitor
systemctl disable nut-driver
systemctl disable nut-server

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
