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
Name=em* eth* en*
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

# also drop hypervisor-networkd on the box
curl -L -o /tmp/networkinst.run https://arrjay.gitlab.io/hypervisor-networkd/install.run
chmod +x /tmp/networkinst.run
/tmp/networkinst.run --ssl-pass-src file:/tmp/common/hypervisor-networkd install || true

# configure the wireless interface
sed -e 's/^Name=.*/Name=wlan0/' < /etc/systemd/network/zz_default.network > /etc/systemd/network/wlan0.network
cp /tmp/common/wpa_supplicant-wlan0.conf /etc/wpa_supplicant
ln -s /lib/systemd/system/wpa_supplicant@.service /etc/systemd/system/multi-user.target.wants/wpa_supplicant@wlan0.service
ln -s /dev/null /etc/systemd/system/systemd-networkd-wait-online.service
