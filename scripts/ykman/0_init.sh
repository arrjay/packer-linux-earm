#!/usr/bin/env bash

set -ex
shopt -s dotglob

export DEBIAN_FRONTEND=noninteractive
export LANG=C
PFSRC=/tmp/packer-files

apt-get -qq clean
apt-get -qq -y install yubikey-personalization \
                       yubikey-personalization-gui \
                       yubikey-manager \
                       gawk fdupes \
                       imagemagick paperkey fonts-freefont-otf zbar-tools ghostscript qrencode \
                       system-config-printer system-config-printer-udev cups cups-daemon \
                       hplip printer-driver-hpijs hpijs-ppds
apt-get -qq clean

# fix the imagemagick policy... first with awk to get it validating, then xmlstarlet.
awk '{ if ($1 == "<!--" && $2 == "<policy" && $NF != "-->") { print $0, "-->" }
       else { print $0 } }' /etc/ImageMagick-6/policy.xml | \
xmlstarlet ed -u 'policymap/policy[@pattern="PDF"]/@rights' -v 'read|write' > /tmp/policy.xml
mv /tmp/policy.xml /etc/ImageMagick-6/policy.xml

u=gfx
# NOTE: position-dependent arguments...
tar xvf "${PFSRC}/cache/misc-scripts.tar" -C "/home/${u}" --strip-components=1 noarch/cardykey.sh
tar xvf "${PFSRC}/cache/keymat.tar" -C "/home/${u}"
chmod +x "/home/${u}/cardykey.sh" "/home/${u}/keymat"/*.sh
chown -R "${u}:${u}" "/home/${u}"
