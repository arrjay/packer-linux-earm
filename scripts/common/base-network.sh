#!/bin/sh

set -e

# configure the wireless interface
printf 'country=%s\n' 'us' >> /etc/wpa_supplicant/wpa_supplicant.conf
cp /tmp/common/wpa_supplicant-wl.conf /etc/wpa_supplicant
ln -s /lib/systemd/system/wpa_supplicant@.service /etc/systemd/system/multi-user.target.wants/wpa_supplicant@wl.service
