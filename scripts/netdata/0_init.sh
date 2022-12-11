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
apt-get install autoconf autoconf-archive autogen automake curl cmake gcc git gzip libjudy-dev libelf-dev liblz4-dev libmnl-dev libssl-dev libuv1-dev lm-sensors make netcat pkg-config python3 python3-mysqldb python3-psycopg2 python3-pymongo tar uuid-dev zlib1g-dev jq firewalld g++ "${extrapkgs}"

cd /usr/src
git clone https://github.com/netdata/netdata.git
cd netdata
git checkout v1.37.1
git submodule update --init --recursive
./netdata-installer.sh --dont-start-it --dont-wait --disable-telemetry

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

# add firewalld service
firewall-offline-cmd --new-service=netdata
firewall-offline-cmd --service=netdata --add-port=19999/tcp
firewall-offline-cmd --service=netdata --set-short=netdata

df -m
