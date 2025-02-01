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
-u             Get current public key
-U "KEY"       Set public key
-r             Get current private key
-R "KEY"       Set private key
-a             View current admin keys
-A "KEY"       Set admin key
-c             Clear admin keys
-p             Get legacy admin channel state
-o "true"      Set legacy admin channel state (true/false = enabled/disabled), case sensitive
-w             Test mesh connectivity by sending "test" to channel 0 and waiting for. Will attempt 3 times
-s             Start/restart Meshtasticd service
-t             Stop Meshtasticd service
-M "enable"    Enable/disable Meshtasticd service. Options: "enable" "disable"
-S             Get Meshtasticd service state
-z             Upgrade Meshtasticd
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
while getopts ":higkl:q:uU:rR:aA:cpo:sM:Stwuxm" opt; do
  case ${opt} in
    h) # Option -h (help)
      echo -e "$help"
      ;;
    i) # Option -i (Get important node info)
      declare -a output_array
      output=$(meshtastic --host --info)
      output_array+=("Service=$(femto-meshtasticd-config.sh -S)")
      output_array+=("Version=$(echo "$output" | grep -oP '"firmwareVersion":\s*"\K[^"]+' | head -n 1)")
      output_array+=("Node name=$(echo "$output" | grep -oP 'Owner:\s*\K.*' | head -n 1)")
      output_array+=("NodeID=$(echo "!$(printf "%08x\n" $(echo "$output" | grep -oP '"myNodeNum":\s*\K\d+' | head -n 1))")")
      output_array+=("Nodenum=$(echo "$output" | grep -oP '"myNodeNum":\s*\K\d+' | head -n 1)")
      output_array+=("TX enabled=$(echo "$output" | grep -oP '"txEnabled":\s*\K\w+')")
      use_preset=$(echo "$output" | grep -oP '"usePreset":\s*\K\w+')
      output_array+=("Use preset=$use_preset")
      if [ "$use_preset" = "true" ]; then # if use-preset is true, then display the preset
        output_array+=("Preset=$(echo "$output" | grep -oP '"modemPreset":\s*"\K[^"]+')")
      else # otherwise, display the lora settings
        output_array+=("Bandwidth=$(echo "$output" | grep -oP '"bandwidth":\s*\K\w+')")
        output_array+=("Spread factor=$(echo "$output" | grep -oP '"spreadFactor":\s*\K\w+')")
        output_array+=("Coding rate=$(echo "$output" | grep -oP '"codingRate":\s*\K\w+')")
      fi
      output_array+=("Role=$(echo "$output" | grep -oP '"role":\s*"\K[^"]+' | head -n 1)")
      freq_offset=$(echo "$output" | grep -oP '"bandwidth":\s*\K\w+')
      if [ "$freq_offset" != 0 ]; then # only display frequency offset if not 0
        output_array+=("Override freq=$freq_offset")
      fi
      output_array+=("Region=$(echo "$output" | grep -oP '"region":\s*"\K[^"]+')")
      output_array+=("Hop limit=$(echo "$output" | grep -oP '"hopLimit":\s*\K\w+')")
      freq_slot=$(echo "$output" | grep -oP '"channelNum":\s*\K\d+' | head -n 1)
      if [ "$freq_slot" != 0 ]; then # only display frequency slot if not 0
        freq_slot+=("Freq slot=$freq_slot")
      fi
      override_freq=$(echo "$output" | grep -oP '"overrideFrequency":\s*\K[0-9.]+')
      if [ "$override_freq" != "0" ]; then # only display override frequency if not 0
        output_array+=("Over. freq=$override_freq")
      fi
      output_array+=("Public key=$(echo "$output" | grep -oP '"publicKey":\s*"\K[^"]+' | head -n 1)")
      output_array+=("Nodes in db=$(echo "$output" | grep -oP '"![a-zA-Z0-9]+":\s*\{' | wc -l)")
      # now, echo the array
      for pair in "${output_array[@]}"; do
        key=$(echo "$pair" | cut -d'=' -f1)
        value=$(echo "$pair" | cut -d'=' -f2-)
        echo "$key:$value"
      done
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
      meshtastic_update "--seturl $OPTARG" 3 "Set URL"
      ;;
    u) # Option -u (get public key)
      meshtastic_update " --get security.public_key" 3 "Get public key" | sed -n 's/.*base64:\([A-Za-z0-9+/=]*\).*/\1/p'
      ;;
    U) # Option -U (set public key)
      meshtastic_update " --set security.public_key base64:$OPTARG" 3 "Set public key"
      ;;
    r) # Option -r (get private key)
      meshtastic_update " --get security.private_key" 3 "Get private key" | sed -n 's/.*base64:\([A-Za-z0-9+/=]*\).*/\1/p'
      ;;
    R) # Option -R (set private key)
      meshtastic_update " --set security.private_key base64:$OPTARG" 3 "Set private key"
      ;;
    a) # Option -a (view admin keys)
      echo "Getting admin keys..."
      keys=$(meshtastic --host --get security.admin_key | grep -oP '(?<=base64:)[^,"]+' | sed "s/'//g" | sed "s/]//g" | nl -w1 -s'. ' | sed 's/^/|n/' | tr '\n' ' ')  #add look for errors
      echo "${keys:- none}"
      ;;
    A) # Option -A (add admin key)
      meshtastic_update "--set security.admin_key base64:$OPTARG" 3 "Set admin key"
      ;;
    c) # Option -c (clear admin key list)
      meshtastic_update "--set security.admin_key 0" 3 "Clear admin keys"
      ;;
    p) # Option -p (view current legacy admin state)
        state=$(meshtastic_update "--get security.admin_channel_enabled" 3 "Get legacy admin state" 2>/dev/null)
        if echo "$state" | grep -q "True"; then
          echo -e "\033[0;34menabled\033[0m"
        elif echo "$state" | grep -q "False"; then
          echo -e "\033[0;31mdisabled\033[0m"
        elif echo "$state" | grep -q "Error"; then
          echo -e "\033[0;31merror\033[0m"
        fi
      ;;
    o) # Option -o (set legacy admin true/false)
      meshtastic_update "--set security.admin_channel_enabled $OPTARG" 3 "Set legacy admin state"
      ;;
    w) # Option -w (mesh connectivity test)
      for ((i=0; i<=2; i++)); do
        if meshtastic --host --ch-index 0 --sendtext "test" --ack 2>/dev/null | grep -q "ACK"; then
          echo -e "Received acknowledgement...\n\n\033[0;34mMesh connectivity confirmed!\033[0m"
          exit 0
        else
          echo "No response, retrying... ($((i + 1)))"
        fi
      done
      echo -e "\033[0;31mFailed after 3 attempts.\033[0m"
      ;;
    s) # Option -s (start/restart Meshtasticd service)
      systemctl restart meshtasticd
      echo "Meshtasticd service started/restarted."
      ;;
    M) # Option -M (Meshtasticd Service disable/enable)
      if [ "$OPTARG" = "enable" ]; then
        systemctl enable meshtasticd
        systemctl restart meshtasticd
      elif [ "$OPTARG" = "disable" ]; then
        systemctl disable meshtasticd
        systemctl stop meshtasticd
      else
        echo "-M argument requires either \"enable\" or \"disable\""
        echo -e "$help"
      fi
      ;;
    S) # Option -S (Get Meshtasticd Service state)
      if systemctl is-enabled meshtasticd &>/dev/null; then
        if echo "$(systemctl status meshtasticd)" | grep -q "active (running)"; then
          echo -e "\033[4m\033[0;34menabled and running\033[0m"
        elif echo "$(systemctl status meshtasticd)" | grep -q "inactive (dead)"; then
          echo -e "\033[4m\033[0;31menabled but not running\033[0m"
        else
          echo "unknown"
        fi
      else
        echo -e "\033[4m\033[0;31mdisabled\033[0m"
      fi
      ;;
    t) # Option -t (stop Meshtasticd service)
      systemctl stop meshtasticd
      echo "Meshtasticd service stopped."
      ;;
    z) # Option -z (upgrade meshtasticd)
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