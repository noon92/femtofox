#!/bin/bash
export NCURSES_NO_UTF8_ACS=1
export TERM=screen
export LANG=C.UTF-8

# build and display package intro, then load package menu
package_intro() {
  dialog --title "$software" --msgbox "\
    $(/usr/local/bin/software/$1.sh -N)\n\
        $(if /usr/local/bin/software/$1.sh -O | grep -q 'A'; then echo -e "by $(/usr/local/bin/software/$1.sh -A)"; fi)\n\
\n\
$(if /usr/local/bin/software/$1.sh -O | grep -q 'D'; then echo -e "\n$(/usr/local/bin/software/$1.sh -D)"; fi)\n\
\n\
An internet connection is required for installation.\n\
$(if /usr/local/bin/software/$1.sh -O | grep -q 'U'; then echo -e "\nFor more information, visit $(/usr/local/bin/software/$1.sh -U)"; fi)
" 0 0
  echo "Loading software menu..."
  package_menu $1
}

package_menu() {
  while true; do
    choice=$(dialog --title "Software" --cancel-label "Back" --menu "$(/usr/local/bin/software/$1.sh -N)" 16 45 5 \
      $(if /usr/local/bin/software/$1.sh -O | grep -q 'i'; then echo "Install x"; fi) \
      $(if /usr/local/bin/software/$1.sh -O | grep -q 'u'; then echo "Uninstall x"; fi) \
      $(if /usr/local/bin/software/$1.sh -O | grep -q 'g'; then echo "Upgrade x"; fi) \
      $(if /usr/local/bin/software/$1.sh -O | grep -q 'e'; then echo "Enable service x"; fi) \
      $(if /usr/local/bin/software/$1.sh -O | grep -q 'd'; then echo "Disable service x"; fi) \
      $(if /usr/local/bin/software/$1.sh -O | grep -q 's'; then echo "Stop service x"; fi) \
      $(if /usr/local/bin/software/$1.sh -O | grep -q 'r'; then echo "Start/restart service x"; fi) \
      "" "" \
      "Exit" "" 3>&1 1>&2 2>&3)
    
    exit_status=$? # This line checks the exit status of the dialog command
    
    if [ $exit_status -ne 0 ]; then # Exit the loop if the user selects "Cancel" or closes the dialog
      break
    fi
    
    case $choice in
      "Install") eval "/usr/local/bin/software/$1.sh -i" ;;
      "Uninstall") eval "/usr/local/bin/software/$1.sh -u" ;;
      "Upgrade") eval "/usr/local/bin/software/$1.sh -g" ;;
      "Enable service") eval "/usr/local/bin/software/$1.sh -e" ;;
      "Disable service") eval "/usr/local/bin/software/$1.sh -d" ;;
      "Stop service") eval "/usr/local/bin/software/$1.sh -s" ;;
      "Start/restart service") eval "/usr/local/bin/software/$1.sh -r" ;;
      "Back") break ;;
    esac
  done
}


while true; do
title="Software"
  option=""
  option=$(dialog --cancel-label "Back" --menu "$title" 0 0 6 \
    1 "Meshing Around by Spud" \
    2 "The Comms Channel BBS, TC²BBS" \
    3 "Curses Client for Meshtastic" \
    4 "Mosquitto MQTT broker" \
    5 "GPS and Telemetry" \
    "" ""\
    6 "Back to Main Menu" 3>&1 1>&2 2>&3)
  
  exit_status=$? # This line checks the exit status of the dialog command
  if [ $exit_status -ne 0 ]; then # Exit the loop if the user selects "Cancel" or closes the dialog
    break
  fi
  
  case $option in
    1) package_intro "meshing_around" ;;
    2) package_intro "tc2_bbs" ;;
    3) curses_client ;;
    4) mosquitto ;;
    5) gpsd ;;
    6) break ;;
  esac
done

exit 0