#!/usr/bin/env bash

set -ex
PFSRC=/tmp/packer-files

# prereq - install mdns-publisher
pushd /usr/src
git clone --depth 1 --branch 0.9.2 https://github.com/carlosefr/mdns-publisher
cd mdns-publisher
python3 setup.py build
python3 setup.py install
popd

# install nut for ups fun...
type upsd >/dev/null 2>&1 || apt-get install nut
type upsc >/dev/null 2>&1 || apt-get install nut-client
apt-get install apg
systemctl disable nut-monitor
# nut-driver is masked due to alias startup issues. we use the nut-driver@ template instead.
systemctl mask nut-driver
systemctl disable nut-server
# the next bits are for nut 2.8.0, which did a target trick...
systemctl disable nut.target || true
systemctl disable nut-driver-enumerator || true

# configure that entire stack so that `upsd -V` works... :x
printf 'MODE=%s\n' 'netserver' > /etc/nut/nut.conf

# clone the nut sources for reference. or don't, if we have one.
nut_ver="$(upsd -V)"
nut_ver="${nut_ver##* }"
pushd /usr/src
nutdir=(nut*)
[[ -d "${nutdir[0]}" ]] || { git clone --depth 1 --branch "v${nut_ver}" https://github.com/networkupstools/nut ; nutdir=("nut") ; }
cd "${nutdir[0]}"
# the below script is an _additional udev hook_ to trip our own attach-hidups services
usbinfo="${PFSRC}/nut-usbinfo.pl"
TOP_SRCDIR=. TOP_BUILDDIR=. perl "${usbinfo}"
install -o 0 -g 0 -m 0644 scripts/udev/nut-usbups.rules.in /etc/udev/rules.d/attach-hidups.rules
popd

# ups.conf is the ups service drivers - dynamically generated
ln -sf /run/untrustedhost/nut/ups.conf /etc/nut/ups.conf

# upsd.users is wired in via xml or a local one-time generator.
ln -sf /run/untrustedhost/nut/upsd.users /etc/nut/upsd.users

# ditto upsmon.conf
ln -sf /run/untrustedhost/nut/upsmon.conf /etc/nut/upsmon.conf

# pi builds get nut added to the i2c group
case "${PACKER_BUILD_NAME}" in
  pi)
    usermod -a -G i2c nut
  ;;
esac

firewall-offline-cmd --zone=internal --add-service=nut

# upsd.conf is the network ups control plane
cat <<_EOF_> /etc/nut/upsd.conf
LISTEN 0.0.0.0 3493
LISTEN :: 3493
_EOF_
