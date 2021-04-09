#!/usr/bin/env bash

set -ex

# build tang...from source
apt-get install -qq -y ninja-build meson libjose-dev libhttp-parser-dev jose
cd /usr/src
git clone https://github.com/latchset/tang
cd tang
git checkout v8
mkdir build
cd build
meson .. --prefix=/usr
ninja
ninja install
