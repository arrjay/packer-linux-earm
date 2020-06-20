#!/usr/bin/env bash

set -e

# copy stable host keys to image
ln -s /dev/null /etc/systemd/system/regenerate_ssh_host_keys.service
#mv /tmp/gloves/ssh_host_*_key /etc/ssh
#chmod 0600 /etc/ssh/ssh_host_*_key
#for k in /etc/ssh/ssh_host_*_key ; do
#  [[ -f $k ]] && ssh-keygen -y -f $k > $k.pub
#done

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
printf '%s\n' 'trowel' > /etc/hostname

# configure dterm
#echo 'tractor: ttyUSB0' >> /etc/dtermrc

# flip the screen - trowel is mounted "upside down"
echo 'lcd_rotate=2' >> /boot/config.txt
