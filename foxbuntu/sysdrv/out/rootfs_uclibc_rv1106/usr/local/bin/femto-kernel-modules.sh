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
    rmmod $1    # Disable the module
    sed -i "/^$1$/d" /etc/modules
    echo -e "\033[4m$1\033[0m has been disabled and removed from boot.\n\nIt may be automatically loaded if compatible hardware is detected."
  else
    echo "Invalid argument \"$2\".\n$help"
  fi
}

# Parse options
while getopts ":hbax" opt; do
  case ${opt} in
    h) # Option -l (set lora radio)
      echo "$help"
      exit 0
    ;;
    b) # kernel modules set to start at boot)
      echo -e "$(modules=$(sed -n '6,$p' /etc/modules | awk '{printf "%s\033[0m \033[4m", $0}' | sed 's/\033\[0m \033\[4m$//'); [ -z "$modules" ] && echo "none" || echo "$modules")"
    ;;
    a) # kernel modules currently active)
      echo -e "$(lsmod | awk 'NR>1 {printf "%s\033[0m \033[4m", $1}' | sed 's/\033\[0m \033\[4m$//')"
    ;;
    x) # Option -x (Set kernel module status (enable/disable))
      echo "$(module_switch $2 $3)"
    ;;
  esac
done
if [ -n "$1" ]; then # if there are arguments, don't proceed to menu
  exit
fi


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

while true; do
  dialog --infobox "Loading kernel module menu..." 5 45
  modules=("Module name" "Loaded/Boot?         Description" "" "")

  # Create a list of modules (filename minus the .ko)
  for module in $(ls "/lib/modules/5.10.160"/*.ko); do
    module_name=$(basename "$module" .ko)
    modules+=("$module_name" "$(lsmod | grep -q "^$module_name " && echo ✅ || echo ❌)$(femto-kernel-modules.sh -b | sed 's/\x1b\[[0-9;]*m//g' | grep -qw "$module_name" && echo ✅ || echo ❌)   $(modinfo $module_name | grep -i 'description' | cut -d: -f2 | sed 's/^[ \t]*//')")
  done

  # Create the menu options
  option=$(dialog --cancel-label "Back" --title "Kernel Modules" --no-shadow --default-item "$selected_module" --menu "" 42 103 8 "${modules[@]}" 3>&1 1>&2 2>&3)
  [ $? -eq 1 ] && break # Exit the loop if the user selects "Cancel" or closes the dialog

  # Get the module name from the selection
  selected_module=$option
  # Get the full modinfo for the module and process it for dialog
  modinfo_output=$(modinfo $selected_module | sed ':a;N;$!ba;s/\n/\\n/g') # add \n to module info

  dialog --colors --yes-label "Back" --no-label "Disable" --extra-button --extra-label "Enable" --title "$selected_module" --yesno "\
Module is currently $(lsmod | grep -q "^$selected_module " && echo "\Z4loaded\Zn" || echo "\Z1unloaded\Zn") and is set $(femto-utils.sh -R "$(femto-kernel-modules.sh -b | sed 's/\x1b\[[0-9;]*m//g' | grep -qw "$selected_module" && echo "\Z4to load at boot\Zn" || echo "\Z1not to load at boot\Zn. It may load automatically if needed")").\n\
\n\
Full module info:\n\
$modinfo_output\n\
\n\
Note: Dependencies are loaded/unloaded automatically." 0 0
  exit_status=$? # This line checks the exit status of the dialog command
  if [ $exit_status -eq 0 ]; then # "Back" button (yes)
    continue
  elif [ $exit_status -eq 3 ]; then # "Enable" button (no)
    dialog --colors --title "$selected_module" --msgbox "$(femto-utils.sh -R "$(module_switch $selected_module enable)")" 9 60
  elif [ $exit_status -eq 1 ]; then # "Disable" button (extra)
    dialog --colors --title "$selected_module" --msgbox "$(femto-utils.sh -R "$(module_switch $selected_module disable)")" 9 60
  fi
done

exit 0