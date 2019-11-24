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

# also drop hypervisor-networkd on the box
curl -L -o /tmp/networkinst.run https://arrjay.gitlab.io/hypervisor-networkd/install.run
chmod +x /tmp/networkinst.run
/tmp/networkinst.run --ssl-pass-src file:/tmp/common/hypervisor-networkd
