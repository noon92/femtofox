#!/bin/bash
export NCURSES_NO_UTF8_ACS=1
export TERM=xterm-256color
export LANG=C.UTF-8

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root."
  echo "Try \`sudo femto-install-wizard\`."
  exit 1
fi

loading() {
  dialog --no-collapse --infobox "$1" 5 45
}

title="Install Wizard"

wizard() {

  femto-set-time.sh

  new_hostname=$(dialog --title "Hostname" --cancel-label "Skip" --inputbox "Enter hostname:" 8 40 $(hostname) 3>&1 1>&2 2>&3)
  if [ $? -eq 0 ]; then #unless cancel/no
    femto-network-config.sh -n "$new_hostname"
    dialog --title "Hostname" --msgbox "\nFemtofox is now reachable at\n$new_hostname.local" 8 40
  fi

  dialog --title "$title" --cancel-label "Skip" --yesno "Configure Wi-Fi settings?" 6 40
  if [ $? -eq 0 ]; then #unless cancel/no
    femto-config -w
  fi

  dialog --title "$title" --cancel-label "Skip" --yesno "Configure Meshtastic?" 6 40
  if [ $? -eq 0 ]; then #unless cancel/no
    femto-meshtasticd-lora-dialogs.sh
  fi

  dialog --title "$title" --msgbox "Setup wizard complete!" 6 40
}

dialog --title "$title" --yesno "\
The install wizard will allow you to configure all the settings necessary to run your Femtofox.\n\
\n\
The wizard takes several minutes to complete and will overwrite some current settings.\n\n\
Proceed?" 12 60
if [ $? -eq 0 ]; then #unless cancel/no
  wizard
fi