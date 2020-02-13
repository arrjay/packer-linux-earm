#!/usr/bin/env bash

# install netdata - omnibus install
apt-get -qq -y install autoconf autoconf-archive autogen automake curl gcc git gzip libjudy-dev liblz4-dev libmnl-dev libssl-dev libuv1-dev lm-sensors make netcat nodejs pkg-config python python-mysqldb python-psycopg2 python-pymongo tar uuid-dev zlib1g-dev jq python-ipaddress
cd /usr/src
git clone https://github.com/netdata/netdata.git
cd netdata
git checkout v1.19.0
./netdata-installer.sh --dont-start-it --dont-wait

# force old lm_sensors plugin on
echo sensors=force >> /etc/netdata/charts.d.conf

# disable version check in web dashboard
echo 0 > /usr/share/netdata/web/version.txt

# add firewalld service
firewall-offline-cmd --new-service=netdata
firewall-offline-cmd --service=netdata --add-port=19999/tcp
firewall-offline-cmd --service=netdata --set-short=netdata
