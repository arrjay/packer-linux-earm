#!/bin/sh

# run the original script
/usr/share/ucarp/vip-up "${@}"

# ask for a dhcpd
systemd-run systemctl start untrustedhost-dhcpd
