#!/bin/bash
ip link set wlan0 up
sleep 60 #wait 60 seconds so networking will be available during boot

# Initial value for comparison (start with an impossible value so it'll always implement the current value after boot)
previous_value=2

while true; do
  if systemctl is-active --quiet meshtasticd; then
    # Run the command to fetch the value
    current_value=$(cat /root/.portduino/default/prefs/config.proto | protoc --decode_raw | awk '/4 {/, /}/ {if ($1 == "1:") print $2}')

    # Check if the value has changed
    if [ "$current_value" != "$previous_value" ]; then

	if [ "$previous_value" -eq 1 ]; then
	    prev_text="Wifi on"
	elif [ "$previous_value" -eq 2 ]; then
	    prev_text="Startup"
	else
	    prev_text="Wifi off"
	fi
	if [ "$current_value" -eq 1 ]; then
	    cur_text="Wifi on"
	else
	    cur_text="Wifi off"
	fi

        # Log the change
        logger "Wifi mesh control: wifi setting changed: $prev_text -> $cur_text"

        # Update the previous value for next comparison
        previous_value="$current_value"
    fi

    # Take action based on the new value
    if [ "$current_value" == "1" ]; then
        ip link set wlan0 up
    else
        ip link set wlan0 down
    fi

  else
    if ip link show wlan0 | grep -q 'state DOWN'; then
      ip link set wlan0 up
      logger "Wifi mesh control: Meshtasticd service is offline, turning wifi on."
    fi
  fi

  # wait 30 secs before checking again
  sleep 30
done
