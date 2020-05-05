#!/usr/bin/env bash

set -e

apt-get -qq -y install isc-dhcp-server

systemctl disable isc-dhcp-server
