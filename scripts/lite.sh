#!/usr/bin/env bash

set -e

export DEBIAN_FRONTEND=noninteractive
export LANG=C

# just for comparison...
df -m

# drop dist hack for init
sed -i -e 's@ init=[0-9a-zA-Z/_.\-]\+@@' /boot/cmdline.txt

# HACK: rewire sources.list to use our cache...
cat <<_EOF_>/etc/apt/sources.list
deb http://hose.g.bbxn.us/apt/raspbian buster main contrib non-free rpi
# Uncomment line below then 'apt-get update' to enable 'apt-get source'
deb-src http://hose.g.bbxn.us/apt/raspbian buster main contrib non-free rpi
_EOF_
cat <<_EOF_>/etc/apt/sources.list.d/raspi.list
#deb http://archive.raspberrypi.org/debian/ buster main
deb http://hose.g.bbxn.us/apt/raspberrypi/debian/ buster main
# Uncomment line below then 'apt-get update' to enable 'apt-get source'
#deb-src http://archive.raspberrypi.org/debian/ buster main
_EOF_

# drop in our apt files
cat <<_EOF_>/etc/apt/apt.conf.d/0assume-yes
APT::Get::Assume-Yes "true";
_EOF_

cat <<_EOF_>/etc/apt/apt.conf.d/0quiet
APT::GET::quiet "1";
_EOF_

cat <<_EOF_>/etc/apt/apt.conf.d/autoremove-suggests
Apt::AutoRemove::SuggestsImportant "false";
_EOF_

cat <<_EOF_>/etc/apt/apt.conf.d/autoclean
DPkg::Post-Invoke { "rm -f /var/cache/apt/archives/*.deb /var/cache/apt/archives/partial/*.deb /var/cache/apt/*.bin || true"; };
APT::Update::Post-Invoke { "rm -f /var/cache/apt/archives/*.deb /var/cache/apt/archives/partial/*.deb /var/cache/apt/*.bin || true"; };
Dir::Cache::pkgcache ""; Dir::Cache::srcpkgcache "";
_EOF_

cat <<_EOF_>/etc/apt/apt.conf.d/gzip-indexes
Acquire::GzipIndexes "true"; Acquire::CompressionTypes::Order:: "gz";
_EOF_

cat <<_EOF_>/etc/apt/apt.conf.d/no-languages
Acquire::Languages "none";
_EOF_

cat <<_EOF_>/etc/apt/apt.conf.d/zz-no-install-recommends
apt::install-recommends "false";
_EOF_

# force the update as root, otherwise this fails in some packer-chroots
apt-get -o APT::Sandbox::User=root update

