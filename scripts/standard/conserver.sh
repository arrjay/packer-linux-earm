#!/usr/bin/bash

VERSION=8.2.6

curl -L -o /tmp/conserver.tgz "https://github.com/bstansell/conserver/releases/download/v${VERSION}/conserver-${VERSION}.tar.gz"

apt-get install libipmiconsole-dev

cd /usr/src
tar xf /tmp/conserver.tgz
cd "conserver-${VERSION}"
./configure --with-uds --with-freeipmi
make install 
