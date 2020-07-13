#!/bin/sh

set -e

AWS_DEFAULT_REGION=us-west-2
PFSRC=/tmp/packer-files

# https://docs.aws.amazon.com/systems-manager/latest/userguide/ssm-agent.html
u=ssm-user

# precreate ssm-user and add to some groups
groupadd $u
useradd -g $u $u
passwd -l $u

for g in systemd-journal ; do
  usermod -a -G $g $u
done

# preconfigure sudoers
rm -f /etc/sudoers.d/ssm-agent-users
printf '%s ALL=(ALL) NOPASSWD: ALL\n' $u > /etc/sudoers.d/ssm-agent-users
chmod 0440 /etc/sudoers.d/ssm-agent-users

# install ssm-agent
case "$(dpkg --print-architecture)" in
  armhf)
    curl -L -o /tmp/amazon-ssm-agent.deb https://s3.$AWS_DEFAULT_REGION.amazonaws.com/amazon-ssm-$AWS_DEFAULT_REGION/latest/debian_arm/amazon-ssm-agent.deb
  ;;
  armel)
    [ -f "${PFSRC}/cache/amazon-ssm-agent.armel.deb" ] && cp "${PFSRC}/cache/amazon-ssm-agent.armel.deb" /tmp/amazon-ssm-agent.deb
  ;;
esac

[ -f /tmp/amazon-ssm-agent.deb ] && {
  dpkg -i /tmp/amazon-ssm-agent.deb || true
  apt-get install -f
}
