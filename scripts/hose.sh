#!/bin/bash

set -e

# install pijuice-base
apt-get install -qq -y pijuice-base

# install gpiozero
apt-get install -qq -y python3-gpiozero

# scripts to flip relays
groupadd relay
usermod -a -G relay ejusdem
usermod -a -G relay ssm-user

cat <<_EOF_> /usr/local/bin/bounce1
#!/usr/bin/env python3
from time import sleep
from gpiozero import DigitalOutputDevice
sw = DigitalOutputDevice("BCM5",active_high=False)
sw.on()
sleep(1)
_EOF_

cat <<_EOF_> /usr/local/bin/bounce2
#!/usr/bin/env python3
from time import sleep
from gpiozero import DigitalOutputDevice
sw = DigitalOutputDevice("BCM6",active_high=False)
sw.on()
sleep(1)
_EOF_

chown root:relay /usr/local/bin/bounce*
chmod 4750 /usr/local/bin/bounce*

ln -s /usr/local/bin/bounce1 /usr/local/bin/garagedoor

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

# configure ups monitoring
read -r upw < /root/upsd-pw

cat <<_EOF_> /etc/nut/upsmon.conf

# upsen to monitor
MONITOR a@localhost 1 root $upw master
MONITOR b@localhost 1 root $upw master

# we're using pijuice outside nut currently
MINSUPPLIES 0

SHUTDOWNCMD "/sbin/shutdown -h +0"

# shove _everything through upssched
NOTIFYCMD /sbin/upssched

POLLFREQ 3

POLLFREQALERT 3

HOSTSYNC 15

DEADTIME 10

POWERDOWNFLAG /etc/killpower

# only call upssched and let it handle the rest
NOTIFYFLAG ONLINE EXEC
NOTIFYFLAG ONBATT EXEC
NOTIFYFLAG LOWBATT EXEC
NOTIFYFLAG FSD EXEC
NOTIFYFLAG COMMOK EXEC
NOTIFYFLAG COMMBAD EXEC
NOTIFYFLAG SHUTDOWN EXEC
NOTIFYFLAG REPLBATT EXEC
NOTIFYFLAG NOCOMM EXEC
NOTIFYFLAG NOPARENT EXEC

RBWARNTIME 43200

NOCOMMWARNTIME 300

FINALDELAY 5
_EOF_

# detour to tmpfiles.d to make the /var/run/nut/upssched directory
cat <<_EOF_> /etc/tmpfiles.d/upssched.conf
D /run/nut/upssched 0700 nut nut - -
_EOF_

# sudo to allow upsdrvctl from nut
cat <<_EOF_ > /etc/sudoers.d/030_nut
nut ALL=(root) NOPASSWD: /sbin/upsdrvctl
_EOF_
chmod 0440 /etc/sudoers.d/030_nut

# upssched command script
cat <<_EOF_ > /usr/local/bin/upssched-cmd
#!/usr/bin/env bash

case \$1 in
        kick-ups-*)
		ups="\${1#kick-ups-}"
		sudo -u root /sbin/upsdrvctl stop \$ups
		sudo -u root /sbin/upsdrvctl start \$ups
		;;
	upsgone)
		logger -t upssched-cmd "The UPS has been gone for awhile"
		;;
	*)
		logger -t upssched-cmd "Unrecognized command: \$1"
		;;
esac
_EOF_
chown nut:nut /usr/local/bin/upssched-cmd
chmod 0500 /usr/local/bin/upssched-cmd

cat <<_EOF_> /etc/nut/upssched.conf
# hand this script...whatever
CMDSCRIPT /usr/local/bin/upssched-cmd

# locking
PIPEFN /run/nut/upssched/upssched.pipe
LOCKFN /run/nut/upssched/upssched.lock

# basically, we abuse upssched to restart the hid drivers should they peace out.
AT COMMBAD a@localhost EXECUTE kick-ups-a
AT NOCOMM a@localhost EXECUTE kick-ups-a
AT COMMBAD b@localhost EXECUTE kick-ups-b
AT NOCOMM b@localhost EXECUTE kick-ups-b
_EOF_

# set the hostname
printf '%s\n' 'hose' > /etc/hostname

# configure wifi
cp /tmp/hose/wpa_supplicant-wlan0.conf /etc/wpa_supplicant
ln -s /lib/systemd/system/wpa_supplicant@.service /etc/systemd/system/multi-user.target.wants/wpa_supplicant@wlan0.service
ln -s /dev/null etc/systemd/system/systemd-networkd-wait-online.service
cat <<_EOF_>/etc/systemd/network/wlan0.network
# dhcp/ipv6 for wlan0
[Match]
Name=wlan0
[Network]
IPv6AcceptRA=yes
DHCP=yes
_EOF_

# install pimd
apt-get install -qq -y lockfile-progs
mkdir -p /usr/lib/untrustedhost/s{cripts,hellib}
cp /tmp/pimd/imd.sh /usr/lib/untrustedhost/scripts
cp /tmp/pimd/*.bash /usr/lib/untrustedhost/shellib

# enable the serial port
printf 'enable_uart=%s\n' '1' >> /boot/config.txt

# configure i2c clock overlay
printf 'dtoverlay=%s\n' 'i2c-rtc,ds1307' >> /boot/config.txt

# configure networking flags
sed -i -e 's/$/ut_skip_br br_garage_ospf/' /boot/cmdline.txt

# install/configure dhcp service
apt-get install -qq -y isc-dhcp-server git

# install/configure chrony
apt-get install -qq -y chrony

# install/configure bind(!)
cat <<_EOF_>/etc/systemd/resolved.conf
[Resolve]
DNSStubListener=no
DNS=127.0.0.1
_EOF_

apt-get install -qq -y bind9
