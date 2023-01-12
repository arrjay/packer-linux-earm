#!/usr/bin/env bash

set -ex

# we're gonna install these, build,. then remove 'em
BUILD_PACKAGES=(
    build-essential devscripts debhelper-compat dh-python
    pkg-config libcap-dev libgdbm-dev libglib2.0-dev libgtk-3-dev
    libexpat-dev libdaemon-dev libdbus-1-dev python3 python3-gdbm
    python3-dbus python3-gi python-gi-dev gobject-introspection
    libgirepository1.0-dev xmltoman intltool
)

# build the latest nut debs on rpi for pijuice support.
apt-get -o APT::Sandbox::User=root update
apt-get install "${BUILD_PACKAGES[@]}"

# build it out of backports...
curl -L -o /tmp/avahi.tgz http://archive.ubuntu.com/ubuntu/pool/main/a/avahi/avahi_0.8.orig.tar.gz
[[ "$(sha512sum /tmp/avahi.tgz | awk '{print $1}')" == 'c6ba76feb6e92f70289f94b3bf12e5f5c66c11628ce0aeb3cadfb72c13a5d1a9bd56d71bdf3072627a76cd103b9b056d9131aa49ffe11fa334c24ab3b596c7de' ]]
curl -L -o /tmp/avahi_debian.txz http://archive.ubuntu.com/ubuntu/pool/main/a/avahi/avahi_0.8-5ubuntu5.debian.tar.xz
[[ "$(sha512sum /tmp/avahi_debian.txz | awk '{print $1}')" == '4a769cbbcfd4696e11f65780b74fdece71d198972b4d43b2da15846322c372a7e5071464ec5af4b23742e963cc3a911c3b742ce6c2840edd994a569e64255ee2' ]]
cd /usr/src
tar xf /tmp/avahi.tgz
cd avahi-*
tar xf /tmp/avahi_debian.txz
debuild -b -uc -us
cd ..

# grab the tarball for the file provisioner to download
mkdir debs
mv ./*.deb debs
tar cvf avahi_debs.tar ./debs
