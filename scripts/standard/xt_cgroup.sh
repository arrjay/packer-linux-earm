#!/usr/bin/env bash

set -e
MOD=xt_cgroup
MVER="${XT_CGROUP_DKMS_VERSION}"
PFSRC=/tmp/packer-files

# if we already have xt_cgroup somewhere, go away
haz=0
for kv in /lib/modules/* ; do
   modinfo -k "${kv##*/}" "${MOD}" && ((haz=haz+1))
done
[[ "${haz}" -gt 0 ]] && exit 0

case "${PACKER_BUILD_NAME}" in
  pi) KH_PKG=("raspberrypi-kernel" "raspberrypi-kernel-headers") ; UPSTREAM_KVER=5.4.60 ;;
  *)  echo "missing xt_group and not sure about kernel header package, oop." 1>&2 ; exit 1 ;;
esac

# the raspberry pi kernel sources from apt-get are a mess, and using git to retrieve kernel sources is silly.
# have a... "close enough"
[[ ! -d /usr/src/linux-upstream ]] && {
  curl -L -o /root/kernel.txz "https://cdn.kernel.org/pub/linux/kernel/v${UPSTREAM_KVER%%.*}.x/linux-${UPSTREAM_KVER}.tar.xz"
  mkdir /usr/src/linux-upstream
  cd /usr/src/linux-upstream
  tar x --strip-components=1 -f /root/kernel.txz -C .
  rm /root/kernel.txz
}

apt-get install -qq -y dkms "${KH_PKG[@]}"

# pry xt_cgroup module out of kernel tree and build with dkms
cp -R "${PFSRC}/dkms/${MOD}-${MVER}" /usr/src
cd "/usr/src/${MOD}-${MVER}"
cp "/usr/src/linux-upstream/net/netfilter/${MOD}.c" .

dkms add -m "${MOD}" -v "${MVER}"

for kv in /lib/modules/* ; do
  # HACK: do not build for 64-bit today.
  case "${kv}" in *-v8+) continue ;; esac
  dkms install -k "${kv##*/}" -m $MOD -v "${MVER}" || {
    find "/var/lib/dkms/${MOD}/${MVER}" -type f ; cat "/var/lib/dkms/${MOD}/${MVER}/build/make.log" ; exit 1
  }
done
