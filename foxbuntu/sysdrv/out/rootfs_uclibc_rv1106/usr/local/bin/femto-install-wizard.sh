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

    femto-meshtasticd-lora-dialogs.sh -w

    # public key
    loading "Getting current public key..."
    key=$(femto-meshtasticd-config.sh -u)
    if [ -n "$key" ]; then
      dialog --no-collapse --title "Meshtastic public key" --yesno "Current public key:\n$key\n\nSet new key?" 9 55
      if [ $? -eq 0 ]; then #unless cancel/no
        key=$(dialog --no-collapse --title "Meshtastic public key" --inputbox "New Meshtastic public key (SHIFT+INS to paste):" 8 60 3>&1 1>&2 2>&3)
        if [ $? -eq 0 ]; then #unless cancel/no
          loading "Sending command..."
          dialog --no-collapse --colors --title "Meshtastic public key" --msgbox "$(femto-meshtasticd-config.sh -U "$key" && echo -e "\n\Z4Command successful!\Zn\n" || echo -e "\n\Z1Command failed.\Zn\n")" 0 0
        fi
      fi
    else
      dialog --no-collapse --colors --title "Meshtastic public key" --msgbox "\Z1Failed to communicate with Meshtasticd.\Zn\n\nIs the service running?\n" 0 0
    fi

    # private key
    loading "Getting current private key..."
    key=$(femto-meshtasticd-config.sh -u)
    if [ -n "$key" ]; then
      dialog --no-collapse --title "Meshtastic private key" --yesno "Current private key:\n$key\n\nSet new key?" 9 55
      if [ $? -eq 0 ]; then #unless cancel/no
        key=$(dialog --no-collapse --title "Meshtastic private key" --inputbox "New Meshtastic private key (SHIFT+INS to paste):" 8 60 3>&1 1>&2 2>&3)
        if [ $? -eq 0 ]; then #unless cancel/no
          loading "Sending command..."
          dialog --no-collapse --colors --title "Meshtastic private key" --msgbox "$(femto-meshtasticd-config.sh -R "$key" && echo -e "\n\Z4Command successful!\Zn\n" || echo -e "\n\Z1Command failed.\Zn\n")" 0 0
        fi
      fi
    else
      dialog --no-collapse --colors --title "Meshtastic private key" --msgbox "\Z1Failed to communicate with Meshtasticd.\Zn\n\nIs the service running?\n" 0 0
    fi

    key=$(dialog --title "Meshtastic admin key" --cancel-label "Skip" --inputbox "Enter Meshtastic admin key (optional). If 3 admin keys are already in Meshtastic, more will be ignored.\n(SHIFT+INS to paste):" 11 50 3>&1 1>&2 2>&3)
    if [ -n "$key" ]; then #if a URL was entered
      loading "Sending key..."
      dialog --no-collapse --colors --title "Meshtastic URL" --msgbox "$(femto-meshtasticd-config.sh -A "$key" && echo -e "\n\Z4Command successful!\Zn\n" || echo -e "\n\Z1Command failed.\Zn\n")" 0 0
    fi

    femto-config -L # legacy admin menu
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