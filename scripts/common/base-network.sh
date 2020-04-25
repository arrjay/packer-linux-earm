#!/bin/sh

set -e

# shoot resolvconf
printf '\nresolvconf=%s\n' 'NO' >> /etc/resolvconf.conf

# replace networking
systemctl mask networking.service
rm -f /etc/network/interfaces
systemctl mask dhcpcd.service

# enable new stack inc. systemd-resolved
systemctl enable systemd-networkd.service
systemctl enable systemd-resolved.service

# handle the resolv.conf link like this so we don't break chroots
cat <<_EOF_ > /etc/systemd/system/resolvlink.service
[Unit]
Description=/etc/resolv.conf link mangler
Before=systemd-resolved.service
ConditionPathIsSymbolicLink=!/etc/resolv.conf
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
_EOF_

# drop a default wired config on the box
cat <<_EOF_ > /etc/systemd/network/zz_default.network
# fallback - try dhcp on it!
[Match]
Name=onboard onboard_wifi
[Network]
LinkLocalAddressing=yes
LLMNR=true
IPv6AcceptRA=yes
DHCP=yes
MulticastDNS=yes
LLDP=yes
EmitLLDP=yes
_EOF_

# disable ipv6 by default in interface bringup
augtool set /files/etc/sysctl.conf/net.ipv6.conf.default.disable_ipv6 1

# configure the wireless interface
cp /tmp/common/wpa_supplicant-onboard_wifi.conf /etc/wpa_supplicant
ln -s /lib/systemd/system/wpa_supplicant@.service /etc/systemd/system/multi-user.target.wants/wpa_supplicant@onboard_wifi.service
ln -s /dev/null /etc/systemd/system/systemd-networkd-wait-online.service

# install firewalld
# prereq - iptables backport
echo "deb http://deb.debian.org/debian buster-backports main" > /etc/apt/sources.list.d/backports.list
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 04EE7237B7D453EC 648ACFD622F3D138
apt-get -qq -y update
apt-get -t buster-backports -qq -y install iptables

apt-get install -qq -y firewalld
