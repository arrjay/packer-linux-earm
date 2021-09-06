#!/bin/sh

# run the original script
/usr/share/ucarp/vip-down "${@}"

# ask for a dhcpd
systemd-run systemctl stop untrustedhost-dhcpd
