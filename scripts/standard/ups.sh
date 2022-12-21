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

# HACK: currently we hardwire firewalld and interface interop to this.
firewall-offline-cmd --new-zone=hv
firewall-offline-cmd --zone=hv --add-interface=be-vl-hv
firewall-offline-cmd --zone=hv --add-service=nut
firewall-offline-cmd --new-zone=ninf
firewall-offline-cmd --zone=ninf --add-interface=be-vl-ninf
firewall-offline-cmd --zone=ninf --add-service=nut
firewall-offline-cmd --zone=trusted --add-service=nut

# copy the services from public to here as well.
for service in $(firewall-offline-cmd --list-services --zone=public) ; do
  firewall-offline-cmd --zone=hv   --add-service="${service}"
  firewall-offline-cmd --zone=ninf --add-service="${service}"
done

# upsd.conf is the network ups control plane
cat <<_EOF_> /etc/nut/upsd.conf
LISTEN 0.0.0.0 3493
LISTEN :: 3493
_EOF_
