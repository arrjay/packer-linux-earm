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

# walk a list of cgroup:tos field mappings
ct=0
for kv in "/system.slice/netdata.service:0x30" "/system.slice/isc-dhcp-server.service:0x38" "/system.slice/bind9.service:0x38" "/system.slice/chrony.service:0x38" ; do
  k="${kv%:*}"
  v="${kv#*:}"
  firewall-offline-cmd --direct --add-rule ipv4 mangle OUTPUT_direct "${ct}" -m cgroup --path "${k}" -j TOS --set-tos "${v}"
  firewall-offline-cmd --direct --add-rule ipv4 mangle INPUT_direct  "${ct}" -m cgroup --path "${k}" -j TOS --set-tos "${v}"
  ((ct++)) || true
done

# install pimd
apt-get install -qq -y lockfile-progs xmlstarlet ipcalc
mkdir -p /usr/lib/untrustedhost/{imd,scripts,shellib,tmpfiles-factory}
cp /tmp/pimd/imd.sh /tmp/pimd/veth-network /usr/lib/untrustedhost/scripts
cp /tmp/pimd/*.bash /usr/lib/untrustedhost/shellib
cp /tmp/pimd/zz_* /usr/lib/untrustedhost/imd
cp /tmp/pimd/anycast-prefixes.conf /usr/lib/untrustedhost/tmpfiles-factory
cp /tmp/pimd/anycast-healthchecker.conf /etc/tmpfiles.d/anycast-healthchecker.conf
cp /tmp/pimd/imd.service /etc/systemd/system
ln -s /etc/systemd/system/imd.service /etc/systemd/system/multi-user.target.wants/imd.service

# install/configure bird from/with pimd bits
apt-get install -qq -y bird
cp /tmp/pimd/bird.conf /etc/bird/bird.conf
mkdir -p /etc/systemd/system/bird.service.d
cp /tmp/pimd/10-create-interface-cfg.conf /etc/systemd/system/bird.service.d

# enable the serial port
printf 'enable_uart=%s\n' '1' >> /boot/config.txt

# configure i2c clock overlay
printf 'dtoverlay=%s\n' 'i2c-rtc,ds1307' >> /boot/config.txt

# configure networking flags
sed -i -e 's/$/ ut_skip_br ut_br_ospf_garage/' /boot/cmdline.txt

# install/configure dhcp service
apt-get install -qq -y isc-dhcp-relay isc-dhcp-server git

# install/configure chrony
apt-get install -qq -y chrony

# install/configure daytime
apt-get install -qq -y xinetd
augtool set '/files/etc/xinetd.d/daytime/service[1]/disable' '"no"'
firewall-offline-cmd --new-service=daytime
firewall-offline-cmd --service=daytime --add-port=13/tcp
firewall-offline-cmd --service=daytime --set-short=daytime

# install/configure bind(!)
cat <<_EOF_>/etc/systemd/resolved.conf
[Resolve]
DNSStubListener=no
DNS=127.0.0.1
_EOF_
cat <<_EOF_>/etc/logrotate.d/named-stats
/var/cache/bind/named.stats {
  su bind bind
  daily
  rotate 4
  compress
  delaycompress
  create 0644 bind bind
  missingok
  postrotate
    rndc reload > /dev/null
  endscript
}
_EOF_

apt-get install -qq -y bind9

# install/configure nginx
apt-get install -qq -y nginx

# TODO: certbot

# install/configure pdns authoritative
mkdir /usr/lib/untrustedhost/share
printf '%s\n' "pdns-backend-sqlite3 pdns-backend-sqlite3/dbconfig-install boolean false" | debconf-set-selections
apt-get install -qq -y pdns-server sqlite3 dbconfig-sqlite3 haveged
pushd /tmp
apt-get download pdns-backend-sqlite3
dpkg -i pdns-backend-sqlite3_*.deb
ar x pdns-backend-sqlite3_*.deb
tar xf data.tar.xz ./usr/share/pdns-backend-sqlite3/schema/schema.sqlite3.sql
mv ./usr/share/pdns-backend-sqlite3/schema/schema.sqlite3.sql /usr/lib/untrustedhost/share/
popd
mv /tmp/pimd/pdns.conf /etc/powerdns/pdns.conf
rm -f /etc/powerdns/pdns.d/bind.conf
mv /tmp/pimd/pdns.local.gsqlite3.conf /etc/powerdns/pdns.d
mkdir -p /etc/systemd/system/pdns.service.d
mv /tmp/pimd/10-wire-namespace.conf /etc/systemd/system/pdns.service.d

# configure rsyslog
cat <<_EOF_>/etc/rsyslog.d/logsink.conf
template(name="remote_daily" type="string" string="/var/log/remote/%FROMHOST-IP%/%\$YEAR%-%\$MONTH%-%$DAY%.log")

ruleset(name="logsink"){
  action(type="omfile" DynaFile="remote_daily")
}

module(load="imudp")

input(type="imudp" address="172.16.193.214" port="514" ruleset="logsink")
_EOF_
