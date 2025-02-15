#!/bin/bash

title="Software Manager"
package_dir="/usr/local/bin/packages"

install() {
  dialog --no-collapse --title "Install $($package_dir/$1.sh -N)" --yesno "\nInstallation requires internet connectivity.\n\nInstall $($package_dir/$1.sh -N)?" 10 40
  [ $? -eq 1 ] && return 1 #if cancel/no

  echo "Installing $($package_dir/$1.sh -N)..."
  # Run the installation script, capturing the output and displaying it in real time
  output=$($package_dir/$1.sh -i | tee /dev/tty)
  install_status=$?  # Capture the exit status of the eval command
  if [ ${#output} -gt 2048 ]; then   # Truncate to 2048 characters and append ellipsis and note if necessary
    truncated_output="${output:0:2000}...\nLOG TRUNCATED"
    if [[ "$output" =~ user_message: ]]; then # preserve user_message by adding to end of string
      truncated_output="$truncated_output\n$(echo "$output" | sed -n 's/.*\(user_message:.*\)/\1/p')"
    fi
    output="$truncated_output"
  fi
  user_message=$(echo "$output" | awk '/user_message: / {found=1; split($0, arr, "user_message: "); print arr[2]; next} found {print}' | sed '/^$/q') # grab the user_message, if present
  output=$(echo -e "$output" | sed '/user_message: /,$d') # remove the user message from the detailed output

  if [ $install_status -eq 0 ]; then # if the installation was successful
    dialog --no-collapse --colors --title "$title" --beep --msgbox "\ZuInstallation of $($package_dir/$1.sh -N) successful!\Zn$([ -n "$user_message" ] && echo "\n\n$user_message")\n\nLog:\n$(echo $output)" 0 0 # if there's a user_message, display it with two preceeding line breaks
  else
    dialog --no-collapse --colors --title "$title" --beep --msgbox "\ZuInstallation of $($package_dir/$1.sh -N) FAILED!\Zn\n\n$user_message\n\nLog:\n$(echo -e $output)" 0 0 # if there's a user_message, display it with two preceeding line breaks
  fi
}

uninstall() {
  dialog --no-collapse --title "Uninstall $($package_dir/$1.sh -N)" --yesno "\nNote: reinstallation will require internet connectivity.\n\nUninstall $($package_dir/$1.sh -N)?" 10 40
  [ $? -eq 1 ] && return 1 #if cancel/no
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
  dialog --no-collapse --title "$title" --yesno "\nIntialize $($package_dir/$1.sh -N)\n\nInitialization runs commands that require user interaction and so can only be run from terminal.\n\nInitialize $($package_dir/$1.sh -N)?" 13 50
  [ $? -eq 1 ] && return 1 #if cancel/no
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
  dialog --no-collapse --title "Upgrade $($package_dir/$1.sh -N)" --yesno "\nUpgrade requires internet connectivity.\n\nUpgrade $($package_dir/$1.sh -N)?" 10 40
  [ $? -eq 1 ] && return 1 #if cancel/no
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
  dialog --no-collapse --colors --title "$title" --yes-label "Continue" --no-label "Back" --yesno "\
$($package_dir/$1.sh -N)\n\
  $(if $package_dir/$1.sh -O | grep -q 'A'; then echo -e "by $($package_dir/$1.sh -A)"; fi)\n\
$(if $package_dir/$1.sh -O | grep -q 'D'; then echo "\n$($package_dir/$1.sh -D)"; fi)\n\
\n\
$(echo "Currently:       " && $package_dir/$1.sh -I && echo "\Zuinstalled\Zn" || echo "\Zunot installed\Zn")\n\
$([ -n "$($package_dir/$1.sh -E)" ] && $package_dir/$1.sh -I && echo "Service status:  \Zu$(femto-utils.sh -C "$($package_dir/$1.sh -E)" | sed 's/\x1b\[[0-9;]*m//g')\Zn\n")\
$(if output=$($package_dir/$1.sh -L); [ -n "$output" ]; then echo "Installs to:     \Zu$output\Zn\n"; fi)\
$(if output=$($package_dir/$1.sh -C); [ -n "$output" ]; then echo "Conflicts with:  \Zu$output\Zn\n"; fi)\
$(if output=$($package_dir/$1.sh -T); [ -n "$output" ]; then echo "License:         \Zu$output\Zn\n"; fi)\
$(if $package_dir/$1.sh -O | grep -q 'U'; then echo "Website:         \Zu$($package_dir/$1.sh -U)\Zn"; fi)" 0 0
  [ $? -eq 1 ] && return 1 # Exit the loop if the user selects "Cancel" or closes the dialog
  package_menu $1 # after user hits "OK", move on to package menu
}

package_menu() {
  choice=""
  while true; do
    echo "Loading package menu..."
    license_button=""
    if $package_dir/$1.sh -O | grep -q 'G' && $package_dir/$1.sh -I; then license_button="--help-button --help-label License"; fi
    # for each line, check if it's supported by the package, display it if the current install state of the package is appropriate (example: don't display "install" if the package is already installed, don't display "stop service" for a package with no services)
    if $package_dir/$1.sh -I; then service_state=$(femto-utils.sh -C "$($package_dir/$1.sh -E)"); fi
    # Removed from menu list until can be fixed - contact does not launch. When returned to list, should be first entry
    # $(if $package_dir/$1.sh -O | grep -q 'l' && $package_dir/$1.sh -I; then echo "Run software x"; fi) \
    menu_list="\
      $(if $package_dir/$1.sh -O | grep -q 'i' && ! $package_dir/$1.sh -I; then echo "Install x"; fi) \
      $(if $package_dir/$1.sh -O | grep -q 'u' && $package_dir/$1.sh -I; then echo "Uninstall x"; fi) \
      $(if $package_dir/$1.sh -O | grep -q 'a' && $package_dir/$1.sh -I; then echo "Initialize x"; fi) \
      $(if $package_dir/$1.sh -O | grep -q 'g' && $package_dir/$1.sh -I; then echo "Upgrade x"; fi) \
      $(if $package_dir/$1.sh -O | grep -q 'e' && $package_dir/$1.sh -I && [[ ! $service_state =~ "enabled" ]]; then echo "Enable service x"; fi) \
      $(if $package_dir/$1.sh -O | grep -q 'e' && $package_dir/$1.sh -I && [[ ! $service_state =~ "disabled" ]]; then echo "Disable service x"; fi) \
      $(if $package_dir/$1.sh -O | grep -q 'e' && $package_dir/$1.sh -I && [[ ! $service_state =~ "not running" ]]; then echo "Stop service x"; fi) \
      $(if $package_dir/$1.sh -O | grep -q 'e' && $package_dir/$1.sh -I; then echo "Start/restart service x"; fi) \
      $(if $package_dir/$1.sh -O | grep -q 'S' && $package_dir/$1.sh -I; then echo "Detailed service status x"; fi)"
      menu_count=$(( $(echo "$menu_list" | grep -o " x" | wc -l) $(if $package_dir/$1.sh -O | grep -q 'e' && $package_dir/$1.sh -I; then echo "+1"; fi) )) # count the number of menu items by counting how many times " x" shows up, +1 if there's a service. This is a stupid way to do this, but because each menu item only contains one space (the rest being space-sized invisible chars) it works. It's late at night, OKAY?!
      if $package_dir/$1.sh -O | grep -q 'e' && [ "$($package_dir/$1.sh -E | wc -w)" -gt 1 ]; then
        multiple_services_note="\nService will appear as \"running\" if any of the services are active."
        menu_count=$((menu_count + 2))
      fi
      choice=$(dialog --no-collapse --colors --title "$($package_dir/$1.sh -N)" $license_button --cancel-label "Back" --default-item "$choice" --menu "$(if $package_dir/$1.sh -O | grep -q 'S' && $package_dir/$1.sh -I; then echo "Service status: $(femto-utils.sh -R "$service_state")"; fi)$multiple_services_note" $(( menu_count + 9 )) 45 $(( menu_count + 3 )) \
      $menu_list \
      " " "" \
      "Back to software manager" "" 3>&1 1>&2 2>&3)
      exit_status=$? # This line checks the exit status of the dialog command
      if [ $exit_status -eq 1 ]; then # Exit the loop if the user selects "Cancel" or closes the dialog
        return
      elif [ $exit_status -eq 2 ]; then # Help ("extra") button
        dialog --no-collapse --colors --title "$($package_dir/$1.sh -N) License" --msgbox "   \Zu$($package_dir/$1.sh -N)\Zn\n$(if output=$($package_dir/$1.sh -T); [ -n "$output" ]; then echo "License: $output"; fi)\n\n$($package_dir/$1.sh -G)" 0 0
      else
        # execute the actual commands
        case $choice in
          "Run software") echo "Launching $($package_dir/$1.sh -N)..." && eval "$($package_dir/$1.sh -l)" ;;
          "Install") install $1 ;;
          "Uninstall") uninstall $1 ;;
          "Initialize") initialize $1 ;;
          "Upgrade") upgrade $1 ;;
          "Enable service") echo "Enabling and starting service..." && eval "$package_dir/$1.sh -e" && eval "$package_dir/$1.sh -r" ;;
          "Disable service") echo "Disabling and stopping service..." && eval "$package_dir/$1.sh -d" && eval "$package_dir/$1.sh -s" ;;
          "Stop service") echo "Stopping service..." && eval "$package_dir/$1.sh -s" ;;
          "Start/restart service") echo "Starting/restarting service..." && eval "$package_dir/$1.sh -r" ;;
          "Detailed service status") echo "Getting service status..." && dialog --no-collapse --title "$title" --msgbox "$(eval "$package_dir/$1.sh -S")" 0 0 ;;
          "Back to software manager") break ;;
        esac
      fi
  done
}

