#!/bin/bash
log_message() {
  echo "First boot: $1"  # Echo to the screen
  logger "First boot: $1"  # Log to the system log
}

if [ ! -e "/etc/.firstboot" ]; then
  # prevents weirdness over tty
  export NCURSES_NO_UTF8_ACS=1
  export TERM=xterm-256color
  export LANG=C.UTF-8
  dialog --title "Femtofox run once utility" --yesno "\
This does not appear to be this system's first boot.\n\
Re-running this script will restore RTC support, set the Meshtastic nodeid and eth0 MAC address to be derivative of the CPU serial number, set the Meshtastic wifi status to \`enabled\` and then reboot.\n\
\n\
Re-running this script after first boot should not cause any harm, but may not work as expected.\n\
\n\
Proceed?" 14 60
  if [ $? -eq 1 ]; then #if cancel/no
    exit 1
  fi
fi

# Perform filesystem resize
  sudo resize2fs /dev/mmcblk1p5
  sudo resize2fs /dev/mmcblk1p6
  log_message "Resizing /dev/mmcblk1p7 can take up to 10 minutes, depending on microSD card size and speed."
  sudo resize2fs /dev/mmcblk1p7

	# allocate swap file
if [ ! -f /etc/.filesystem_swap ]; then # check if swap file already exists
  sudo fallocate -l 1G /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile > /dev/null
  sudo swapon /swapfile > /dev/null
  echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab > /dev/null
  touch /etc/.filesystem_swap
  log_message "Swap file allocated."
else
	log_message "Swap file already allocated, skipping."
fi

# add RTC support
bash -c 'echo ds1307 0x68 > /sys/class/i2c-adapter/i2c-3/new_device'
log_message "Added ds1307/ds3231 RTC support."

# prevent randomized mac address for eth0. If `eth0`` is already present in /etc/network/interfaces, skip
if ! grep -q "eth0" /etc/network/interfaces; then
  log_message "Setting eth0 MAC address to derivative of CPU s/n."
  cat <<EOF >> /etc/network/interfaces
# static mac address for onboard ethernet (castellated pins)
allow-hotplug eth0
iface eth0 inet dhcp
hwaddress ether $(awk '/Serial/ {print $3}' /proc/cpuinfo | tail -c 11 | sed 's/^\(.*\)/a2\1/' | sed 's/\(..\)/\1:/g;s/:$//')
EOF
else
  log_message "eth0 already exists in /etc/network/interfaces, skipping."
fi

# set meshtastic nodeid to derivative of CPU serial number (unique to this board)
seed=$(sed -n '/Serial/ s/^.*: \(.*\)$/\U\1/p' /proc/cpuinfo | bc | tail -c 9)
#seed=$((0x$(awk '/Serial/ {print $3}' /proc/cpuinfo) & 0x3B9AC9FF)) #alternate method for generating seed - not in use
sed -i "s|^ExecStart=/usr/sbin/meshtasticd.*|ExecStart=/usr/sbin/meshtasticd -h $seed|" /usr/lib/systemd/system/meshtasticd.service
log_message "Using Luckfox CPU S/N to generate nodeid for Meshtastic."
systemctl daemon-reload
systemctl enable meshtasticd
systemctl restart meshtasticd

# remove first boot flag
rm /etc/.firstboot
log_message "Removing first boot flag and rebooting in 5 seconds..."
sleep 5
reboot