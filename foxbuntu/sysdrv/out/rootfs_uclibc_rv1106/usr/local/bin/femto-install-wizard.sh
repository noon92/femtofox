#!/bin/bash
export NCURSES_NO_UTF8_ACS=1
export TERM=xterm-256color
export LANG=C.UTF-8

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root."
  echo "Try \`sudo femto-install-wizard\`."
  exit 1
fi

# pause
pause() {
  echo "Press any key to continue..."
  read -n 1 -s -r
}

title="Install Wizard"

wizard() {

  femto-set-time.sh

  new_hostname=$(dialog --title "$title" --cancel-label "Skip" --inputbox "Enter hostname:" 8 40 $(hostname) 3>&1 1>&2 2>&3)
  if [ $? -eq 0 ]; then #unless cancel/no
    femto-network-config.sh -n "$new_hostname"
    dialog --title "$title" --msgbox "\nFemtofox is now reachable at\n$new_hostname.local" 8 40
  fi

  dialog --title "$title" --cancel-label "Skip" --yesno "\nConfigure Wi-Fi settings?" 8 40
  if [ $? -eq 0 ]; then #unless cancel/no
    femto-config -w
  fi

  dialog --title "$title" --cancel-label "Skip" --yesno "\nConfigure Meshtastic?" 8 40
  if [ $? -eq 0 ]; then #unless cancel/no
    newurl=$(dialog --title "Meshtastic URL" --cancel-label "Skip" --inputbox "New Meshtasticd URL (SHIFT+INS to paste):" 8 50 3>&1 1>&2 2>&3)
    if [ -n "$newurl" ]; then #if a URL was entered
      femto-meshtasticd-config.sh -q "$newurl"
      pause
    fi

    femto-config -l

    key=$(dialog --title "$title" --cancel-label "Skip" --inputbox "Enter Meshtastic admin key (optional). If 3 admin keys are already in Meshtastic, more will be ignored.\n(SHIFT+INS to paste):" 11 50 3>&1 1>&2 2>&3)
    if [ -n "$key" ]; then #if a URL was entered
      femto-meshtasticd-config.sh -a "$key"
      pause
    fi
    
    while true; do
      choice=$(dialog --title "$title" --cancel-label "Skip" --menu "Enable/disable Meshtastic Legacy admin channel?" 12 40 5 \
        1 "Enable" \
        2 "Disable (default)" \
        "" "" \
        3 "Skip" 3>&1 1>&2 2>&3)
      
      exit_status=$? # This line checks the exit status of the dialog command
      
      if [ $exit_status -ne 0 ]; then # Exit the loop if the user selects "Cancel" or closes the dialog
        break
      fi
      
      case $choice in
        1) femto-meshtasticd-config.sh -o "true" && break ;;
        2) femto-meshtasticd-config.sh -o "false" && break ;;
        3) break ;;
        *) dialog --msgbox "Invalid choice, please try again." 8 40 ;;
      esac
    done
  fi

  dialog --title "$title" --msgbox "\nSetup wizard complete!" 8 40
}

dialog --title "$title" --yesno "\
The install wizard will allow you to configure all the settings necessary to run your Femtofox.\n\
\n\
Running this wizard will overwrite some current settings.\n\
Proceed?" 0 0
if [ $? -eq 0 ]; then #unless cancel/no
  wizard
fi