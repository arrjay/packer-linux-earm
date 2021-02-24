#!/usr/bin/bash

VERSION=8.2.6

curl -L -o /tmp/conserver.tgz "https://github.com/bstansell/conserver/releases/download/v${VERSION}/conserver-${VERSION}.tar.gz"

apt-get install libwrap0-dev libpam0g-dev libipmiconsole-dev

cd /usr/src
tar xf /tmp/conserver.tgz
cd "conserver-${VERSION}"
./configure --with-uds --with-freeipmi --with-ipv6 --with-pam --with-libwrap
make install 