# drop docs, groff, lintian
cat <<_EOF_>/etc/dpkg/dpkg.cfg.d/01_nodoc
path-exclude /usr/share/doc/*
# we need to keep copyright files for legal reasons
path-include /usr/share/doc/*/copyright
path-exclude /usr/share/man/*
path-exclude /usr/share/groff/*
path-exclude /usr/share/info/*
# lintian stuff is small, but really unnecessary
path-exclude /usr/share/lintian/*
path-exclude /usr/share/linda/*
_EOF_

cat <<_EOF_>/etc/dpkg/dpkg.cfg.d/01_noi18n
path-exclude /usr/share/locale/*
path-include /usr/share/locale/en*
path-exclude /usr/share/i18n/locales/*
path-include /usr/share/i18n/locales/en*
_EOF_

# delete anything from that now
find /usr/share/doc -depth -type f ! -name copyright|xargs rm || true
find /usr/share/doc -empty|xargs rmdir || true
rm -rf /usr/share/groff/* /usr/share/info/* /usr/share/man/*
rm -rf /usr/share/lintian/* /usr/share/linda/* /var/cache/man/*

# configure pi locale
raspi-config nonint do_configure_keyboard us
raspi-config nonint do_change_locale en_US.UTF-8

# server runs in UCT kthxbye
ln -sf /usr/share/zoneinfo/UCT /etc/localtime

# https://blog.packagecloud.io/eng/2017/02/21/set-environment-variable-save-thousands-of-system-calls/ o_O
mkdir -p /etc/systemd/system.conf.d
printf '[Manager]\nDefaultEnvironment=TZ=UCT\n' > /etc/systemd/system.conf.d/TZ.conf

# people run in LA...
printf 'TZ=America/Los_Angeles\n' >> /etc/environment

# configure localepurge, make ssl shut _up_
libssl=$(dpkg -l | grep libssl | awk '{print $2}') 
printf '%s\n' "localepurge localepurge/use-dpkg-feature boolean false" \
              "localepurge localepurge/mandelete boolean true" \
              "localepurge localepurge/dontbothernew boolean true" \
              "localepurge localepurge/showfreedspace boolean false" \
              "localepurge localepurge/quickndirtycale boolean true" \
              "localepurge localepurge/verbose boolean false" \
              "localepurge localepurge/nopurge string en,en_US,en_US.UTF-8" \
              "${libssl} libraries/restart-without-asking boolean true" \
 | debconf-set-selections
apt-get install localepurge
localepurge
echo "localepurge localepurge/use-dpkg-deature boolean true" | debconf-set-selections
dpkg-reconfigure localepurge

# configure initramfs generation
printf 'RPI_INITRD=%s\n' 'Yes' >> /etc/default/raspberrypi-kernel
cat <<_EOF_> /etc/kernel/postinst.d/rpi-initramfs
#!/bin/sh -e

case "\${RPI_INITRD}" in
  Y*|y*|T*|t*|1) : ;;
  *)             exit 0 ;;
esac

# relies on the fact pi can't have multiple kernels installed. feels bad.
for kv in /lib/modules/* ; do
  case "\${kv}" in
    *-v7+)   mkinitramfs -o /boot/initrd7.img  "\${kv}" ;;
    *-v7l+)  mkinitramfs -o /boot/initrd7l.img "\${kv}" ;;
    *-v8+)   mkinitramfs -o /boot/initrd8.img  "\${kv}" ;;
    *[0-9]+) mkinitramfs -o /boot/initrd.img   "\${kv}" ;;
  esac
done
_EOF_
chmod 0755 /etc/kernel/postinst.d/rpi-initramfs

# append initramfs loading to config.txt
cat <<_EOF_>>/boot/config.txt
[pi0]
initramfs initrd.img followkernel
[pi1]
initramfs initrd.img followkernel
[pi2]
# NOTE: if you are using a 64-bit kernel, adjust these!
initramfs initrd7.img followkernel
[pi3]
initramfs initrd7.img followkernel
[pi4]
initramfs initrd7l.img followkernel
[all]
# cleared filter
# for serial support, do this:
#cmdline=serial.txt
#enable_uart=1
_EOF_

# add hooks for resizing and ld.so.preload fixups
cat <<_EOF_>/etc/initramfs-tools/hooks/resize-parttbl
#!/bin/sh
# install in initramfs-tools/hooks/resize-parttbl

set -e

PREREQ=""

prereqs () {
	echo "\${PREREQ}"
}

case "\${1}" in
	prereqs)
		prereqs
		exit 0
		;;
esac

. /usr/share/initramfs-tools/hook-functions

copy_exec /usr/bin/awk /usr/bin
copy_exec /sbin/blkid /sbin
copy_exec /bin/lsblk /bin
copy_exec /sbin/parted /sbin
_EOF_
chmod 0755 /etc/initramfs-tools/hooks/resize-parttbl

cat <<_EOF_>/etc/initramfs-tools/scripts/local-premount/resize-parttbl
#!/bin/sh
# resize partition table script
# install in initramfs-tools/scripts/local-premount

PREREQ=""
prereqs()
{
     echo "\$PREREQ"
}

case \$1 in
prereqs)
     prereqs
     exit 0
     ;;
esac

. /scripts/functions

# bail if we're resuming, ok?
if [ -n "\${resume?}" ] || [ -e /sys/power/resume ]; then
        exit 0
fi

# deps
command -v awk >/dev/null || exit 0
command -v blkid >/dev/null || exit 0
command -v lsblk >/dev/null || exit 0
command -v parted >/dev/null || exit 0

# find partitions belonging to the root block device and extend them.
log_begin_msg "resizing partitions underlying \${ROOT}"
case "\${ROOT}" in
  /*)
    rootdev="\${ROOT}"
   ;;
  *=*) 
    lsbk=\$(echo "\${ROOT}" | awk -F= '{ print \$1 }')
    lsbv=\$(echo "\${ROOT}" | awk -F= '{ gsub(/"/, "", \$2) ; print \$2 }')
    rootdev=\$(blkid | awk -F: '\$2 ~ "'"\${lsbk}"'=\"'"\${lsbv}"'\"" { print \$1 }')
   ;;
esac

parts=\$(lsblk -Ps "\${rootdev}" | awk '\$0 ~ "TYPE=\"part\"" { e=split(\$1, o, "=") ; gsub(/"/, "", o[e]) ; print o[e] }')

for slice in \${parts} ; do
  read -r pno < "/sys/class/block/\${slice}/partition"
  disk=\$(lsblk -Ps "/dev/\${slice}" | awk '\$0 ~ "TYPE=\"disk\"" { e=split(\$1, o, "=") ; gsub(/"/, "", o[e]) ; print o[e] }')
  parted -s "/dev/\${disk}" resizepart "\${pno}" 100%
done

log_end_msg
_EOF_
chmod 0755 /etc/initramfs-tools/scripts/local-premount/resize-parttbl

cat <<_EOF_>/etc/initramfs-tools/scripts/local-bottom/ld_preload_hack
#!/bin/sh
# move ld.preload.dist back if it exists
# install in initramfs-tools/scripts/local-bottom

PREREQ=""
prereqs()
{
     echo "\$PREREQ"
}

case \$1 in
prereqs)
     prereqs
     exit 0
     ;;
esac

. /scripts/functions

[ -f "\${rootmnt}/etc/ld.so.preload.dist" ] && {
  mount -o rw,remount "\${rootmnt}"
  mv "\${rootmnt}/etc/ld.so.preload.dist" "\${rootmnt}/etc/ld.so.preload"
  mount -o ro,remount "\${rootmnt}"
}
_EOF_
chmod 0755 /etc/initramfs-tools/scripts/local-bottom/ld_preload_hack

# create the initrds
RPI_INITRD=yes /etc/kernel/postinst.d/rpi-initramfs

# create an alternate serial.txt commandline
sed -e 's/console=tty1//' -e 's/quiet//' -e 's/ +//' < /boot/cmdline.txt > /boot/serial.txt

# collect stats for next image...
df -m
