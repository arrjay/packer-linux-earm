#!/usr/bin/env bash

set -e

# the raspberry pi kernel sources from apt-get are a mess, and using git to retrieve kernel sources are silly.
# have a... "close enough"
curl -L -o /root/kernel.txz https://hose.g.bbxn.us/linux/kernel/v4.x/linux-4.19.120.tar.xz
mkdir /usr/src/linux-upstream
cd /usr/src/linux-upstream
tar x --strip-components=1 -f /root/kernel.txz -C .
rm /root/kernel.txz
