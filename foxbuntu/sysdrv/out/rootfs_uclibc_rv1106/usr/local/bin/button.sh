#!/bin/bash

logger "Listening for button press on $DEVICE..."
evtest --grab /dev/input/event0 | while read line; do
  # Check for key press event
  if echo "$line" | grep -q "EV_KEY.*value 1"; then
    start_time=$(date +%s)
  fi
  
  # Check for key release event
  if echo "$line" | grep -q "EV_KEY.*value 0"; then
    duration=$(($(date +%s) - start_time))
    if [ $duration -lt 2 ]; then
      ( for i in $(seq 1 3); do
          echo 1 > /sys/class/gpio/gpio34/value;
          sleep 0.25;
          echo 0 > /sys/class/gpio/gpio34/value;
          sleep 0.25;
        done
      ) &
      wifi_status=$(cat /root/.portduino/default/prefs/config.proto | protoc --decode_raw | awk '/4 {/, /}/ {if ($1 == "1:") print $2}')
      if [ "$wifi_status" -eq 1 ]; then
        logger "$duration second button press detected. Toggling wifi off."
        femto-meshtasticd-config.sh -m "--set network.wifi_enabled false" 10 "Button toggle wifi"
      else
        logger "$duration second button press detected. Toggling wifi on."
        femto-meshtasticd-config.sh -m "--set network.wifi_enabled true" 10 "Button toggle wifi"
      fi
    else
      logger "$duration second button press detected. Rebooting."
      echo 1 > /sys/class/gpio/gpio34/value;
      reboot
    fi
  fi
done
