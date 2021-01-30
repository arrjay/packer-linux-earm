#!/usr/bin/env bash

set -ex

# build tang...from source
apt-get install -qq -y ninja-build meson libjose-dev libhttp-parser-dev jose
cd /usr/src
git clone https://github.com/latchset/tang
cd tang
git checkout 75106616bb7a4255d2303e4b31205cb2ad1d8bfa
mkdir build
cd build
meson .. --prefix=/usr
ninja
ninja install
