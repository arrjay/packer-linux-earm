#!/usr/bin/env bash

apt-get -qq -y install snmp snmptrapd snmptt snmp-mibs-downloader

mkdir -p /usr/share/mibs/site
cd /usr/share/mibs/site
curl -LO http://www.downloads.netgear.com/files/GDC/GS110TP/GS108Tv2_GS110TP%20MIB_V5.4.2.16.zip
unzip -j GS108Tv2_GS110TP%20MIB_V5.4.2.16.zip
