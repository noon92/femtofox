#!/bin/bash
export NCURSES_NO_UTF8_ACS=1 # prevents weirdness over tty

if [[ $EUID -ne 0 ]]; then
  echo -e "This script must be run as root. Try \`sudo femto-set-timezone\`."
  exit 1
fi

arg_count=$#

help=$(cat <<EOF
If no argument is specified, a menu system will be used. Options are:
-h             This message
-t "TIMEZONE"  Set timezone
EOF
)

log_message() {
  logger $1
  if [ $arg_count -eq 0 ]; then
    dialog --msgbox "$1" 12 50
  else
    echo -e $1
  fi
}

set_timezone() {
  if timedatectl set-timezone "$1"; then
    log_message "\nTime zone set to $1 (UTC$(date +%z)) successfully."
    exit 0
  else
    log_message "\nFailed to set the time zone to $1."
    exit 1
  fi
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
echo "Loading timezones..."
timezones=$(timedatectl list-timezones)
# Build the options array
options=()
while IFS= read -r timezone; do
  options+=("$timezone" "x")
done <<< "$timezones"

# Convert options array to string
options_str=$(printf '%s\n' "${options[@]}")

# Show timezone selection menu with preselection of current timezone
selected_timezone=$(dialog --title "Select Timezone" \
                           --default-item "$(cat /etc/timezone)" \
                           --menu "Current timezone: $(cat /etc/timezone) (UTC$(date +%z))" 20 60 10 \
                           $(printf "%s " "${options[@]}") 3>&1 1>&2 2>&3)
exit_status=$?
if [[ $exit_status -eq 0 && -n "$selected_timezone" ]]; then
  # Set the selected time zone
  set_timezone $selected_timezone
else
  exit 1
fi

DATE=$(echo "$(dialog --title "Select Date" --calendar "Choose a date:\nCurrent date: $(date "+%B %d, %Y")\nPress [TAB] to select." 0 0 $(date +%d) $(date +%m) $(date +%Y) 3>&1 1>&2 2>&3)" | awk -F/ '{printf "%04d-%02d-%02d", $3, $2, $1}')
if [ $? -eq 1 ]; then #if cancel/no
  exit 1
fi
TIME=$(dialog --title "Set Time" --timebox "Select time:\nCurrent time: $(date +%H:%M:%S)\nPress [TAB] to select." 0 0 3>&1 1>&2 2>&3) # Dialog timebox for time
if [ $? -eq 1 ]; then #if cancel/no
  exit 1
fi
if date -s "$DATE $TIME"; then # set time
  if hwclock --systohc; then
    rtc="New time successfully saved to RTC."
  else
    rtc="Unable to communicate with RTC module. An RTC module can save system time between reboots/power outages."
  fi
  log_message "System time updated to:\n$(date)\n\n$rtc\nTime & date are also set automatically from internet."
else
  log_message "Failed to set system time."
  exit 1
fi