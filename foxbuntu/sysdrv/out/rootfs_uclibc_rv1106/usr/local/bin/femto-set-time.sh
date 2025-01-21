#!/bin/bash
# prevents weirdness over tty
export NCURSES_NO_UTF8_ACS=1
export TERM=xterm-256color
export LANG=C.UTF-8

if [[ $EUID -ne 0 ]]; then
  echo -e "This script must be run as root. Try \`sudo femto-set-timezone\`."
  exit 1
fi

arg_count=$#

help=$(cat <<EOF
If no argument is specified, a menu system will be used. Options are:
-h             This message
-t "TIMEZONE"  Set timezone
-T "TIMESTAMP" Set timestamp (unix timestamp)
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
  for i in {1..5}; do
    timedatectl set-timezone "$1" >/dev/null 2>&1 && break
    sleep 1
  done
  [ "$i" -eq 5 ] && log_message "\nFailed to set the time zone to $1 after 5 attempts." && exit 1
}

set_timestamp() {
for i in {1..5}; do
  if date -s "@$1" >/dev/null 2>&1; then
    if hwclock --systohc >/dev/null 2>&1; then
      echo "System time updated to:\n$(date)\n\nNew time successfully saved to RTC.\nTime & date are also set automatically from internet."
      return 0
    else
      echo "System time updated to:\n$(date)\n\nUnable to communicate with RTC module. An RTC module can save system time between reboots/power outages.\nTime & date are also set automatically from internet."
      return 0
    fi
  fi
done

echo "Failed to set system time to $(date -d @$1) after 5 attempts."
return 1
}


while getopts ":t:T:h" opt; do
  case ${opt} in
    t)  # Option -t (timezone)
      set_timezone "$OPTARG"
    ;;
    T)  # Option -t (timestamp)
      set_timestamp "$OPTARG"
    ;;
    h)  # Option -h (help)
      echo -e "$help"
    ;;
  esac
done

if [ $arg_count -eq 0 ]; then # if the script was launched with no arguments, then load the UI.
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

  DATE=$(dialog --title "Select Date" --calendar "Choose a date:\nCurrent date: $(date "+%B %d, %Y")\nPress [TAB] to select." 0 0 $(date +%d) $(date +%m) $(date +%Y) 3>&1 1>&2 2>&3)
  if [ $? -ne 0 ]; then
    exit 1
  fi
  DATE=$(echo "$DATE" | awk -F'/' '{print $3"-"$2"-"$1}') #reformat to YYYY-MM-DD
  TIME=$(dialog --title "Set Time" --timebox "Select time:\nCurrent time: $(date +%H:%M:%S)\nPress [TAB] to select." 0 0 3>&1 1>&2 2>&3) # Dialog timebox for time
  if [ $? -eq 1 ]; then #if cancel/no
    exit 1
  fi
  log_message "$(set_timestamp $(date -d "$DATE $TIME" +%s))"
  exit $? #exit status matches set_timestamp exit status

fi