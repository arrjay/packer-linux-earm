#!/usr/bin/env bash

# set up a recursive dns server with magix forward records to the authority.
apt-get install bind9

systemctl disable bind9
