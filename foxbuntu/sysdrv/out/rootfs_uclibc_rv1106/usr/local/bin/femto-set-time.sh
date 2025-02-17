#!/bin/bash
# prevents weirdness over tty
export NCURSES_NO_UTF8_ACS=1
export TERM=xterm-256color
export LANG=C.UTF-8

if [[ $EUID -ne 0 ]]; then
  echo -e "This script must be run as root. Try \`sudo femto-set-time.sh\`."
  exit 1
fi

arg_count=$#

help=$(cat <<EOF
If no argument is specified, a menu system will be used. Options are:
-h             This message
-t "TIMEZONE"  Set time zone
-T "TIMESTAMP" Set timestamp (unix timestamp)
EOF
)

set_timezone() {
  echo "Setting time zone..."
  ln -f -s /usr/share/zoneinfo/$1 /etc/localtime >/dev/null 2>&1
  dpkg-reconfigure --frontend noninteractive tzdata >/dev/null 2>&1
}

set_timestamp() {
for i in {1..5}; do
  if date -s "@$1" >/dev/null 2>&1; then
    if hwclock --systohc >/dev/null 2>&1; then
      echo "Time Zone updated to:\n$(timedatectl show --property=Timezone --value) $(date +%Z) (UTC$(date +%:z))\nSystem time updated to:\n$(date)\n\nNew time successfully saved to RTC.\nTime & date are also set automatically from internet, if connected."
      return 0
    else
      echo "System time updated to:\n$(date) ($(date +"UTC%z" | sed -E 's/GMT([+-])0?([0-9]{1,2})00/GMT\1\2/'))\n\nUnable to communicate with RTC module. An RTC module can remember system time between reboots/power outages.\nTime & date are also set automatically from internet, if connected."
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
  echo "Loading current time settings..."
  current_timezone=$(timedatectl show --property=Timezone --value)
  dialog --no-collapse --title "System time" --yesno "\
Current system time:\n\
$(date +"%B %d, %Y %H:%M:%S") $(timedatectl show --property=Timezone --value) ($(date +"UTC%z" | sed -E 's/GMT([+-])0?([0-9]{1,2})00/GMT\1\2/'))\n\
$(hwclock >/dev/null 2>&1 && echo "RTC module found!" || echo "RTC module not found.")\n\
\n\
Set new time and timezone?" 10 70
  if [ $? -eq 1 ]; then #unless cancel/no
    exit 0
  fi
  # Fetch available time zones
  echo "Loading time zones..."
  timezones=$(timedatectl list-timezones)
  # Build the options array
  options=()
  while IFS= read -r timezone; do
    options+=("$timezone" "x")
  done <<< "$timezones"

  # Convert options array to string
  options_str=$(printf '%s\n' "${options[@]}")
  
  # Show timezone selection menu with preselection of current timezone
  selected_timezone=$(dialog --title "Set Time Zone" \
                            --default-item "$current_timezone" \
                            --menu "Current time zone: $current_timezone (UTC$(date +%z))" 20 60 10 \
                            $(printf "%s " "${options[@]}") 3>&1 1>&2 2>&3)
  exit_status=$?
  if [[ $exit_status -eq 0 && -n "$selected_timezone" ]]; then
    # Set the selected time zone
    set_timezone $selected_timezone
  else
    exit 1
  fi

  DATE=$(dialog --title "Set Date" --calendar "Current date: $(date "+%B %d, %Y") \nPress [TAB] to select." 0 0 $(date +%d) $(date +%m) $(date +%Y) 3>&1 1>&2 2>&3)
  if [ $? -ne 0 ]; then
    exit 1
  fi
  DATE=$(echo "$DATE" | awk -F'/' '{print $3"-"$2"-"$1}') #reformat to YYYY-MM-DD
  TIME=$(dialog --title "Set Time" --timebox "Current time: $(date +%H:%M:%S)\nPress [TAB] to select." 0 0 3>&1 1>&2 2>&3) # Dialog timebox for time
  if [ $? -eq 1 ]; then #if cancel/no
    exit 1
  fi
  
  msg="$(set_timestamp $(date -d "$DATE $TIME" +%s))"
  exit_status=$?

  logger $msg
  if [ $arg_count -eq 0 ]; then
    dialog --msgbox "$msg" 13 50
  else
    echo -e $msg
  fi
  exit $exit_status #exit status matches set_timestamp exit status

fi