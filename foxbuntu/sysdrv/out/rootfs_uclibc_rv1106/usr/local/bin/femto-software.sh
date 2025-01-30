#!/bin/bash

title="Software Manager"
package_dir="/usr/local/bin/packages"

install() {
  dialog --no-collapse --title "$title" --yesno "\nInstall $($package_dir/$1.sh -N)\n\nProceed?" 10 40
  if [ $? -eq 1 ]; then #if cancel/no
    return 1
  fi
  echo "Installing $($package_dir/$1.sh -N)..."
  # Run the installation script, capturing the output and displaying it in real time
  output=$($package_dir/$1.sh -i)
  install_status=$?  # Capture the exit status of the eval command
  user_message=$(echo "$output" | awk '/user_message: / {found=1; split($0, arr, "user_message: "); print arr[2]; next} found {print}' | sed '/^$/q') # grab the user_message, if present
  output=$(echo -e "$output" | sed '/user_message: /,$d') # remove the user message from the detailed output

  if [ $install_status -eq 0 ]; then # if the installation was successful
    dialog --no-collapse --colors --title "$title" --beep --msgbox "\ZuInstallation of $($package_dir/$1.sh -N) successful!\Zn$([ -n "$user_message" ] && echo "\n\n$user_message")\n\nLog:\n$(echo $output)" 0 0 # if there's a user_message, display it with two preceeding line breaks
  else
    dialog --no-collapse --colors --title "$title" --beep --msgbox "\ZuInstallation of $($package_dir/$1.sh -N) FAILED!\Zn\n\n$user_message\n\nLog:\n$(echo -e $output)" 0 0 # if there's a user_message, display it with two preceeding line breaks
  fi
}

uninstall() {
  dialog --no-collapse --title "$title" --yesno "\nUninstall $($package_dir/$1.sh -N)\n\nProceed?" 10 40
  if [ $? -eq 1 ]; then #if cancel/no
    return 1
  fi
  echo "Uninstalling $($package_dir/$1.sh -N)..."
  output=$(eval "$package_dir/$1.sh -u 2>&1 | tee /dev/tty")
  install_status=$?  # Capture the exit status of the eval command
  user_message=$(echo "$output" | awk '/user_message: / {found=1; split($0, arr, "user_message: "); print arr[2]; next} found {print}' | sed '/^$/q') # grab the user_message, if present
  output=$(echo "$output" | sed '/user_message: /,$d') # remove the user message from the detailed output
  if [ $install_status -eq 0 ]; then # if the installation was successful
    dialog --no-collapse --colors --title "$title" --beep --msgbox "\n\ZuUninstallation of $($package_dir/$1.sh -N) successful!\Zn$([ -n "$user_message" ] && echo "\n\n$user_message")\n\nLog:\n$(echo -e "$output")" 0 0 # if there's a user_message, display it with two preceeding line breaks
  else
    dialog --no-collapse --colors --title "$title" --beep --msgbox "\n\ZuUninstallation of $($package_dir/$1.sh -N) FAILED!\Zn\n\n$user_message\n\nLog:\n$(echo "$output")" 0 0 # if there's a user_message, display it with two preceeding line breaks
  fi
}

initialize() {
  dialog --no-collapse --title "$title" --yesno "\nIntialize $($package_dir/$1.sh -N)\n\nInitialization runs commands that frequently require user interaction and so can only be run from terminal.\n\nProceed?" 13 50
  if [ $? -eq 1 ]; then #if cancel/no
    return 1
  fi
  clear
  echo "Initializing $($package_dir/$1.sh -N)..."
  eval "$package_dir/$1.sh -a"
  if [ $? -eq 0 ]; then # if the installation was successful
    dialog --no-collapse --colors --title "$title" --beep --msgbox "\nInitialization of $($package_dir/$1.sh -N) successful!" 8 50 # if there's a user_message, display it with two preceeding line breaks
  else
    dialog --no-collapse --colors --title "$title" --beep --msgbox "\nInitialization of $($package_dir/$1.sh -N) FAILED!" 8 50 # if there's a user_message, display it with two preceeding line breaks
  fi
}

upgrade() {
  dialog --no-collapse --title "$title" --yesno "\nUpgrade $($package_dir/$1.sh -N)\n\nProceed?" 10 40
  if [ $? -eq 1 ]; then #if cancel/no
    return 1
  fi
  echo "Upgrading $($package_dir/$1.sh -N)..."
  output=$(eval "$package_dir/$1.sh -g 2>&1 | tee /dev/tty")
  install_status=$?  # Capture the exit status of the eval command
  user_message=$(echo "$output" | awk '/user_message: / {found=1; split($0, arr, "user_message: "); print arr[2]; next} found {print}' | sed '/^$/q') # grab the user_message, if present
  output=$(echo "$output" | sed '/user_message: /,$d') # remove the user message from the detailed output
  if [ $install_status -eq 0 ]; then # if the installation was successful
    dialog --no-collapse --colors --title "$title" --beep --msgbox "\n\ZuUpgrade of $($package_dir/$1.sh -N) successful!\Zn$([ -n "$user_message" ] && echo "\n\n$user_message")\n\nLog:\n$output" 0 0 # if there's a user_message, display it with two preceeding line breaks
  else
    dialog --no-collapse --colors --title "$title" --beep --msgbox "\n\ZuUpgrade of $($package_dir/$1.sh -N) FAILED!\Zn\n\n$user_message\n\nLog:\n$output" 0 0 # if there's a user_message, display it with two preceeding line breaks
  fi  
}


