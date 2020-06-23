#!/usr/bin/env bash

set -e

export DEBIAN_FRONTEND=noninteractive
export LANG=C

# just for comparison...
df -m

# wire initonce
mkdir -p /usr/lib/untrustedhost/scripts
mv /tmp/initonce.sh /usr/lib/untrustedhost/scripts
chmod +x /usr/lib/untrustedhost/scripts/initonce.sh

sed -ie 's@ init=[0-9a-zA-Z/_.\-]\+@@' /boot/cmdline.txt
sed -ie 's@$@ init=/usr/lib/untrustedhost/scripts/initonce.sh@' /boot/cmdline.txt

# HACK: rewire sources.list to use our cache...
cat <<_EOF_>/etc/apt/sources.list
deb http://hose.g.bbxn.us/apt/raspbian buster main contrib non-free rpi
# Uncomment line below then 'apt-get update' to enable 'apt-get source'
deb-src http://hose.g.bbxn.us/apt/raspbian buster main contrib non-free rpi
_EOF_
cat <<_EOF_>/etc/apt/sources.list.d/raspi.list
#deb http://archive.raspberrypi.org/debian/ buster main
deb http://hose.g.bbxn.us/apt/raspberrypi/debian/ buster main
# Uncomment line below then 'apt-get update' to enable 'apt-get source'
#deb-src http://archive.raspberrypi.org/debian/ buster main
_EOF_

apt-get -o APT::Sandbox::User=root update

# drop docs, groff, lintian
cat <<EOF>/etc/dpkg/dpkg.cfg.d/01_nodoc
path-exclude /usr/share/doc/*
# we need to keep copyright files for legal reasons
path-include /usr/share/doc/*/copyright
path-exclude /usr/share/man/*
path-exclude /usr/share/groff/*
path-exclude /usr/share/info/*
# lintian stuff is small, but really unnecessary
path-exclude /usr/share/lintian/*
path-exclude /usr/share/linda/*
EOF

# delete anything from that now
find /usr/share/doc -depth -type f ! -name copyright|xargs rm || true
find /usr/share/doc -empty|xargs rmdir || true
rm -rf /usr/share/groff/* /usr/share/info/* /usr/share/man/*
rm -rf /usr/share/lintian/* /usr/share/linda/* /var/cache/man/*

# configure pi locale
raspi-config nonint do_configure_keyboard us
raspi-config nonint do_change_locale en_US.UTF-8

# server runs in UCT kthxbye
ln -sf /usr/share/zoneinfo/UCT /etc/localtime

# https://blog.packagecloud.io/eng/2017/02/21/set-environment-variable-save-thousands-of-system-calls/ o_O
mkdir -p /etc/systemd/system.conf.d
printf '[Manager]\nDefaultEnvironment=TZ=UCT\n' > /etc/systemd/system.conf.d/TZ.conf

# people run in LA...
printf 'TZ=America/Los_Angeles\n' >> /etc/environment

# configure localepurge, make ssl shut _up_
libssl=$(dpkg -l | grep libssl | awk '{print $2}') 
printf '%s\n' "localepurge localepurge/use-dpkg-feature boolean false" \
              "localepurge localepurge/mandelete boolean true" \
              "localepurge localepurge/dontbothernew boolean true" \
              "localepurge localepurge/showfreedspace boolean false" \
              "localepurge localepurge/quickndirtycale boolean true" \
              "localepurge localepurge/verbose boolean false" \
              "localepurge localepurge/nopurge string en,en_US,en_US.UTF-8" \
              "${libssl} libraries/restart-without-asking boolean true" \
 | debconf-set-selections
apt-get -qq -y install localepurge
localepurge
echo "localepurge localepurge/use-dpkg-deature boolean true" | debconf-set-selections
dpkg-reconfigure localepurge
apt-get -qq clean

# collect stats for next image...
df -m
