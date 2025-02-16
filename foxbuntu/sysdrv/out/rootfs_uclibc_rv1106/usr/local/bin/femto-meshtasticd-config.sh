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
-m             Meshtastic update tool. Syntax: \`femto-meshtasticd-config.sh -m '--set security.admin_channel_enabled false' 10 'Disable legacy admin'\`
               Will retry the \`--set security.admin_channel_enabled false\` command until successful or up to 10 times, and tag status reports with \`Disable legacy admin\` via echo and to system log.
Meshtastic LoRa settings:
-e "value"     Region (frequency plan). Options are: UNSET, US, EU_433, EU_868, CN, JP, ANZ, KR, TW, RU ,IN, NZ_865, TH, LORA_24, UA_433, UA_868, MY_433, MY_919, SG_923
-P "true"      Use modem preset (true, false)
-E "value"     Preset. Options are: LONG_FAST, LONG_SLOW, VERY_LONG_SLOW, MEDIUM_SLOW, MEDIUM_FAST, SHORT_SLOW, SHORT_FAST, SHORT_TURBO
-b "value"     Bandwidth (only used if modem preset is disabled)
-f "value"     Spread Factor (only used if modem preset is disabled)
-C "value"     Coding rate (only used if modem preset is disabled)
-O "value"     Frequency offset (MHz)
-H "value"     Hop limit (0-7)
-T "true"      TX enabled (true/false)
-X "value"     TX power (dBm)
-F "value"     Frequency slot
-V "false"     Override duty cycle (true/false)
-B "true"      SX126X RX boosted gain (true/false)
-v "value"     Override frequency (MHz) (overrides frequency slot)
-G "false"     Ignore MQTT (true/false)
-K "false"     OK to MQTT (true/false)
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
    local output=$(meshtastic --host $command | tee /dev/tty) #>&2 lets meshtastic's output display on screen
    logger $output
    if echo "$output" | grep -qiE "Abort|invalid|Error|refused|Errno"; then
      if [ "$retries" -lt $attempts ]; then
        local msg="${ref:+$ref}Meshtastic command failed, retrying ($(($retries + 1))/$attempts)..."
        femto-meshtasticd-config.sh -s
        echo "$msg"
        logger "$msg"
        sleep 2 # Add a small delay before retrying
      fi
    else
      local success="true"
      echo -e "$output"
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
    echo -e "$output"
    msg="${ref:+$ref}Meshtastic command FAILED."
    echo "$msg"
    logger "$msg"
    exit 1 # always exit script if failed
  fi
}

# Parse options
while getopts ":higkl:q:uU:rR:aA:cpo:sM:StwuxmP:E:b:f:C:O:e:H:T:X:F:V:B:v:G:K:" opt; do
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
        output_array+=("Freq offset=$freq_offset")
      fi
      output_array+=("Region=$(echo "$output" | grep -oP '"region":\s*"\K[^"]+')")
      output_array+=("Hop limit=$(echo "$output" | grep -oP '"hopLimit":\s*\K\w+')")
      freq_slot=$(echo "$output" | grep -oP '"channelNum":\s*\K\d+' | head -n 1)
      if [ "$freq_slot" != 0 ]; then # only display frequency slot if not 0
        freq_slot+=("Freq slot=$freq_slot")
      fi
      override_freq=$(echo "$output" | grep -oP '"overrideFrequency":\s*\K[0-9.]+')
      if [ "$override_freq" != "0.0" ]; then # only display override frequency if not 0.0
        output_array+=("Override freq=$override_freq")
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
      ls /etc/meshtasticd/config.d 2>/dev/null | grep '^femtofox_' | xargs -r -n 1 basename | sed 's/^femtofox_//;s/\.yaml$//' | grep . || echo -e "\033[0;31mnone (simulated radio)\033[0m"
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
      elif [ "$OPTARG" = "lora-meshstick-1262" ]; then
        eval $prepare
        cp /etc/meshtasticd/available.d/lora-meshstick-1262.yaml /etc/meshtasticd/config.d/femtofox_lora-meshstick-1262.yaml # ugly code for the special case of the meshstick, which is not femto. Allows it to be detected by femto scripts and removed if radio changes
        systemctl restart meshtasticd
      elif [ "$OPTARG" = "none" ]; then
        eval $prepare
        systemctl restart meshtasticd
      else
        echo "$OPTARG is not a valid option. Options are \`lr1121_tcxo\`, \`sx1262_tcxo\`, \`sx1262_xtal\`, \`lora-meshstick-1262\`, \`none\` (simradio)"
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
      femto-utils.sh -C "meshtasticd" # this functionality has been moved
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
    e) # Option -e (Set region/frequency plan)
      regions="UNSET US EU_433 EU_868 CN JP ANZ KR TW RU IN NZ_865 TH LORA_24 UA_433 UA_868 MY_433 MY_919 SG_923"
      if [[ ! " $regions " =~ " $OPTARG " ]]; then
        echo "Error: Invalid option '$OPTARG'. Must be one of $regions." >&2
        echo -e "$help"
        exit 1
      else
        meshtastic_update "--set lora.region $OPTARG" 3 "Set region"
      fi
      ;;
    P) # Option -P (Use modem preset: enable/disable)
      options="true false"
      if [[ ! " $options " =~ " $OPTARG " ]]; then
        echo "Error: Invalid option '$OPTARG'. Must be one of $options." >&2
        echo -e "$help"
        exit 1
      else
        meshtastic_update "--set lora.use_preset $OPTARG" 3 "Set use_preset"
      fi
      ;;
    E) # Option -E (Preset. Options are: LONG_FAST, LONG_SLOW, VERY_LONG_SLOW, MEDIUM_SLOW, MEDIUM_FAST, SHORT_SLOW, SHORT_FAST, SHORT_TURBO)
      presets="LONG_FAST LONG_SLOW VERY_LONG_SLOW MEDIUM_SLOW MEDIUM_FAST SHORT_SLOW SHORT_FAST SHORT_TURBO"
      if [[ ! " $presets " =~ " $OPTARG " ]]; then
        echo "Error: Invalid option '$OPTARG'. Must be one of $presets." >&2
        echo -e "$help"
        exit 1
      else
        meshtastic_update "--set lora.modem_preset $OPTARG" 3 "Set modem_preset"
      fi
      ;;
    b) # Option -b (Set bandwidth; used if modem preset is disabled)
      options="31 62 125 250 500"
      if [[ ! " $options " =~ " $OPTARG " ]]; then
        echo "Error: Invalid option '$OPTARG'. Must be one of $options." >&2
        echo -e "$help"
        exit 1
      else
        meshtastic_update "--set lora.bandwidth $OPTARG" 3 "Set bandwidth"
      fi
      ;;
    f) # Option -f (Set spread factor; used if modem preset is disabled)
      options="7 8 9 10 11 12"
      if [[ ! " $options " =~ " $OPTARG " ]]; then
        echo "Error: Invalid option '$OPTARG'. Must be one of $options." >&2
        echo -e "$help"
        exit 1
      else
        meshtastic_update "--set lora.spread_factor $OPTARG" 3 "Set spread_factor"
      fi
      ;;
    C) # Option -C (Set coding rate; used if modem preset is disabled)
      options="5 6 7 8"
      if [[ ! " $options " =~ " $OPTARG " ]]; then
        echo "Error: Invalid option '$OPTARG'. Must be one of $options." >&2
        echo -e "$help"
        exit 1
      else
        meshtastic_update "--set lora.coding_rate $OPTARG" 3 "Set coding_rate"
      fi
      ;;
    O) # Option -O (Set frequency offset in MHz)
      if ! [[ "$OPTARG" =~ ^[0-1000000]$ ]]; then
        echo "Error: Invalid option '$OPTARG'. Must be a number between 0 and 1000000." >&2
        echo -e "$help"
        exit 1
      else
        meshtastic_update "--set lora.frequency_offset $OPTARG" 3 "Set frequency_offset"
      fi
      ;;
    H) # Option -H (Set hop limit, range 0-7)
      if ! [[ "$OPTARG" =~ ^[0-7]$ ]]; then
        echo "Error: Invalid option '$OPTARG'. Must be a number between 0 and 7." >&2
        echo -e "$help"
        exit 1
      else
        meshtastic_update "--set lora.hop_limit $OPTARG" 3 "Set hop limit"
      fi
      ;;
    T) # Option -T (Enable/disable TX)
      options="true false"
      if [[ ! " $options " =~ " $OPTARG " ]]; then
        echo "Error: Invalid option '$OPTARG'. Must be one of $options." >&2
        echo -e "$help"
        exit 1
      else
        meshtastic_update "--set lora.tx_enabled $OPTARG" 3 "Set hop limit"
      fi
      ;;
    X) # Option -X (Set TX power in dBm)
      if ! [[ "$OPTARG" =~ ^([0-9]|1[0-9]|2[0-9]|30)$ ]]; then
        echo "Error: Invalid option '$OPTARG'. Must be a number between 0 and 30." >&2
        echo -e "$help"
        exit 1
      else
        meshtastic_update "--set lora.tx_power $OPTARG" 3 "Set tx_power"
      fi
      ;;
    F) # Option -F (Set frequency slot)
      meshtastic_update "--set lora.channel_num $OPTARG" 3 "Set frequency slot"
      ;;
    V) # Option -V (Enable/disable override duty cycle)
      options="true false"
      if [[ ! " $options " =~ " $OPTARG " ]]; then
        echo "Error: Invalid option '$OPTARG'. Must be one of $options." >&2
        echo -e "$help"
        exit 1
      else
        meshtastic_update "--set lora.override_duty_cycle $OPTARG" 3 "Set override_duty_cycle"
      fi
      ;;
    B) # Option -B (Enable/disable SX126X RX boosted gain)
      options="true false"
      if [[ ! " $options " =~ " $OPTARG " ]]; then
        echo "Error: Invalid option '$OPTARG'. Must be one of $options." >&2
        echo -e "$help"
        exit 1
      else
        meshtastic_update "--set lora.sx126x_rx_boosted_gain $OPTARG" 3 "Set sx126x_rx_boosted_gain"
      fi
      ;;
    v) # Option -v (Override frequency in MHz; overrides frequency slot)
      meshtastic_update "--set lora.override_frequency $OPTARG" 3 "Set override_frequency"
      ;;
    G) # Option -G (enable/disable ignore MQTT)
      options="true false"
      if [[ ! " $options " =~ " $OPTARG " ]]; then
        echo "Error: Invalid option '$OPTARG'. Must be one of $options." >&2
        echo -e "$help"
        exit 1
      else
        meshtastic_update "--set lora.ignore_mqtt $OPTARG" 3 "Set ignore_mqtt"
      fi
      ;;
    K) # Option -K (enable/disable OK to MQTT)
      options="true false"
      if [[ ! " $options " =~ " $OPTARG " ]]; then
        echo "Error: Invalid option '$OPTARG'. Must be one of $options." >&2
        echo -e "$help"
        exit 1
      else
        meshtastic_update "--set lora.config_ok_to_mqtt $OPTARG" 3 "Set config_ok_to_mqtt"
      fi
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