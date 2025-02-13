#!/bin/bash

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root."
  echo "Try \`sudo femto-config\`."
  exit 1
fi

help=$(cat <<EOF
If script is run without arguments, a dialog menu UI will load.
Options are:
-h                            This message
-b                            List kernel modules set to load at boot
-a                            List active kernel modules
-x "kernelmodule" "enable"    Set kernel module status (enable/disable)
-z "kernelmodule" "blacklist" Set kernel module blacklist status (blacklist/un-blacklist)
EOF
)

module_switch() {
  if [ $2 = "enable" ]; then
    modprobe $1    # Load the selected module
    if [ $? -eq 0 ]; then
      if ! grep -Fxq "$1" /etc/modules; then  # Add the module to /etc/modules if not already present
        echo "$1" >> /etc/modules
      fi
      echo -e "\033[4m$1\033[0m has been enabled and will be started at boot.\n\nSome modules are unloaded automatically when not in use."
    else
      echo -e "Failed to enable \033[4m$1\033[0m."
      exit 1
    fi
  elif [ $2 = "disable" ]; then
    rmmod $1 > /dev/null 2>&1    # Unload the module
    sed -i "/^$1$/d" /etc/modules
    echo -e "\033[4m$1\033[0m has been disabled and removed from boot.\n\nIt may be automatically loaded if compatible hardware is detected."
  else
    echo "Invalid argument \"$2\".\n$help"
  fi
}

module_blacklist() {
  if [ $2 = "blacklist" ]; then
    mv "$module_dir/$1.ko" "$module_dir/$1.ko.blacklisted" > /dev/null 2>&1
    echo -e "$1 is blacklisted."
  elif [ $2 = "un-blacklist" ]; then
    sudo rmmod $1 > /dev/null 2>&1    # Unload the module
    mv "$module_dir/$1.ko.blacklisted" "$module_dir/$1.ko" > /dev/null 2>&1
    echo -e "$1 is un-blacklisted."
  else
    echo "Invalid argument \"$2\".\n$help"
  fi
}