# build and display package intro
package_intro() {
  echo "Loading package info..."
  # check if each field in the package info is supported by the package, and if so get it and insert it into the package info dialog
  dialog --no-collapse --colors --title "$title" --msgbox "\
    $($package_dir/$1.sh -N)\n\
        $(if $package_dir/$1.sh -O | grep -q 'A'; then echo -e "by $($package_dir/$1.sh -A)"; fi)\n\
$(if $package_dir/$1.sh -O | grep -q 'D'; then echo "\n$($package_dir/$1.sh -D)"; fi)\n\
\n\
$(echo "Currently:       " && $package_dir/$1.sh -I && echo "\Zuinstalled\Zn" || echo "\Zunot installed\Zn")\n\
$(if output=$($package_dir/$1.sh -L); [ -n "$output" ]; then echo "Installs to:     \Zu$output\Zn\n"; fi)\
$(if output=$($package_dir/$1.sh -C); [ -n "$output" ]; then echo "Conflicts with:  \Zu$output\Zn\n"; fi)\
An internet connection is required for installation.\n\
$(if $package_dir/$1.sh -O | grep -q 'U'; then echo "\nFor more information, visit $($package_dir/$1.sh -U)"; fi)" 0 0
  package_menu $1 # after user hits "OK", move on to package menu
}

package_menu() {
  choice=""
  while true; do
    echo "Loading package menu..."
    # for each line, check if it's supported by the package, display it if the current install state of the package is appropriate (example: don't display "install" if the package is already installed, don't display "stop service" for a package with no services)
    choice=$(dialog --no-collapse --title "$title" --cancel-label "Back" --default-item "$choice" --menu "$($package_dir/$1.sh -N)" 18 45 5 \
      $(if $package_dir/$1.sh -O | grep -q 'l' && $package_dir/$1.sh -I; then echo "Run software x"; fi) \
      $(if $package_dir/$1.sh -O | grep -q 'i' && ! $package_dir/$1.sh -I; then echo "Install x"; fi) \
      $(if $package_dir/$1.sh -O | grep -q 'u' && $package_dir/$1.sh -I; then echo "Uninstall x"; fi) \
      $(if $package_dir/$1.sh -O | grep -q 'a' && $package_dir/$1.sh -I; then echo "Initialize x"; fi) \
      $(if $package_dir/$1.sh -O | grep -q 'g' && $package_dir/$1.sh -I; then echo "Upgrade x"; fi) \
      $(if $package_dir/$1.sh -O | grep -q 'e' && $package_dir/$1.sh -I; then echo "Enable service x"; fi) \
      $(if $package_dir/$1.sh -O | grep -q 'd' && $package_dir/$1.sh -I; then echo "Disable service x"; fi) \
      $(if $package_dir/$1.sh -O | grep -q 's' && $package_dir/$1.sh -I; then echo "Stop service x"; fi) \
      $(if $package_dir/$1.sh -O | grep -q 'r' && $package_dir/$1.sh -I; then echo "Start/restart service x"; fi) \
      $(if $package_dir/$1.sh -O | grep -q 'S' && $package_dir/$1.sh -I; then echo "Get service status x"; fi) \
      " " "" \
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
      "Initialize") initialize $1 ;;
      "Upgrade") upgrade $1 ;;
      "Enable service") echo "Enabling and starting service..." && eval "$package_dir/$1.sh -e" && eval "$package_dir/$1.sh -r" ;;
      "Disable service") echo "Disabling and stopping service..." && eval "$package_dir/$1.sh -d" && eval "$package_dir/$1.sh -s" ;;
      "Stop service") echo "Stopping service..." && eval "$package_dir/$1.sh -s" ;;
      "Start/restart service") echo "Starting/restarting service..." && eval "$package_dir/$1.sh -r" ;;
      "Get service status") echo "Getting service status..." && dialog --no-collapse --title "$title" --msgbox "$(eval "$package_dir/$1.sh -S")" 0 0 ;;
      "Back to software manager") break ;;
    esac
  done
}

# generate menu from filenames in /usr/local/bin/packages
while true; do
  menu_entries=()
  index=1
  for file in /usr/local/bin/packages/*.sh; do
    filename=$(basename "$file" .sh)
    [[ "$filename" == "package_template" ]] && continue # skip package_template.sh
    menu_entries+=("$index" "$(/usr/local/bin/packages/"$filename".sh -N)")
    ((index++))
  done

  menu_entries+=(" " "")  # add blank line and "Back to Main Menu" entry
  menu_entries+=("$index" "Back to main menu")
  software_option=$(dialog --no-collapse --cancel-label "Back" --default-item "$software_option" --menu "$title" $((9 + index)) 50 $((index + 1)) "${menu_entries[@]}" 3>&1 1>&2 2>&3)
  exit_status=$? # This line checks the exit status of the dialog command
  if [ $exit_status -ne 0 ]; then # Exit the loop if the user selects "Cancel" or closes the dialog
    break
  fi
    
  case_block="  case \$software_option in"
  index=1
  for file in /usr/local/bin/packages/*.sh; do
    filename=$(basename "$file" .sh)
    [[ "$filename" == "package_template" ]] && continue # skip package_template.sh
    case_block+="
      $index) package_intro \"$filename\" ;;"
    ((index++))
  done

  case_block+="
      $index) break ;;
    esac" #add return to main menu option
  eval "$case_block" # Execute the generated case statement
done

exit 0


    # 4 "Mosquitto MQTT broker" \
    # 5 "GPS and Telemetry" \
    
    # 4) mosquitto ;;
    # 5) gpsd ;;
