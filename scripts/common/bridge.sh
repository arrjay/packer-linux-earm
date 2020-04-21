#!/usr/bin/env bash

set -ex

apt-get install -qq -y dkms

# pry bridge module out of kernel tree and build with dkms
MVER=2.3
MOD=bridge
# this screwy path is because there's a private header inc'd by the trace subsystem
# so we make a path relative to _us_ that works.
mkdir -p "/usr/src/${MOD}-${MVER}/src/lx"
cd "/usr/src/${MOD}-${MVER}/src/lx"
cp -R /usr/src/linux-upstream/net/bridge .
mkdir -p "/usr/src/${MOD}-${MVER}/net"
# fix headers with relative links, bleh
ln -s "../src/lx/bridge" "/usr/src/${MOD}-${MVER}/net/bridge"
cat <<_EOF_>Makefile
ifneq (\$(DKMS_KERNEL_VERSION),)
KERNELVER = \$(DKMS_KERNEL_VERSION)
else 
KERNELVER ?= \$(shell uname -r) 
endif 
 
# allow to build for other headers
KERNEL_SRC ?= /lib/modules/\$(KERNELVER)/build

obj-m            += bridge/

all:
	make -C \$(KERNEL_SRC) M=\$(CURDIR) modules

clean:
	make -C \$(KERNEL_SRC) M=\$(CURDIR) clean

install:
	make -C \$(KERNEL_SRC) M=\$(CURDIR) modules_install
_EOF_
cat <<_EOF_>dkms.conf
MAKE[0]="'make' -C src all DKMS_KERNEL_VERSION=\$kernelver"
CLEAN="'make' clean"
BUILT_MODULE_NAME[0]="$MOD"
BUILT_MODULE_LOCATION[0]=''
PACKAGE_NAME="$MOD"
PACKAGE_VERSION="$MVER"
DEST_MODULE_LOCATION[0]="/kernel/net/bridge"
AUTOINSTALL="yes"
REMAKE_INITRD=no
_EOF_

dkms add -m $MOD -v $MVER

for kv in /lib/modules/* ; do
  # HACK: do not build for 64-bit today.
  case "${kv}" in *-v8+) continue ;; esac
  dkms install -k ${kv##*/} -m $MOD -v $MVER || { find /var/lib/dkms/$MOD/$MVER -type f ; cat /var/lib/dkms/$MOD/$MVER/build/make.log ; exit 1 ; }
done
