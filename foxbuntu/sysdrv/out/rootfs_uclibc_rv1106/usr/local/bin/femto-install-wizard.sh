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

  dialog --title "$title" --cancel-label "Skip" --yesno "\nConfigure network settings?" 8 40
  if [ $? -eq 0 ]; then #unless cancel/no
    new_hostname=$(dialog --title "$title" --cancel-label "Skip" --inputbox "Enter hostname:" 8 40 $(hostname) 3>&1 1>&2 2>&3)
    if [ $? -eq 0 ]; then #unless cancel/no
      femto-network-config.sh -n "$new_hostname"
      dialog --title "$title" --msgbox "\nFemtofox is now reachable at\n$new_hostname.local" 8 40
    fi
  
    femto-config -w
  fi

  dialog --title "$title" --cancel-label "Skip" --yesno "\nConfigure Meshtastic?" 8 40
  if [ $? -eq 0 ]; then #unless cancel/no
    femto-config -l #set lora radio model
    
    newurl=$(dialog --title "Meshtastic URL" --inputbox "New Meshtasticd URL (SHIFT+INS to paste):" 8 60 3>&1 1>&2 2>&3)
    if [ -n "$newurl" ]; then #if a URL was entered
      loading "Sending URL..."
      dialog --no-collapse --colors --title "Meshtastic URL" --msgbox "$(femto-meshtasticd-config.sh -q "$newurl" && echo -e "\n\Z4Command successful!\Zn\n" || echo -e "\n\Z1Command failed.\Zn\n")" 0 0
    fi

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

    key=$(dialog --title "$title" --cancel-label "Skip" --inputbox "Enter Meshtastic admin key (optional). If 3 admin keys are already in Meshtastic, more will be ignored.\n(SHIFT+INS to paste):" 11 50 3>&1 1>&2 2>&3)
    if [ -n "$key" ]; then #if a URL was entered
      loading "Sending key..."
      dialog --no-collapse --colors --title "Meshtastic URL" --msgbox "$(femto-meshtasticd-config.sh -A "$key" && echo -e "\n\Z4Command successful!\Zn\n" || echo -e "\n\Z1Command failed.\Zn\n")" 0 0
    fi

    dialog --no-collapse --infobox "Getting current legacy admin state..." 5 45
    state=$(sudo femto-meshtasticd-config.sh -p)
    if echo "$state" | grep -q "enabled"; then # poor man's replace ansi colors
      state="\Z4enabled\Zn"
    elif echo "$state" | grep -q "disabled"; then
      state="\Z1disabled\Zn"
    elif echo "$state" | grep -q "error"; then
      state="\Z1error\Zn"
    fi
    while true; do
      choice=$(dialog --no-collapse --colors --cancel-label "Skip" --title "Meshtasticd Legacy Admin" --menu "Current state: $state" 12 40 5 \
        1 "Enable" \
        2 "Disable (default)" \
        "" "" \
        3 "Skip" 3>&1 1>&2 2>&3)
      exit_status=$? # This line checks the exit status of the dialog command
      if [ $exit_status -ne 0 ]; then # Exit the loop if the user selects "Cancel" or closes the dialog
        break
      fi
      case $choice in
        1) # enable legacy admin)
          dialog --no-collapse --infobox "Sending command..." 5 45
          dialog --no-collapse --colors --title "$title" --msgbox "$(femto-meshtasticd-config.sh -o "true" && echo -e "\n\Z4Command successful!\Zn\n" || echo -e "\n\Z1Command failed.\Zn\n")" 0 0
          break
        ;;
        2) # disable legacy admin)
          dialog --no-collapse --infobox "Sending command..." 5 45
          dialog --no-collapse --colors --title "$title" --msgbox "$(femto-meshtasticd-config.sh -o "false" && echo -e "\n\Z4Command successful!\Zn\n" || echo -e "\n\Z1Command failed.\Zn\n")" 0 0
          break
        ;;
        3) break ;;
      esac
    done
  fi

  dialog --title "$title" --msgbox "\nSetup wizard complete!" 8 40
}

dialog --title "$title" --yesno "\
The install wizard will allow you to configure all the basic settings necessary to run your Femtofox.\n\
\n\
Running this wizard will overwrite some current settings.\n\n\
Proceed?" 13 50
if [ $? -eq 0 ]; then #unless cancel/no
  wizard
fi