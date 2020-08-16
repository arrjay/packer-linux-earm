#!/usr/bin/env bash

set -e
PFSRC=/tmp/packer-files

# prereq - install mdns-publisher
pushd /usr/src
git clone --depth 1 --branch 0.9.2 https://github.com/carlosefr/mdns-publisher
cd mdns-publisher
python setup.py build
python setup.py install
popd

# install nut for ups fun...
apt-get install nut nut-monitor apg
systemctl disable nut-monitor
systemctl disable nut-driver
systemctl disable nut-server

# clone the nut sources for reference
nut_ver=$(upsd -V)
nut_ver="${nut_ver##* }"
pushd /usr/src
git clone --depth 1 --branch v2.7.4 https://github.com/networkupstools/nut
cd nut
TOP_SRCDIR=. TOP_BUILDDIR=. perl "${PFSRC}/nut-usbinfo.pl"
install -o 0 -g 0 -m 0644 scripts/udev/nut-usbups.rules.in /etc/udev/rules.d/attach-hidups.rules
popd

# configure that entire stack
printf 'MODE=%s\n' 'netserver' > /etc/nut/nut.conf

# ups.conf is the ups service drivers - dynamically generated
ln -sf /run/untrustedhost/nut/ups.conf /etc/nut/ups.conf

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
