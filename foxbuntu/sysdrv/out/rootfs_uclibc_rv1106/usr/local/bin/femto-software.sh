#!/bin/bash
export NCURSES_NO_UTF8_ACS=1
export TERM=screen
export LANG=C.UTF-8

title="Software Manager"
package_dir="/usr/local/bin/packages"
install() {
  dialog --title "$title" --yesno "\nInstalling $1.\n\nProceed?" 10 40
  if [ $? -eq 1 ]; then #if cancel/no
    return 1
  fi
  # Run the installation script, capturing the output and displaying it in real time
  output=$(eval "$package_dir/$1.sh -i 2>&1 | tee /dev/tty")
  install_status=$?  # Capture the exit status of the eval command

  # Check the exit status of the installation command
  if [ $install_status -eq 0 ]; then
    dialog --colors --title "$title" --beep --msgbox "\n\Z2Installation successful!\Zn\n\nDetailed installation info:\n$output" 0 0
  else
    dialog --colors --title "$title" --beep --msgbox "\n\Z1Installation FAILED!\Zn\n\nDetailed installation info:\n$output" 0 0
  fi
}



# build and display package intro, then load package menu
package_intro() {
  dialog --colors --title "$title" --msgbox "\
    $($package_dir/$1.sh -N)\n\
        $(if $package_dir/$1.sh -O | grep -q 'A'; then echo -e "by $($package_dir/$1.sh -A)"; fi)\n\
\n\
$(if $package_dir/$1.sh -O | grep -q 'D'; then echo -e "\n$($package_dir/$1.sh -D)"; fi)\n\
\n\
$(echo "Currently:      " && $package_dir/$1.sh -I && echo "\Zuinstalled\Zn" || echo "\Zunot installed\Zn")\n\
$(if $package_dir/$1.sh -O | grep -q 'L'; then echo -e "\nInstalls to:    \Zu$($package_dir/$1.sh -L)\Zn"; fi)\n\
$(if $package_dir/$1.sh -O | grep -q 'C'; then echo -e "\nConflicts with: \Zu$($package_dir/$1.sh -C)\Zn"; fi)\n\

\n\
An internet connection is required for installation.\n\
$(if $package_dir/$1.sh -O | grep -q 'U'; then echo -e "\nFor more information, visit $($package_dir/$1.sh -U)"; fi)" 0 0
  echo "Loading software menu..."
  package_menu $1
}

package_menu() {
  while true; do
    choice=$(dialog --title "$title" --cancel-label "Back" --menu "$($package_dir/$1.sh -N)" 16 45 5 \
      $(if $package_dir/$1.sh -O | grep -q 'i' && $package_dir/$1.sh -I; then echo "Install x"; fi) \
      $(if $package_dir/$1.sh -O | grep -q 'u' && ! $package_dir/$1.sh -I; then echo "Uninstall x"; fi) \
      $(if $package_dir/$1.sh -O | grep -q 'g' && ! $package_dir/$1.sh -I; then echo "Upgrade x"; fi) \
      $(if $package_dir/$1.sh -O | grep -q 'e' && ! $package_dir/$1.sh -I; then echo "Enable service x"; fi) \
      $(if $package_dir/$1.sh -O | grep -q 'd' && ! $package_dir/$1.sh -I; then echo "Disable service x"; fi) \
      $(if $package_dir/$1.sh -O | grep -q 's' && ! $package_dir/$1.sh -I; then echo "Stop service x"; fi) \
      $(if $package_dir/$1.sh -O | grep -q 'r' && ! $package_dir/$1.sh -I; then echo "Start/restart service x"; fi) \
      "" "" \
      "Back to software manager" "" 3>&1 1>&2 2>&3)
    
    exit_status=$? # This line checks the exit status of the dialog command
    
    if [ $exit_status -ne 0 ]; then # Exit the loop if the user selects "Cancel" or closes the dialog
      break
    fi
    
    case $choice in
      "Install") install $1 ;;
      "Uninstall") eval "$package_dir/$1.sh -u" ;;
      "Upgrade") eval "$package_dir/$1.sh -g" ;;
      "Enable service") eval "$package_dir/$1.sh -e" ;;
      "Disable service") eval "$package_dir/$1.sh -d" ;;
      "Stop service") eval "$package_dir/$1.sh -s" ;;
      "Start/restart service") eval "$package_dir/$1.sh -r" ;;
      "Back to software manager") break ;;
    esac
  done
}


while true; do
title="$title"
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