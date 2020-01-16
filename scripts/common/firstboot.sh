#!/bin/sh

set -e

mkdir -p /usr/lib/untrustedhost/scripts
mv /tmp/initonce.sh /usr/lib/untrustedhost/scripts
chmod +x /usr/lib/untrustedhost/scripts/initonce.sh

sed -ie 's@ init=[0-9a-zA-Z/_.\-]\+@@' /boot/cmdline.txt
sed -ie 's@$@ init=/usr/lib/untrustedhost/scripts/initonce.sh@' /boot/cmdline.txt
