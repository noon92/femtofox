#!/bin/bash
export NCURSES_NO_UTF8_ACS=1 # prevents weirdness over tty

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Try \`sudo femto-set-timezone\`."
   exit 1
fi

arg_count=$#

help=$(cat <<EOF
If no argument is specified, a menu system will be used. Options are:
-h             This message
-t "TIMEZONE"  Set timezone
EOF
)

set_timezone() {
    if timedatectl set-timezone "$1"; then
        msg="Time zone set to $1 successfully."
        status=0
    else
        msg="Failed to set the time zone to $1. Please try again." 8 40
        status=1
    fi
    if [ $arg_count -eq 0 ]; then
        dialog --msgbox "$msg" 8 40
    else
        echo $msg
        logger $msg
    fi
    exit $status
}



while getopts ":t:h" opt; do
  case ${opt} in
    t)  # Option -t (timezone)
      set_timezone "$OPTARG"
      ;;
    h)  # Option -h (help)
        echo -e "$help"
      ;;
  esac
done

# Fetch available time zones
timezones=$(timedatectl list-timezones)
if [[ -z "$timezones" ]]; then
    dialog --msgbox "\nFailed to retrieve time zones. Ensure 'timedatectl' is installed and functional." 8 40
    return
fi

# Build options for dialog menu
while IFS= read -r timezone; do
    options+=("$timezone" "x")
done <<< "$timezones"

# Convert options array to string
options_str=$(printf '%s\n' "${options[@]}")

# Show timezone selection menu
selected_timezone=$(dialog --title "Select Time Zone" --cancel-label "Skip" --menu "Choose a time zone:" 20 60 10 $(printf "%s " "${options[@]}") 3>&1 1>&2 2>&3)
exit_status=$?
if [[ $exit_status -eq 0 && -n "$selected_timezone" ]]; then
    # Set the selected time zone
    set_timezone $selected_timezone
fi