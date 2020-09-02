#!/usr/bin/env bash

set -e

apt-get install unbound

usermod -a -G unbound netdata

systemctl disable unbound

# this thing exits nonzero if it updates the anchor. I hate it.
unbound-anchor -vv || true

cd /usr/src
git clone https://github.com/arrjay/unbound-hosts-blocklists/

mkdir -p /usr/lib/unbound-hosts-blocklists

printf 'workdir=%s\n' '/usr/lib/unbound-hosts-blocklists' > /etc/update-blocklists.conf

/usr/src/unbound-hosts-blocklists/update-blocklists

ln -s /usr/lib/unbound-hosts-blocklists/local-data.conf /etc/unbound/unbound.conf.d/local-data.conf