# Parse options
while getopts ":hbax:z:" opt; do
  case ${opt} in
    h) # Option -l (set lora radio)
      echo "$help"
      exit 0
    ;;
    b) # kernel modules set to start at boot)
      echo -e "$(modules=$(sed -n '6,$p' /etc/modules | awk '{printf "\033[4m%s\033[0m ", $0}'); [ -z "$modules" ] && echo "\033[4mnone\033[0m" || echo "$modules")"
    ;;
    a) # kernel modules currently active)
      echo -e "$(modules=$(lsmod | awk 'NR>1 {printf "\033[4m%s\033[0m ", $1}'); [ -z "$modules" ] && echo "none" || echo "$modules")"
    ;;
    x) # Option -x (Set kernel module status (enable/disable))
      echo "$(module_switch $2 $3)"
    ;;
    z) # Option -z (Set kernel module blacklist status (blacklist/un-blacklist))
      echo "$(module_blacklist $2 $3)"
    ;;
  esac
done
if [ -n "$1" ]; then # if there are arguments, don't proceed to menu
  exit
fi

module_dir="/lib/modules/5.10.160"

dialog --no-collapse --colors --title "$title" --yesno "\
Kernel modules are loadable pieces of code that extend a Linux kernel's functionality without requiring a reboot. Common examples include device drivers, file systems, or system calls.\n\
\n\
This tool will allow you to manage kernel modules and add pre-compiled modules to Foxbuntu.\n\
\n\
Boot modules:    \Zu$(femto-utils.sh -R "$(femto-kernel-modules.sh -b)")\Zu\Zn\n\
Active modules:  \Zu$(femto-utils.sh -R "$(femto-kernel-modules.sh -a)")\Zu\Zn\n\
\n\
Continue?
" 0 0
[ ! $? -eq 0 ] && exit 1

load_modules() {
  dialog --infobox "Loading kernel module menu...\n\nExpected load time: 35 seconds." 6 45
  modules=()

  # Create a list of modules (filename minus the .ko)
  for module in $(ls $module_dir/*.ko*); do
    module_name=$(basename "$module" | sed 's/\([^.]*\).*/\1/')
    modules+=("$module_name" "$(lsmod | grep -q "^$module_name " && echo ✅ || echo ❌)$(femto-kernel-modules.sh -b | sed 's/\x1b\[[0-9;]*m//g' | grep -qw "$module_name" && echo ✅ || echo ❌)   $(basename "$module" | grep -q "blacklisted" && echo "BLACKLISTED" || modinfo "$module_name" | grep -i 'description' | cut -d: -f2 | sed 's/^[ \t]*//' )")
  done
  modules_changed="false"
}

load_modules
modules_changed="false"

while true; do
  [ $modules_changed = "true" ] && load_modules
  # Create the menu options
  selected_module=$(dialog --no-collapse --cancel-label "Back" --ok-label "Open" --title "Kernel Modules" --no-shadow --default-item "$selected_module" --menu "Module name             Loaded/Boot?             Description" 42 103 8 "${modules[@]}" 3>&1 1>&2 2>&3)
  [ $? -eq 1 ] && break # Exit the loop if the user selects "Cancel" or closes the dialog

  modules_changed="false"
  # Get the full modinfo for the module and process it for dialog
  while true; do
    modinfo_output=$(modinfo $selected_module 2>/dev/null | sed ':a;N;$!ba;s/\n/\\n/g') # add \n to module info

    if [ ! -e "$module_dir/$selected_module.ko" ]; then
        module_info="\Z1\ZuMODULE BLACKLISTED!\Zn\n\n$selected_module has been blacklisted and will not load."
    else
        module_info="Module is currently $(lsmod | grep -q "^$selected_module " && echo "\Z4loaded\Zn" || echo "\Z1unloaded\Zn") and is set $(femto-utils.sh -R "$(femto-kernel-modules.sh -b | sed 's/\x1b\[[0-9;]*m//g' | grep -qw "$selected_module" && echo "\Z4to load at boot\Zn" || echo "\Z1not to load at boot\Zn. It may load automatically if needed")").\n\
\n\
Full module info:\n$modinfo_output\n\nNote: Dependencies are loaded/unloaded automatically."
    fi
    
    dialog --colors --yes-label "Cancel" --no-label "Disable" --extra-button --extra-label "Enable" --help-button --help-label "Blacklist" --title "$selected_module" --yesno "$module_info" 0 0

    exit_status=$? # This line checks the exit status of the dialog command
    if [ $exit_status -eq 0 ]; then # "Back" button
      break
    elif [ $exit_status -eq 3 ]; then # "Enable" button
      dialog --colors --title "$selected_module" --msgbox "$(femto-utils.sh -R "$(module_switch $selected_module enable)")" 0 0
      modules_changed="true"
    elif [ $exit_status -eq 1 ]; then # "Disable" button
      dialog --colors --title "$selected_module" --msgbox "$(femto-utils.sh -R "$(module_switch $selected_module disable)")" 0 0
      modules_changed="true"
    elif [ $exit_status -eq 2 ]; then # "Blacklist" button
      dialog --no-collapse --colors --title "$selected_module" --yes-label "Cancel" --no-label "Un-blacklist" --extra-button --extra-label "Blacklist" --yesno "$selected_module is currently $([ -e "$module_dir/$selected_module.ko" ] && echo "\Z4\Zunot blacklisted\Zn" || echo "\Z1\Zublacklisted\Zn").\n\nBlacklisting prevents a kernel module from loading.\n\nWould you like to blacklist $selected_module?" 0 0
      exit_status=$?
      if [ $exit_status -eq 0 ]; then 
        continue
      elif [ $exit_status -eq 3 ]; then # blacklist
        dialog --colors --title "$selected_module" --msgbox "$(femto-utils.sh -R "$(module_blacklist $selected_module blacklist)")" 6 45
        modules_changed="true"
      else # blacklist
        dialog --colors --title "$selected_module" --msgbox "$(femto-utils.sh -R "$(module_blacklist $selected_module un-blacklist)")" 6 45
        modules_changed="true"
      fi
    fi
  done
done

exit 0