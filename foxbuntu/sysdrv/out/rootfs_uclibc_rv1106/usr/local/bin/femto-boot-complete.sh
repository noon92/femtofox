#!/bin/bash
if grep -qE '^first_boot=true' /etc/femto.conf; then
  echo "First boot, skipping \`boot complete\` tasks."
  exit 0
fi

echo "Boot complete"

femto-utils.sh -a &
sleep 1

# blink successful boot code
for i in $(seq 1 5); do
  echo 1 > /sys/class/gpio/gpio34/value;
  sleep 0.5;
  echo 0 > /sys/class/gpio/gpio34/value;
  sleep 0.5;
done
exit 0