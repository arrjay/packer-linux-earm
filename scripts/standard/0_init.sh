#!/usr/bin/env bash

set -e
shopt -s dotglob

export DEBIAN_FRONTEND=noninteractive
export LANG=C
PFSRC=/tmp/packer-files

# just for comparison...
df -m

# load any environment things we need and export them
. /etc/environment
export $(awk -F= '{ print $1 }' < /etc/environment)

# recursion function for walking around in /tmp, installing to /etc
install_ef () {
  local s d
  while (( "$#" )) ; do
    s="${1}" ; shift
    [[ -e "${s}" ]] || continue
    [[ -d "${s}" ]] && { "${FUNCNAME[0]}" "${s}"/* ; continue ; }
    d="${s#/tmp}"
    install --verbose --mode="${INSTALL_MODE:-0644}" --owner=0 --group=0 -D "${s}" "${TARGET_DIR:-/etc}${d}"
  done
}

# HACK: imd expects bird. that's not gonna happen, so...
install --verbose -o 0 -g 0 -d /etc/bird

# install imd kit now
chmod +x "${PFSRC}/cache/imd/install.run"
"${PFSRC}/cache/imd/install.run"

# disable pi's userconfig
case "${PACKER_BUILD_NAME}" in
  pi)
    systemctl disable userconfig
  ;;
esac

# install system configs from packer file provisioner
for source in \
  "${PFSRC}/cache/etc/skel" \
  "${PFSRC}/systemd" \
  "${PFSRC}/untrustedhost" \
  "${PFSRC}/untrustedhost-scripts" \
  "${PFSRC}/imd" \
  "${PFSRC}/logrotate.d" \
  "${PFSRC}/udev" \
  "${PFSRC}/incron.d" \
  "${PFSRC}/networkd-dispatcher" \
 ; do
  [[ -d "${source}" ]] && rsync -a "${source}/" "/tmp/${source##*/}/"
done

# if we have a platform directory, arrange for that too
for source in \
  "${PFSRC}/${PACKER_BUILD_NAME}/untrustedhost" \
  "${PFSRC}/${PACKER_BUILD_NAME}/untrustedhost-scripts" \
  "${PFSRC}/${PACKER_BUILD_NAME}/imd" \
  "${PFSRC}/${PACKER_BUILD_NAME}/systemd" \
  "${PFSRC}/${PACKER_BUILD_NAME}/incron.d" \
 ; do
  [[ -d "${source}" ]] && rsync -a "${source}/" "/tmp/${source##*/}/"
done

# install from scratch directories into filesystem, clean them back up
for directory in /tmp/systemd /tmp/untrustedhost /tmp/logrotate.d /tmp/udev /tmp/incron.d ; do
  install_ef "${directory}"
  rm -rf "${directory}"
done

for directory in /tmp/skel /tmp/networkd-dispatcher ; do
  INSTALL_MODE=0755 install_ef "${directory}"
  rm -rf "${directory}"
done

for directory in /tmp/imd ; do
  INSTALL_MODE=0755 TARGET_DIR=/usr/lib/untrustedhost install_ef "${directory}"
  rm -rf "${directory}"
done

# enable mdns to pass through firewalld
firewall-offline-cmd --add-service=mdns --zone=public

# disable ssh in external zone
firewall-offline-cmd --zone=external --remove-service-from-zone=ssh

# install additional scripts
rm -rf /tmp/scripts
mv /tmp/untrustedhost-scripts /tmp/scripts
for file in /tmp/scripts/* ; do
  INSTALL_MODE=0755 TARGET_DIR=/usr/lib/untrustedhost install_ef "${file}"
  rm -rf "${file}"
done

if [[ -e "${PFSRC}/${PACKER_BUILD_NAME}/fitstat" ]] ; then
  install --verbose --mode=0755 --owner=0 --group=0 -D "${PFSRC}/${PACKER_BUILD_NAME}/fitstat" "/usr/lib/untrustedhost/scripts/fitstat"
  systemctl enable untrustedhost-fitstat
fi

if [[ -e /etc/systemd/system/untrustedhost-pwm.service ]] ; then
  systemctl enable untrustedhost-pwm
fi
