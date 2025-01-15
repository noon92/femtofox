#!/bin/bash

title="Software Manager"
package_dir="/usr/local/bin/packages"

install() {
  dialog --title "$title" --yesno "\nInstall $($package_dir/$1.sh -N)\n\nProceed?" 10 40
  if [ $? -eq 1 ]; then #if cancel/no
    return 1
  fi
  echo "Installing $($package_dir/$1.sh -N)..."
  # Run the installation script, capturing the output and displaying it in real time
  output=$($package_dir/$1.sh -i)
  echo $output
  install_status=$?  # Capture the exit status of the eval command
  user_message=$(echo "$output" | awk '/user_message: / {found=1; split($0, arr, "user_message: "); print arr[2]; next} found {print}' | sed '/^$/q') # grab the user_message, if present
  #output=$(echo -e "$output" | sed '/user_message: /,$d') # remove the user message from the detailed output

  if [ $install_status -eq 0 ]; then # if the installation was successful
    dialog --colors --title "$title" --beep --msgbox "\n\ZuInstallation of $($package_dir/$1.sh -N) successful!\Zn$([ -n "$user_message" ] && echo "\n\n$user_message")\n\nLog:\n$(echo $output)" 0 0 # if there's a user_message, display it with two preceeding line breaks
  else
    dialog --colors --title "$title" --beep --msgbox "\n\ZuInstallation of $($package_dir/$1.sh -N) FAILED!\Zn\n\n$user_message\n\nLog:\n$(echo -e $output)" 0 0 # if there's a user_message, display it with two preceeding line breaks
  fi
}

uninstall() {
  dialog --title "$title" --yesno "\nUninstall $1\n\nProceed?" 10 40
  if [ $? -eq 1 ]; then #if cancel/no
    return 1
  fi
  echo "Uninstalling $($package_dir/$1.sh -N)..."
  output=$(eval "$package_dir/$1.sh -u 2>&1 | tee /dev/tty")
  install_status=$?  # Capture the exit status of the eval command
  user_message=$(echo "$output" | awk '/user_message: / {found=1; split($0, arr, "user_message: "); print arr[2]; next} found {print}' | sed '/^$/q') # grab the user_message, if present
  #output=$(echo "$output" | sed '/user_message: /,$d') # remove the user message from the detailed output
  if [ $install_status -eq 0 ]; then # if the installation was successful
    dialog --colors --title "$title" --beep --msgbox "\n\ZuUninstallation of $($package_dir/$1.sh -N) successful!\Zn$([ -n "$user_message" ] && echo "\n\n$user_message")\n\nLog:\n$(echo -e "$output")" 0 0 # if there's a user_message, display it with two preceeding line breaks
  else
    dialog --colors --title "$title" --beep --msgbox "\n\ZuUninstallation of $($package_dir/$1.sh -N) FAILED!\Zn\n\n$user_message\n\nLog:\n$(echo "$output")" 0 0 # if there's a user_message, display it with two preceeding line breaks
  fi  
}

upgrade() {
  dialog --title "$title" --yesno "\nUpgrade $1\n\nProceed?" 10 40
  if [ $? -eq 1 ]; then #if cancel/no
    return 1
  fi
  echo "Upgrading $($package_dir/$1.sh -N)..."
  output=$(eval "$package_dir/$1.sh -g 2>&1 | tee /dev/tty")
  install_status=$?  # Capture the exit status of the eval command
  user_message=$(echo "$output" | awk '/user_message: / {found=1; split($0, arr, "user_message: "); print arr[2]; next} found {print}' | sed '/^$/q') # grab the user_message, if present
  output=$(echo "$output" | sed '/user_message: /,$d') # remove the user message from the detailed output
  if [ $install_status -eq 0 ]; then # if the installation was successful
    dialog --colors --title "$title" --beep --msgbox "\n\ZuUpgrade of $($package_dir/$1.sh -N) successful!\Zn$([ -n "$user_message" ] && echo "\n\n$user_message")\n\nLog:\n$output" 0 0 # if there's a user_message, display it with two preceeding line breaks
  else
    dialog --colors --title "$title" --beep --msgbox "\n\ZuUpgrade of $($package_dir/$1.sh -N) FAILED!\Zn\n\n$user_message\n\nLog:\n$output" 0 0 # if there's a user_message, display it with two preceeding line breaks
  fi  

}


