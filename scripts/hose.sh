#!/bin/sh

set -e

# install pijuice-base
apt-get install -qq -y pijuice-base

# configure ups drivers
cat <<_EOF_> /etc/nut/ups.conf
maxretry = 3

[a]
  driver = usbhid-ups
  port = auto
  serial = CR7FX2008290
  pollinterval = 2
  pollfreq = 15
[b]
  driver = usbhid-ups
  port = auto
  serial = QAJHS2000664
  pollinterval = 2
  pollfreq = 15
_EOF_

# set the hostname
printf '%s\n' 'hose' > /etc/hostname

# configure wifi
cp /tmp/hose/wpa_supplicant-wlan0.conf /etc/wpa_supplicant
ln -s /lib/systemd/system/wpa_supplicant@.service /etc/systemd/system/multi-user.target.wants/wpa_supplicant@wlan0.service
cat <<_EOF_>/etc/systemd/network/wlan0.network
# dhcp/ipv6 for wlan0
[Match]
Name=wlan0
[Network]
IPv6AcceptRA=yes
DHCP=yes
_EOF_

# enable the serial port
printf 'enable_uart=%s\n' '1' >> /boot/config.txt

# configure i2c clock overlay
printf 'dtoverlay=%s\n' 'i2c-rtc,ds1307' >> /boot/config.txt

# disable usb2(!) - it is problematic with usbserial
sed -i -e 's/dwc_otg.speed=[0-9]\+//' -e 's/$/ dwc_otg.speed=1/' /boot/cmdline.txt

# install dhcp service
apt-get install -qq -y isc-dhcp-server

