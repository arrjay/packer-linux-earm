#!/usr/bin/env bash

apt-get -qq clean
apt-get -qq -y install yubikey-personalization \
                       yubikey-personalization-gui \
                       yubikey-manager
apt-get -qq clean
