#!/bin/bash
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Try \`sudo femto-meshtasticd-config\`."
   exit 1
fi

help=$(cat <<EOF
Options are:
-h             This message
-i             Get important node info
-g             Gets the current configuration URL and QR code
-k             Get current LoRa radio selection
-l "RADIO"     Choose LoRa radio model. Options are \`lr1121_tcxo\`, \`sx1262_tcxo\`, \`sx1262_xtal\`, \`none\` (simradio)
-q "URL"       Set configuration URL
-v             View current admin keys
-a "KEY"       Set admin key
-c             Clear admin keys
-p             Get legacy admin channel state
-o "true"      Set legacy admin channel state (true/false = enabled/disabled), case sensitive
-r             Test mesh connectivity by sending "test" to channel 0 and waiting for. Will attempt 3 times
-s             Start/restart Meshtasticd Service
-t             Stop Meshtasticd Service
-S             Get Meshtasticd Service state
-u             Upgrade Meshtasticd
-x             Uninstall Meshtasticd
-m             Meshtastic update tool. Syntax: \`femto-meshtasticd-config.sh -m \"--set security.admin_channel_enabled false\" 10 \"Disable legacy admin\"\`
               Will retry the \`--set security.admin_channel_enabled false\` command until successful or up to 10 times, and tag status reports with \`Disable legacy admin\` via echo and to system log.
EOF
)

if [ $# -eq 0 ]; then
  echo "No arguments provided."
  echo -e "$help"
  exit 1
fi

meshtastic_update() {
  local command="$1"
  local attempts=$2
  local ref="$3: "
  echo "Submitting to Meshtastic..."
  for retries in $(seq 1 $attempts); do
    local output=$(meshtastic --host $command) #>&2 lets meshtastic's output display on screen
    echo $output
    logger $output
    if echo "$output" | grep -qiE "Abort|invalid|Error|refused|Errno"; then
      if [ "$retries" -lt $attempts ]; then
        local msg="${ref:+$ref}Meshtastic command failed, retrying ($(($retries + 1))/$attempts)..."
        echo "$msg"
        logger "$msg"
        sleep 2 # Add a small delay before retrying
      fi
    else
      local success="true"
      msg="${ref:+$ref}Meshtastic command successful!"
      echo "$msg"
      logger "$msg"
      if [ -n "$external" ]; then # exit script only if meshtastic_update was called directly via argument
        exit 0
      fi
      return 0
    fi
  done
  if [ -z "$success" ]; then
    msg="${ref:+$ref}Meshtastic command FAILED."
    echo "$msg"
    logger "$msg"
    exit 1 # always exit script if failed
  fi
}

# Parse options
while getopts ":higkl:q:va:cpo:sStruxm" opt; do
  case ${opt} in
    h) # Option -h (help)
      echo -e "$help"
      ;;
    i) # Option -i (Get important node info)
      output=$(meshtastic --host --info)
      echo -e "\
Version:          $(echo "$output" | grep -oP '"firmwareVersion":\s*"\K[^"]+' | head -n 1)\n\
Node name:        $(echo "$output" | grep -oP 'Owner:\s*\K.*' | head -n 1)\n\
NodeID:           $(printf "%08x\n" $(echo "$output" | grep -oP '"myNodeNum":\s*\K\d+' | head -n 1)) ($(echo "$output" | grep -oP '"myNodeNum":\s*\K\d+' | head -n 1))\n\
TX enabled?       $(txEnabled=$(echo "$output" | grep -oP '"txEnabled":\s*\K\w+'); [[ "$txEnabled" == "true" ]] && echo "\033[0;34menabled\033[0m" || echo "\033[0;31mdisabled\033[0m")\n\
Role:             $(echo "$output" | grep -oP '"role":\s*"\K[^"]+' | head -n 1)\n\
Preset:           $(echo "$output" | grep -oP '"modemPreset":\s*"\K[^"]+')\n\
Region:           $(echo "$output" | grep -oP '"region":\s*"\K[^"]+')\n\
$(channelNum=$(echo "$output" | grep -oP '"channelNum":\s*\K\d+' | head -n 1); [[ -n "$channelNum" && "$channelNum" -gt 0 ]] && echo -e "Frequency slot:   $channelNum")
$(overrideFrequency=$(echo "$output" | grep -oP '"overrideFrequency":\s*\K[0-9.]+'); [[ -n "$overrideFrequency" && $(echo "$overrideFrequency > 0" | bc) -eq 1 ]] && echo -e "Override freq:    $overrideFrequency")\n\
Uptime:           $(echo "$output" | grep -oP '"uptimeSeconds":\s*\K\d+' | head -n 1 | awk '{days=int($1/86400); hrs=int(($1%86400)/3600); mins=int(($1%3600)/60); secs=int($1%60); printf "%d days %02d:%02d:%02d\n", days, hrs, mins, secs}')\n\
Public key:       $(echo "$output" | grep -oP '"publicKey":\s*"\K[^"]+' | head -n 1)\
"
      ;;
    g) # Option -g (get config URL)
      url=$(meshtastic --host --qr-all | grep -oP '(?<=Complete URL \(includes all channels\): )https://[^ ]+') #add look for errors
      clear
      echo "$url" | qrencode -o - -t UTF8 -s 1
      echo "Meshtastic configuration URL:"
      echo $url
      ;;
    k) # Option -k (get current lora radio model)
      ls /etc/meshtasticd/config.d 2>/dev/null | xargs -r -n 1 basename | sed 's/^femtofox_//;s/\.yaml$//' | grep . || echo -e "\033[0;31mnone (simulated radio)\033[0m"
      ;;
    l) # Option -l (choose lora radio model)
      prepare="rm -f /etc/meshtasticd/config.d/femtofox* && echo \"Radio type $OPTARG selected.\""
      if [ "$OPTARG" = "lr1121_tcxo" ]; then
        eval $prepare
        cp /etc/meshtasticd/available.d/femtofox/femtofox_LR1121_TCXO.yaml /etc/meshtasticd/config.d
        systemctl restart meshtasticd
      elif [ "$OPTARG" = "sx1262_tcxo" ]; then
        eval $prepare
        cp /etc/meshtasticd/available.d/femtofox/femtofox_SX1262_TCXO.yaml /etc/meshtasticd/config.d
        systemctl restart meshtasticd
      elif [ "$OPTARG" = "sx1262_xtal" ]; then
        eval $prepare
        cp /etc/meshtasticd/available.d/femtofox/femtofox_SX1262_XTAL.yaml /etc/meshtasticd/config.d
        systemctl restart meshtasticd
      elif [ "$OPTARG" = "none" ]; then
        eval $prepare
        systemctl restart meshtasticd
      else
        echo "$OPTARG is not a valid option. Options are \`lr1121_tcxo\`, \`sx1262_tcxo\`, \`sx1262_xtal\`, \`none\` (simradio)"
      fi
      ;;
    q) # Option -q (set config URL)
      meshtastic_update "--seturl $OPTARG" 10 "Set URL"
      ;;
    v) # Option -v (view admin keys)
      echo "Getting admin keys..."
      keys=$(meshtastic --host --get security.admin_key | grep -oP '(?<=base64:)[^,"]+' | sed "s/'//g" | sed "s/]//g" | nl -w1 -s'. ' | sed 's/^/|n/' | tr '\n' ' ')  #add look for errors
      echo "${keys:-none}"
      ;;
    a) # Option -a (add admin key)
      meshtastic_update "--set security.admin_key base64:$OPTARG" 10 "Set admin key"
      ;;
    c) # Option -c (clear admin key list)
      meshtastic_update "--set security.admin_key 0" 10 "Set admin key"
      ;;
    p) # Option -p (view current legacy admin state)
      meshtastic_update "--get security.admin_channel_enabled" 3 "Get legacy admin state"
      ;;
    o) # Option -o (set legacy admin true/false)
      meshtastic_update "--set security.admin_channel_enabled $OPTARG" 10 "Set legacy admin state"
      ;;
    r) # Option -r (mesh connectivity test)
      for ((i=0; i<=2; i++)); do
        if meshtastic --host --ch-index 0 --sendtext "test" --ack 2>/dev/null | grep -q "ACK"; then
          echo "Received acknowledgement!"
          exit 0
        else
          echo "Retrying... ($((i + 1)))"
        fi
      done
      echo "Failed after 3 attempts."
      ;;
    s) # Option -s (start/restart Meshtasticd service)
      systemctl restart meshtasticd
      echo "Meshtasticd service started/restarted."
      ;;
    S) # Option -S (Get Meshtasticd Service state)
      if echo "$(systemctl status meshtasticd)" | grep -q "active (running)"; then
        echo -e "\033[4m\033[0;34mrunning\033[0m"
      elif echo "$(systemctl status meshtasticd)" | grep -q "inactive (dead)"; then
        echo -e "\033[4m\033[0;31mnot running\033[0m"
      else
        echo "unknown"
      fi
      ;;
    t) # Option -t (stop Meshtasticd service)
      systemctl stop meshtasticd
      echo "Meshtasticd service stopped."
      ;;
    u) # Option -u (upgrade meshtasticd)
      apt update
      apt install --only-upgrade meshtasticd
      ;;
    x) # Option -x (uninstall meshtasticd)
      apt remove meshtasticd
      ;;
    m)
      external="true" # set a variable so the function knows it was called by an an external script and not locally
      meshtastic_update "$2" $3 "$4"
      ;;
    \?)  # Invalid option
      echo "Invalid option: -$OPTARG"
      echo -e "$help"
      exit 1
      ;;
    :) # Missing argument for option
      echo "Option -$OPTARG requires a setting."
      echo -e "$help"
      exit 1
      ;;
  esac
done