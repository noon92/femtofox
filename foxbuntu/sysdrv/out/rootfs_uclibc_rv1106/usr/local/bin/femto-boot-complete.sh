#!/bin/bash
echo "Boot complete"

echo "Disabling ACT LED..."
echo "none" > /sys/class/leds/work/trigger &
sleep 1

# blink successful boot code
for i in $(seq 1 5); do
  echo 1 > /sys/class/gpio/gpio34/value;
  sleep 0.5;
  echo 0 > /sys/class/gpio/gpio34/value;
  sleep 0.5;
done
exit 0