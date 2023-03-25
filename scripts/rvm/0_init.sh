#!/usr/bin/env bash

# srsly sudo
printf '%s\n' 'Defaults:root runcwd=*' > /etc/sudoers.d/015_root_runcwd
chmod 0440 /etc/sudoers.d/015_root_runcwd

apt-get -o APT::Sandbox::User=root update

apt-get install git gawk autoconf automake bison libffi-dev libgdbm-dev libncurses5-dev libsqlite3-dev \
	libtool libyaml-dev sqlite3 libgmp-dev libreadline-dev libssl-dev

# create scratch user
groupadd rvm
useradd -g rvm rvm

mkdir ~rvm

chown rvm:rvm ~rvm

# set up rvm, get a ruby
sudo -Hi -u rvm gpg --keyserver hkp://keys.openpgp.org --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
sudo -Hi -u rvm curl https://rvm.io/mpapis.asc     | sudo -Hi -u rvm gpg --import -
sudo -Hi -u rvm curl https://rvm.io/pkuczynski.asc | sudo -Hi -u rvm gpg --import -
sudo -Hi -u rvm curl -sSL https://get.rvm.io | sudo -Hi -u rvm bash -s stable
sudo -Hi -u rvm ~rvm/.rvm/bin/rvm autolibs read-fail
sudo -Hi -u rvm ~rvm/.rvm/bin/rvm requirements
sudo -Hi -u rvm ~rvm/.rvm/bin/rvm install 2.7
#sudo -Hi -u oxidized ~oxidized/.rvm/bin/rvm use --default 2.7
sudo -Hi -u rvm ~rvm/.rvm/bin/rvm 2.7 do rvm gemset create oxi-upstream
sudo -Hi -u rvm mkdir ~rvm/src
sudo -Hi -u rvm --chdir ~rvm/src git clone https://github.com/arrjay/oxidized
sudo -Hi -u rvm --chdir ~rvm/src/oxidized git checkout mainline
sudo -Hi -u rvm --chdir ~rvm/src/oxidized ~rvm/.rvm/bin/rvm 2.7@oxi-upstream do gem build
gemfile=(~rvm/src/oxidized/oxidized*gem)
sudo -Hi -u rvm --chdir ~rvm/src/oxidized ~rvm/.rvm/bin/rvm 2.7@oxi-upstream do gem install "${gemfile[0]}"

# cleanup
pkill -9 -u rvm

(cd /home && tar cf /root/rvm.tar rvm)
