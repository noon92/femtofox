#!/bin/bash
command="$1"
attempts=$2
ref="$3: "
echo "Submitting to Meshtastic..."
for retries in $(seq 1 $attempts); do
  
  output=$(meshtastic --host 127.0.0.1 $command) #>&2 lets meshtastic's output display on screen
  echo $output
  logger $output
  if echo "$output" | grep -qiE "Abort|invalid|Error|refused|Errno"; then
    if [ "$retries" -lt $attempts ]; then
      msg="${ref:+$ref }Meshtastic update failed, retrying ($(($retries + 1))/$attempts)..."
      echo "$msg"
      logger "$msg"
      sleep 2 # Add a small delay before retrying
    fi
  else
    exit 0 #success
    break
  fi
done
exit 1 #failed
