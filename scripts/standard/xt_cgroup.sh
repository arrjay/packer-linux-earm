#!/usr/bin/env bash

set -ex

# the raspberry pi kernel sources from apt-get are a mess, and using git to retrieve kernel sources is silly.
# have a... "close enough"
curl -L -o /root/kernel.txz https://hose.g.bbxn.us/linux/kernel/v4.x/linux-4.19.131.tar.xz
mkdir /usr/src/linux-upstream
cd /usr/src/linux-upstream
tar x --strip-components=1 -f /root/kernel.txz -C .
rm /root/kernel.txz

apt-get install -qq -y dkms raspberrypi-kernel-headers

# pry xt_cgroup module out of kernel tree and build with dkms
MVER=0.1
MOD=xt_cgroup
mkdir "/usr/src/${MOD}-${MVER}"
cd "/usr/src/${MOD}-${MVER}"
cp /usr/src/linux-upstream/net/netfilter/xt_cgroup.c .
cat <<_EOF_>Makefile
ifneq (\$(DKMS_KERNEL_VERSION),)
KERNELVER = \$(DKMS_KERNEL_VERSION)
else 
KERNELVER ?= \$(shell uname -r) 
endif 
 
# allow to build for other headers
KERNEL_SRC ?= /lib/modules/\$(KERNELVER)/build

obj-m += xt_cgroup.o

all:
	make -C \$(KERNEL_SRC) M=\$(CURDIR) modules

clean:
	make -C \$(KERNEL_SRC) M=\$(CURDIR) clean

install:
	make -C \$(KERNEL_SRC) M=\$(CURDIR) modules_install
_EOF_
cat <<_EOF_>dkms.conf
MAKE[0]="'make' all DKMS_KERNEL_VERSION=\$kernelver"
CLEAN="'make' clean"
BUILT_MODULE_NAME[0]="$MOD"
BUILT_MODULE_LOCATION[0]=''
PACKAGE_NAME="$MOD"
PACKAGE_VERSION="$MVER"
DEST_MODULE_LOCATION[0]="/kernel/net/netfilter"
AUTOINSTALL="yes"
REMAKE_INITRD=no
_EOF_

dkms add -m $MOD -v $MVER

for kv in /lib/modules/* ; do
  # HACK: do not build for 64-bit today.
  case "${kv}" in *-v8+) continue ;; esac
  dkms install -k ${kv##*/} -m $MOD -v $MVER || { find /var/lib/dkms/$MOD/$MVER -type f ; cat /var/lib/dkms/$MOD/$MVER/build/make.log ; exit 1 ; }
done
