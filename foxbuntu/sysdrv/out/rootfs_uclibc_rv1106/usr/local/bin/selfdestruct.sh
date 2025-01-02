#!/bin/bash
echo ""
echo "------- Start at $(date). ~8m -------"

systemctl stop meshtasticd
rm -rf /etc/meshtasticd
rm /etc/wpa_supplicant/wpa_supplicant.conf

# Clear dmesg Log
dmesg -C

# Clear Shell History
rm ~/.bash_history
history -c && history -w

# Clear Temporary Files
rm -rf /tmp/*
rm -rf /var/tmp/*

# Stop BBS service and clear log
systemctl stop mesh-bbs.service

# Clear Package Cache
apt-get -y autoremove
apt-get -y clean
apt-get -y autoclean

# Clear caches
rm -rf ~/.cache/*
rm -rf /var/cache/*

# Clear DHCP Leases
rm -f /var/lib/dhcp/dhclient.leases

# Clear Udev Cache
rm -rf /etc/udev/rules.d/70-persistent-*

# Clear System Logs
rm -rf /var/log/*

# Clear Journal Logs
journalctl --rotate
journalctl --vacuum-time=1s

# Clear User-specific Logs
rm -f ~/.xsession-errors*

#Remove Temporary Files in User Directories
rm -rf ~/.local/share/Trash/*

# Remove Kernel and System Debugging Logs
rm -f /var/log/kern.log
rm -f /var/log/debug

# Clear wtmp, btmp, and lastlog
truncate -s 0 /var/log/wtmp
truncate -s 0 /var/log/btmp
truncate -s 0 /var/log/lastlog

# Clear Auth Logs
truncate -s 0 /var/log/auth.log

# Clear Other Specific Logs
truncate -s 0 /var/log/syslog
truncate -s 0 /var/log/daemon.log
truncate -s 0 /var/log/messages

rm /usr/local/bin/*

echo "------- Start zeroing at $(date). ~5 mins."
dd if=/dev/zero of=~/delete_me
echo "------- Done  zeroing at $(date)-------"
sync
sync
echo "------- Delete dummy file -------"
rm -f ~/delete_me
sync
sync
fstrim -v /
echo "-------Finish zeroing at $(date)-------"
echo ""

# Clear dmesg Log
dmesg -C

history -c && history -w
reboot