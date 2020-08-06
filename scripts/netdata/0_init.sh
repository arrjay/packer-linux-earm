#!/usr/bin/env bash

set -e

export DEBIAN_FRONTEND=noninteractive
export LANG=C

. /etc/environment
export $(awk -F= '{ print $1 }' < /etc/environment)

apt-get -o APT::Sandbox::User=root update

# armel does *not* have nodejs
case "${PACKER_BUILD_NAME}" in
  sheeva) extrapkgs=''       ;;
  *)      extrapkgs='nodejs' ;;
esac

# install netdata - omnibus install
apt-get install autoconf autoconf-archive autogen automake curl cmake gcc git gzip libjudy-dev liblz4-dev libmnl-dev libssl-dev libuv1-dev lm-sensors make netcat pkg-config python python-mysqldb python-psycopg2 python-pymongo tar uuid-dev zlib1g-dev jq python-ipaddress firewalld "${extrapkgs}"

cd /usr/src
git clone https://github.com/netdata/netdata.git
cd netdata
git checkout v1.23.2
# HACK: currently ebpf is disabled because it doesn't work on arm.
./netdata-installer.sh --dont-start-it --dont-wait --disable-ebpf

case "${PACKER_BUILD_NAME}" in
  pi)
    # force old lm_sensors plugin on
    echo sensors=force >> /etc/netdata/charts.d.conf
    chown netdata:netdata /etc/netdata/charts.d.conf
    chmod 0644 /etc/netdata/charts.d.conf
   ;;
esac

# disable version check in web dashboard
echo 0 > /usr/share/netdata/web/version.txt

# HACK 2: disable ebpf plugin by just...writing a config file. sure.
cat<<EOF>/etc/netdata/netdata.conf
[plugins]
  ebpf = no
EOF
chown 0:0 /etc/netdata/netdata.conf ; chmod 0644 /etc/netdata/netdata.conf

# add firewalld service
firewall-offline-cmd --new-service=netdata
firewall-offline-cmd --service=netdata --add-port=19999/tcp
firewall-offline-cmd --service=netdata --set-short=netdata

df -m