# generate menu from filenames in /usr/local/bin/packages

while true; do
  echo "Loading packages..."
  menu_entries=("Package name" "Installed?" "" "")
  index=1
  for file in /usr/local/bin/packages/*.sh; do
    filename=$(basename "$file" .sh)
    [[ "$filename" == femto_* ]] && continue # skip filenames starting with femto_
    menu_entries+=("$(/usr/local/bin/packages/"$filename".sh -N)" "$($package_dir/$filename.sh -I && echo "✅ " || echo "❌ ")")
    ((index++)) # keeping an index to determine menu window height
  done

  menu_entries+=(" " "")  # add blank line and "Back to Main Menu" entry
  menu_entries+=("Back to main menu" "")
  software_option=$(dialog --no-collapse --cancel-label "Back" --default-item "$software_option" --menu "$title" $((11 + index)) 50 $((index + 3)) "${menu_entries[@]}" 3>&1 1>&2 2>&3)
  [ $? -eq 1 ] && break # Exit the loop if the user selects "Cancel" or closes the dialog
    
  case_block="  case \$software_option in"
  index=1
  for file in /usr/local/bin/packages/*.sh; do
    filename=$(basename "$file" .sh)
    [[ "$filename" == femto_* ]] && continue # skip filenames starting with femto_
    case_block+="
      \"$(/usr/local/bin/packages/"$filename".sh -N)\") package_intro \"$filename\" ;;"
    ((index++))
  done

  case_block+="
      \"Back to main menu\") break ;;
    esac" #add return to main menu option
  eval "$case_block" # Execute the generated case statement
done

exit 0