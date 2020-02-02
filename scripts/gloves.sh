#!/usr/bin/env bash

set -e

# copy stable host keys to image
ln -s /dev/null /etc/systemd/system/regenerate_ssh_host_keys.service
mv /tmp/gloves/ssh_host_*_key /etc/ssh
chmod 0600 /etc/ssh/ssh_host_*_key
for k in /etc/ssh/ssh_host_*_key ; do
  [[ -f $k ]] && ssh-keygen -y -f $k > $k.pub
done

# configure ups drivers
cat <<_EOF_> /etc/nut/ups.conf
maxretry = 3

[a]
  driver = usbhid-ups
  port = auto
_EOF_

# configure ups monitoring
read -r upw < /root/upsd-pw

cat <<_EOF_> /etc/nut/upsmon.conf

# upsen to monitor
MONITOR a@localhost 1 root $upw master
# there is no b supply

# system is _on_ the ups
MINSUPPLIES 1

SHUTDOWNCMD "/sbin/shutdown -h +0"

# shove _everything through upssched
NOTIFYCMD /sbin/upssched

POLLFREQ 3

POLLFREQALERT 3

HOSTSYNC 15

DEADTIME 10

POWERDOWNFLAG /etc/killpower

# only call upssched and let it handle the rest
NOTIFYFLAG ONLINE EXEC
NOTIFYFLAG ONBATT EXEC
NOTIFYFLAG LOWBATT EXEC
NOTIFYFLAG FSD EXEC
NOTIFYFLAG COMMOK EXEC
NOTIFYFLAG COMMBAD EXEC
NOTIFYFLAG SHUTDOWN EXEC
NOTIFYFLAG REPLBATT EXEC
NOTIFYFLAG NOCOMM EXEC
NOTIFYFLAG NOPARENT EXEC

RBWARNTIME 43200

NOCOMMWARNTIME 300

FINALDELAY 5
_EOF_

# detour to tmpfiles.d to make the /var/run/nut/upssched directory
cat <<_EOF_> /etc/tmpfiles.d/upssched.conf
D /run/nut/upssched 0700 nut nut - -
_EOF_

# sudo to allow upsdrvctl from nut
cat <<_EOF_ > /etc/sudoers.d/030_nut
nut ALL=(root) NOPASSWD: /sbin/upsdrvctl
_EOF_
chmod 0440 /etc/sudoers.d/030_nut

# upssched command script
cat <<_EOF_ > /usr/local/bin/upssched-cmd
#!/usr/bin/env bash

case \$1 in
        kick-ups-*)
		ups="\${1#kick-ups-}"
		sudo -u root /sbin/upsdrvctl stop \$ups
		sudo -u root /sbin/upsdrvctl start \$ups
		;;
	upsgone)
		logger -t upssched-cmd "The UPS has been gone for awhile"
		;;
	*)
		logger -t upssched-cmd "Unrecognized command: \$1"
		;;
esac
_EOF_
chown nut:nut /usr/local/bin/upssched-cmd
chmod 0500 /usr/local/bin/upssched-cmd

cat <<_EOF_> /etc/nut/upssched.conf
# hand this script...whatever
CMDSCRIPT /usr/local/bin/upssched-cmd

# locking
PIPEFN /run/nut/upssched/upssched.pipe
LOCKFN /run/nut/upssched/upssched.lock

# basically, we abuse upssched to restart the hid drivers should they peace out.
AT COMMBAD a@localhost EXECUTE kick-ups-a
AT NOCOMM a@localhost EXECUTE kick-ups-a
_EOF_

# set the hostname
printf '%s\n' 'gloves' > /etc/hostname

# configure networking flags
sed -i -e 's/$/ ut_skip_br ut_br_ninf/' /boot/cmdline.txt

# create gloves user
u=gloves

groupadd $u
useradd -g $u $u
rsync -a /etc/skel/ /home/$u/

# tell lightdm to log in automatically
mkdir -p /etc/lightdm/lightdm.conf.d
printf '[SeatDefaults]\nautologin-user=%s\n' $u > /etc/lightdm/lightdm.conf.d/autologin.conf

# disable light-locker
mkdir -p /home/$u/.config/autostart
printf '[Desktop Entry]\nHidden=true\n' > /home/$u/.config/autostart/light-locker.desktop
chown -R $u:$u /home/$u

# install synergy
dpkg -i /tmp/synergy.deb || true
apt-get install -qq -y -f

# configure synergy key
read sk < /tmp/gloves/synergy_key
mkdir -p /home/$u/.config/Synergy
cat <<_EOF_>/home/$u/.config/Synergy/Synergy.conf
[General]
serialKey=$sk
startedBefore=true
_EOF_
chown -R $u:$u /home/$u

# create use for ssh tunneling of synergy
u=tunnel
groupadd $u
useradd -g $u $u
mkdir -p /home/$u/.ssh

# restrict this user to allow the synergy port, 24800 via ssh authorized_key wrangling
p=24800
while read -r t k r ; do
  case $t in ssh-*) : ;; *) continue ;; esac
  printf 'command="/bin/true",restrict,port-forwarding,permitopen="localhost:%s",permitopen="127.0.0.1:%s" %s %s %s\n' $p $p $t $k $r > /home/$u/.ssh/authorized_keys
done < /tmp/gloves/sshpub_tunnel_keys

chown -R $u:$u /home/$u

# configure dterm
echo 'tractor: ttyUSB0'
