#!/bin/bash
log_message() {
  echo -e "\e[32mFirst boot\e[0m: $1"  # Echo to the screen
  logger "First boot: $1"  # Log to the system log
}

if ! systemctl is-enabled femto-runonce &>/dev/null; then # if not the first boot

  who | grep -q . || exit 0 # if not logged in, exit script. May not deal well with future web UI

  # prevents weirdness over tty
  export NCURSES_NO_UTF8_ACS=1
  export TERM=xterm-256color
  export LANG=C.UTF-8
  dialog --title "Femtofox run once utility" --yesno "\
This does not appear to be this system's first boot.\n\
\n\
Re-running this script will:\n\
* Resize filesystem to fit the SD card\n\
* Allocate the swap file\n\
* Replace the SSH encryption keys\n\
* Replace the Web Terminal SSL encryption keys\n\
* Set the eth0 MAC to be derivative of CPU serial number\n\
* Add terminal type to user femto's .bashrc\n\
* Add a shortcut \`sfc\` to user femto's .bashrc\n\
* Enable the meshtasticd service\n\
* Add compiler support\n\
\n\
Finally, the Femtofox will reboot.\n\
\n\
Re-running this script after first boot should not cause any harm, but may not work as expected.\n\
\n\
Proceed?" 24 60
  if [ $? -eq 1 ]; then #if cancel/no
    exit 0
  fi
fi

echo -e "\e[32m******* First boot *******\e[0m"

# pulse LED during firstboot
(
  while true; do
    echo 1 > /sys/class/gpio/gpio34/value;
    sleep 0.5;
    echo 0 > /sys/class/gpio/gpio34/value;
    sleep 0.5;
  done
) &

# Perform filesystem resize
log_message "Resizing filesystem..."
resize2fs /dev/mmcblk1p5
resize2fs /dev/mmcblk1p6
resize2fs /dev/mmcblk1p7
log_message "Resizing filesystem complete"

	# allocate swap file
if [ ! -f /swapfile ]; then # check if swap file already exists
	log_message "Allocating swap file..."
  fallocate -l 1G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile > /dev/null
  swapon /swapfile > /dev/null
  echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab > /dev/null
  log_message "Swap file allocated."
else
	log_message "Swap file already allocated, skipping"
fi

# prevent randomized mac address for eth0. If `eth0`` is already present in /etc/network/interfaces, skip
mac="$(awk '/Serial/ {print $3}' /proc/cpuinfo | tail -c 11 | sed 's/^\(.*\)/a2\1/' | sed 's/\(..\)/\1:/g;s/:$//')"
file="/etc/network/interfaces"
if ! grep -q "    hwaddress ether $mac" "$file"; then
  log_message "Setting eth0 MAC address to $mac (derivative of CPU s/n)"
  awk -v mac="$mac" '
    { print }
    /allow-hotplug eth0/ { count=5 }
    count && --count == 0 { print "    hwaddress ether " mac }
  ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
else
  log_message "eth0 mac address already set in /etc/network/interfaces, skipping"
fi

# Add term stuff to .bashrc
lines="export NCURSES_NO_UTF8_ACS=1
export TERM=xterm-256color
export LANG=C.UTF-8"
if ! grep -Fxq "$lines" /home/femto/.bashrc; then # Check if the lines are already in .bashrc
  echo "$lines" >> /home/femto/.bashrc
  log_message "Added TERM, LANG and NCURSES_NO_UTF8_ACS to .bashrc"
else
  log_message "TERM, LANG and NCURSES_NO_UTF8_ACS already present in .bashrc, skipping"
fi

# Fix Compiler
cp /usr/lib/arm-linux-gnueabihf/libc_nonshared.a.keep /usr/lib/arm-linux-gnueabihf/libc_nonshared.a
log_message "Added compiler support"

# Add a cheeky alias to .bash_aliases
if ! grep -Fxq "alias sfc='sudo femto-config'" /home/femto/.bashrc; then # Check if the lines are already in .bash_aliases
  echo "alias sfc='sudo femto-config'" >> /home/femto/.bashrc
  log_message "Added \`alias sfc='sudo femto-config'\` to .bashrc"
else
  log_message "\`alias sfc='sudo femto-config'\` already present in .bashrc, skipping"
fi

log_message "Enabling meshtasticd service"
systemctl enable meshtasticd

#generate SSH keys
log_message "Generating new SSH encryption keys. This can take a couple minutes..."
femto-utils.sh -E

#generate ttyd SSL keys
log_message "Generating new Web Terminal (ttyd) SSL encryption keys. This can take a couple minutes..."
/usr/local/bin/packages/ttyd.sh -k
log_message "Enabling Web Terminal (ttyd) service..."
systemctl enable ttyd

# remove first boot flag
systemctl disable femto-runonce
log_message "Disabled first boot service and rebooting in 5 seconds..."
sleep 5
reboot