# build and display package intro
package_intro() {
  echo "Loading package info..."
  # check if each field in the package info is supported by the package, and if so get it and insert it into the package info dialog
  dialog --colors --title "$title" --msgbox "\
    $($package_dir/$1.sh -N)\n\
        $(if $package_dir/$1.sh -O | grep -q 'A'; then echo -e "by $($package_dir/$1.sh -A)"; fi)\n\
$(if $package_dir/$1.sh -O | grep -q 'D'; then echo "\n$($package_dir/$1.sh -D)"; fi)\n\
\n\
$(echo "Currently:      " && $package_dir/$1.sh -I && echo "\Zuinstalled\Zn" || echo " \Zunot installed\Zn")\n\
$(if output=$($package_dir/$1.sh -L); [ -n "$output" ]; then echo "Installs to:     \Zu$output\Zn\n"; fi)\
$(if output=$($package_dir/$1.sh -C); [ -n "$output" ]; then echo "Conflicts with:  \Zu$output\Zn\n"; fi)\
An internet connection is required for installation.\n\
$(if $package_dir/$1.sh -O | grep -q 'U'; then echo "\nFor more information, visit $($package_dir/$1.sh -U)"; fi)" 0 0
  package_menu $1 # after user hits "OK", move on to package menu
}

package_menu() {
  while true; do
    echo "Loading package menu..."
    # for each line, check if it's supported by the package, display it if the current install state of the package is appropriate (example: don't display "install" if the package is already installed, don't display "stop service" for a package with no services)
    choice=$(dialog --title "$title" --cancel-label "Back" --menu "$($package_dir/$1.sh -N)" 17 45 5 \
      $(if $package_dir/$1.sh -O | grep -q 'l' && $package_dir/$1.sh -I; then echo "Run software x"; fi) \
      $(if $package_dir/$1.sh -O | grep -q 'i' && ! $package_dir/$1.sh -I; then echo "Install x"; fi) \
      $(if $package_dir/$1.sh -O | grep -q 'u' && $package_dir/$1.sh -I; then echo "Uninstall x"; fi) \
      $(if $package_dir/$1.sh -O | grep -q 'g' && $package_dir/$1.sh -I; then echo "Upgrade x"; fi) \
      $(if $package_dir/$1.sh -O | grep -q 'e' && $package_dir/$1.sh -I; then echo "Enable service x"; fi) \
      $(if $package_dir/$1.sh -O | grep -q 'd' && $package_dir/$1.sh -I; then echo "Disable service x"; fi) \
      $(if $package_dir/$1.sh -O | grep -q 's' && $package_dir/$1.sh -I; then echo "Stop service x"; fi) \
      $(if $package_dir/$1.sh -O | grep -q 'r' && $package_dir/$1.sh -I; then echo "Start/restart service x"; fi) \
      $(if $package_dir/$1.sh -O | grep -q 'S' && $package_dir/$1.sh -I; then echo "Get service status x"; fi) \
      "" "" \
      "Back to software manager" "" 3>&1 1>&2 2>&3)
    
    exit_status=$? # This line checks the exit status of the dialog command
    
    if [ $exit_status -ne 0 ]; then # Exit the loop if the user selects "Cancel" or closes the dialog
      break
    fi
    
    # execute the actual commands
    case $choice in
      "Run software") eval "$package_dir/$1.sh -l" ;;
      "Install") install $1 ;;
      "Uninstall") uninstall $1 ;;
      "Upgrade") upgrade $1 ;;
      "Enable service") eval "$package_dir/$1.sh -e" ;;
      "Disable service") eval "$package_dir/$1.sh -d" ;;
      "Stop service") eval "$package_dir/$1.sh -s" ;;
      "Start/restart service") eval "$package_dir/$1.sh -r" ;;
      "Get service status") dialog --title "$title" --msgbox "$(eval "$package_dir/$1.sh -S")" 0 0 ;;
      "Back to software manager") break ;;
    esac
  done
}


while true; do
title="$title"
  option=""
  option=$(dialog --cancel-label "Back" --menu "$title" 0 0 6 \
    1 "The Comms Channel BBS, TC²BBS" \
    2 "Contact" \
    3 "Meshing Around by Spud" \
    4 "Mosquitto MQTT Broker" \
    5 "Mosquitto MQTT Client" \
    "" ""\
    6 "Back to Main Menu" 3>&1 1>&2 2>&3)
  
  exit_status=$? # This line checks the exit status of the dialog command
  if [ $exit_status -ne 0 ]; then # Exit the loop if the user selects "Cancel" or closes the dialog
    break
  fi
  
  case $option in
    1) package_intro "tc2_bbs" ;;
    2) package_intro "contact_client" ;;
    3) package_intro "meshing_around" ;;
    4) package_intro "mosquitto_mqtt_broker" ;;
    5) package_intro "mosquitto_mqtt_client" ;;
    6) break ;;
  esac
done

exit 0


    # 4 "Mosquitto MQTT broker" \
    # 5 "GPS and Telemetry" \
    
    # 4) mosquitto ;;
    # 5) gpsd ;;