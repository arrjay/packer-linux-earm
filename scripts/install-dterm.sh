#!/bin/sh

set -e

apt-get -qq -y install libreadline-dev

curl -L -o /tmp/dterm.tgz http://www.knossos.net.nz/downloads/dterm-0.5.tgz

mkdir -p /usr/src/dterm
tar xvf /tmp/dterm.tgz -C /usr/src/dterm --strip-components=1

cd /usr/src/dterm
make

cp /usr/src/dterm/dterm /usr/local/bin/dterm
chmod 0755 /usr/local/bin/dterm

