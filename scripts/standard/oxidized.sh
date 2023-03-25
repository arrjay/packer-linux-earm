#!/usr/bin/env bash

# create oxidized user
groupadd oxidized
useradd -g oxidized oxidized

mkdir ~oxidized

chown oxidized:oxidized ~oxidized

# set up rvm, get a ruby
sudo -Hi -u oxidized gpg --keyserver hkp://pool.sks-keyservers.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
sudo -Hi -u oxidized curl https://rvm.io/mpapis.asc     | sudo -Hi -u oxidized gpg --import -
sudo -Hi -u oxidized curl https://rvm.io/pkuczynski.asc | sudo -Hi -u oxidized gpg --import -
sudo -Hi -u oxidized curl -sSL https://get.rvm.io | sudo -Hi -u oxidized bash -s stable
sudo -Hi -u oxidized ~oxidized/.rvm/bin/rvm autolibs read-fail
#sudo -Hi -u oxidized ~oxidized/.rvm/bin/rvm requirements
sudo -Hi -u oxidized ~oxidized/.rvm/bin/rvm install 2.7
#sudo -Hi -u oxidized ~oxidized/.rvm/bin/rvm use --default 2.7
sudo -Hi -u oxidized ~oxidized/.rvm/bin/rvm 2.7 do rvm gemset create oxi-upstream
sudo -Hi -u oxidized mkdir ~oxidized/src
sudo -Hi -u oxidized --chdir ~oxidized/src git clone https://github.com/arrjay/oxidized
sudo -Hi -u oxidized --chdir ~oxidized/src/oxidized git checkout mainline
sudo -Hi -u oxidized --chdir ~oxidized/src/oxidized ~oxidized/.rvm/bin/rvm 2.7@oxi-upstream do gem build
gemfile=(~oxidized/src/oxidized/oxidized*gem)
sudo -Hi -u oxidized --chdir ~oxidized/src/oxidized ~oxidized/.rvm/bin/rvm 2.7@oxi-upstream do gem install "${gemfile[0]}"

# cleanup
pkill -9 -u oxidized
