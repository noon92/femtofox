#!/bin/bash

help=$(cat <<EOF
If script is run without arguments, a dialog menu UI will load.
Options are:
-h                            This message
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
      echo "$1 has been enabled and will be started at boot."
    else
      exit 1
    fi
  elif [ $2 = "disable" ]; then
    rmmod $1    # Disable the module
    if [ $? -eq 0 ]; then
      sed -i "/^$1$/d" /etc/modules
      echo "$1 has been disabled and removed from boot."
    else
      exit 1
    fi
  else
    echo "Invalid argument \"$2\".\n$help"
  fi
}

# Parse options
while getopts ":hx" opt; do
  case ${opt} in
    h) # Option -l (set lora radio)
      echo "$help"
      exit 0
    ;;
    x) # Option -x (Set kernel module status (enable/disable))
      echo "$(module_switch $2 $3)"
    ;;
  esac
done
if [ -n "$1" ]; then # if there are arguments, don't proceed to menu
  exit
fi

dialog --infobox "Loading kernel module menu..." 5 45

modules=()

# Create a list of modules (filename minus the .ko)
for module in $(ls "/lib/modules/5.10.160"/*.ko); do
  module_name=$(basename "$module" .ko)
  modules+=("$module_name" "$(modinfo $module_name | grep -i 'description' | cut -d: -f2 | sed 's/^[ \t]*//')")
done

while true; do
  # Create the menu options
  option=$(dialog --cancel-label "Back" --title "Kernel Modules" --menu "" 42 103 8 "${modules[@]}" 3>&1 1>&2 2>&3)
  
  exit_status=$? # Check the exit status of the dialog command
  
  if [ $exit_status -ne 0 ]; then # Exit the loop if the user selects "Cancel" or closes the dialog
    break
  fi

  # Get the module name from the selection
  selected_module=$option
  
  # Get the full modinfo for the module and process it for dialog
  modinfo_output=$(modinfo $selected_module | sed ':a;N;$!ba;s/\n/\\n/g') # add \n to module info

  # Check if the module is currently enabled
  if lsmod | grep -q "^$selected_module "; then
    dialog --colors --title "Disable Module" --yesno "The module '$selected_module' is currently \Z2\Zuenabled\Zn.\n\nDo you want to disable it?\n\nFull module info:\n$modinfo_output\n\nNote: Unused dependencies will be removed automatically." 25 0
    if [ $? -eq 0 ]; then
      dialog --msgbox "$(module_switch $selected_module disable)" 7 60
    fi
  else
    dialog --colors --title "Enable Module" --yesno "The module '$selected_module' is currently \Z1disabled\Zn.\n\nDo you want to enable it?\n\nFull module info:\n$modinfo_output\n\nNote: Dependencies will be loaded automatically." 25 0
    if [ $? -eq 0 ]; then
      dialog --msgbox "$(module_switch $selected_module enable)" 7 60
    fi
  fi
done

exit 0