#!/bin/bash
log_message() {
  echo "USB config: $1"  # Echo to the screen
  logger "USB config: $1"  # Log to the system log
}

if [ ! -e "/usr/local/bin/.firstboot" ]; then
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
    

# resize filesystem to fill partition
/usr/bin/filesystem_resize.sh

# add RTC support
bash -c 'echo ds1307 0x68 > /sys/class/i2c-adapter/i2c-3/new_device'
log_message "First boot: Added RTC support."

# prevent randomized mac address for eth0. If `eth0`` is already present in /etc/network/interfaces, skip
if ! grep -q "eth0" /etc/network/interfaces; then
  log_message "First boot: Setting eth0 MAC address to derivative of CPU s/n."
  echo "$msg"
  logger "$msg"
  cat <<EOF >> /etc/network/interfaces
# static mac address for onboard ethernet (castellated pins)
allow-hotplug eth0
iface eth0 inet dhcp
hwaddress ether $(awk '/Serial/ {print $3}' /proc/cpuinfo | tail -c 11 | sed 's/^\(.*\)/a2\1/' | sed 's/\(..\)/\1:/g;s/:$//')
EOF
else
  log_message "First boot: eth0 already exists in /etc/network/interfaces."
  echo "$msg"
  logger "$msg"
fi

# set meshtastic nodeid to derivative of CPU serial number (unique to this board)
seed=$(sed -n '/Serial/ s/^.*: \(.*\)$/\U\1/p' /proc/cpuinfo | bc | tail -c 9)
#seed=$((0x$(awk '/Serial/ {print $3}' /proc/cpuinfo) & 0x3B9AC9FF)) #alternate method for generating seed - not in use
sed -i "s|^ExecStart=/usr/sbin/meshtasticd.*|ExecStart=/usr/sbin/meshtasticd -h $seed|" /usr/lib/systemd/system/meshtasticd.service
log_message "First boot: Using Luckfox CPU S/N to generate nodeid for Meshtastic."
systemctl daemon-reload
systemctl enable meshtasticd
systemctl restart meshtasticd

# enable wifi in meshtastic settings. Because this is very important, we'll try 10 times.
log_message "First boot: Enabling wifi setting in Meshtasticd."
/usr/local/bin/femto-meshtasticd-config.sh -m "--set network.wifi_enabled true" 10 "First boot"

# remove first boot flag
rm /usr/local/bin/.firstboot
log_message "First boot: Removing first boot flag and rebooting in 5 seconds..."
sleep 5
reboot