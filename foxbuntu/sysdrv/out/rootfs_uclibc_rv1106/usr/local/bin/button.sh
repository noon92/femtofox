#!/bin/bash

logger "Listening for button press on $DEVICE..."
evtest --grab /dev/input/event0 | while read line; do
  # Check for key press event
  if echo "$line" | grep -q "EV_KEY.*value 1"; then
    start_time=$(date +%s) #start timer
  fi
  
  # Check for key release event
  if echo "$line" | grep -q "EV_KEY.*value 0"; then
    duration=$(($(date +%s) - start_time))

    if [ $duration -lt 2 ]; then # <2 second press: toggle wifi
      (
        for i in $(seq 1 3); do
          echo 1 > /sys/class/gpio/gpio34/value;
          sleep 0.25;
          echo 0 > /sys/class/gpio/gpio34/value;
          sleep 0.25;
        done
      ) &
      msg="$duration second button press detected. Toggling wifi"
      echo $msg | sudo tee /dev/console
      logger $msg
      (femto-network-config.sh -T) & # toggle wifi in background so button can be repressed immediately
    elif [ $duration -lt 5 ]; then # 2-5 second press: reboot
      msg="$duration second button press detected. Rebooting"
      echo $msg | sudo tee /dev/console
      logger $msg
      for i in $(seq 1 20); do
        echo 1 > /sys/class/gpio/gpio34/value;
        sleep 0.0625;
        echo 0 > /sys/class/gpio/gpio34/value;
        sleep 0.0625;
      done
      reboot
    else # 5+ second press: halt
      msg="$duration second button press detected. Halting system"
      echo $msg | sudo tee /dev/console
      logger $msg
      echo 1 > /sys/class/gpio/gpio34/value;
      halt
    fi
  fi
done
