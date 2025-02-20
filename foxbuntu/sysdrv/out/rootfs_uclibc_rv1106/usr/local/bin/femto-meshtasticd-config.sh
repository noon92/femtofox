#!/bin/bash
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Try \`sudo femto-meshtasticd-config\`."
   exit 1
fi

help=$(cat <<EOF
Options are:
-h             This message
-i             Get important node info
-C "all"       Get node configuration, by category. Multiple categories can be selected by comma delineation. \`quiet\`: do not echo to console. Options are \`quiet\`, \`all\`, \`nodeinfo\`, \`settings\`, \`channels\`
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
    local output=$(meshtastic --host $command 2>&1 | tee $(if [ -e /dev/tty ]; then echo /dev/tty; else echo /dev/ttyFIQ0; fi))
    logger $output
    if echo "$output" | grep -qiE "Abort|invalid|Error|refused|Errno"; then
      if [ "$retries" -lt $attempts ]; then
        local msg="${ref:+$ref}Meshtastic command failed, retrying ($(($retries + 1))/$attempts)..."
        echo "$msg"
        logger "$msg"
        femto-meshtasticd-config.sh -s
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
    echo -e "$output"
    msg="${ref:+$ref}Meshtastic command FAILED."
    echo "$msg"
    logger "$msg"
    exit 1 # always exit script if failed
  fi
}

get_meshtastic_settings() {
  for retries in $(seq 1 3); do
    if meshtastic_info=$(meshtastic --host --info); then # if successful
      success="true"
      break
    else # if failed
      if [ "$retries" -lt 3 ]; then # if under 3 retries
        echo "Meshtastic command failed, retrying ($(($retries + 1))/3)..."
        femto-meshtasticd-config.sh -s
        sleep 2 # Add a small delay before retrying
      fi
    fi
  done
  if [ -z "$success" ]; then # if failed all retries
    echo "Meshtastic command FAILED."
    exit 1 # always exit script if failed
  fi

  if [[ "$1" == *"all"*  ]] || [[ "$1" == *"nodeinfo"* ]]; then
    # myInfo
    eval "myInfo_owner='$(echo "$meshtastic_info" | grep "^Owner: " | sed 's/^Owner: //')'"
    [[ "$1" != *"quiet"*  ]] && echo "myInfo_owner:$myInfo_owner"
    while IFS="=" read -r varname value; do
      eval "myInfo_$varname='$value'"  # Create a variable with the formatted name
      [[ "$1" != *"quiet"*  ]] && echo "myInfo_$varname:$value"
    done < <(
      echo "$(echo "$meshtastic_info" | grep '^My info: ' | sed 's/^My info: //')" | 
      jq -r 'to_entries[] | "\(.key)=\(.value)"'
    )

    # metadata
    while IFS="=" read -r varname value; do
      eval "metadata_$varname='$value'"  # Create a variable with the formatted name
      [[ "$1" != *"quiet"*  ]] && echo "metadata_$varname:$value"
    done < <(
      echo "$(echo "$meshtastic_info" | grep '^Metadata: ' | sed 's/^Metadata: //')" | 
      jq -r 'to_entries[] | "\(.key)=\(.value)"'
    )
    metadata_nodedbCount=$(echo "$meshtastic_info" | grep -oP '"![a-zA-Z0-9]+":\s*\{' | wc -l)
    [[ "$1" != *"quiet"*  ]] && echo "metadata_nodedbCount:$metadata_nodedbCount"

    # nodeinfo
    while IFS='=' read -r var value; do
      eval "nodeinfo_$var=\"$value\""
      [[ "$1" != *"quiet"*  ]] && echo "nodeinfo_$var:$value"
    done < <(echo "$(echo "$meshtastic_info" | sed -n '/Nodes in mesh:/,$p' | sed '1s/^Nodes in mesh: *//' | sed '/^[[:space:]]*$/q' | jq -r 'to_entries | .[0] | "\(.key)=\(.value)"' | sed 's/^[^=]*=//;s/^[ \t]*}//')" | jq -r '
      def recurse:
        if type == "object" then
          to_entries | .[] | "\(.key)=\(.value | recurse)"
        elif type == "array" then
          . | tostring
        else
          .
        end;
      recurse' | sed '/=/ {s/\(.*\)=\(.*\)=/\1_\2=/; }'
    )
  fi

  if [[ "$1" == *"all"*  ]] || [[ "$1" == *"settings"* ]]; then
    # settings
    while IFS="=" read -r varname value; do
      eval "$varname='$value'"
      [[ "$1" != *"quiet"*  ]] && echo "$varname:$value"
    done < <(
      echo "$(echo "$meshtastic_info" | sed -n '/Preferences: {/,$p' | sed '1s/.*/{/; /^[[:space:]]*$/q')" | 
      jq -r 'to_entries[] | select(.value | type == "object") | .key as $block | .value | to_entries[] | "\($block)_\(.key)=\(.value)"'
    )

    # module settings
    while IFS="=" read -r varname value; do
      eval "$varname='$value'"
      [[ "$1" != *"quiet"*  ]] && echo "$varname:$value"
    done < <(
      echo "$(echo "$meshtastic_info" | sed -n '/Module preferences: {/,$p' | sed '1s/.*/{/; /^[[:space:]]*$/q')" | 
      jq -r 'to_entries[] | select(.value | type == "object") | .key as $block | .value | to_entries[] | "\($block)_\(.key)=\(.value)"'
    )
  fi

  if [[ "$1" == *"all"*  ]] || [[ "$1" == *"channels"* ]]; then
    # channels
    while read index line; do
      channel_type=$(echo "$line" | awk '{print $3}')
      psk_type=$(echo "$line" | grep -o 'psk=[^ ]*' | cut -d= -f2)
      eval "channel${index}_type='$channel_type'"
      [[ "$1" != *"quiet"*  ]] && echo "channel${index}_type:$channel_type"
      eval "channel${index}_psk_type='$psk_type'"
      [[ "$1" != *"quiet"*  ]] && echo "channel${index}_psk_type:$psk_type"

      # get the json portion of the channel listing
      while IFS=":" read -r key value; do
        eval "$key='$value'"
        [[ "$1" != *"quiet"*  ]] && echo "$key:$value"
      done < <(
        echo "$(echo "$line" | sed 's/.*\({.*\)/\1/')" | jq -r 'to_entries | .[] | "channel'${index}'_\(.key):\(.value)"'
      )
    done < <(
      echo "$meshtastic_info" | awk '/Channels:/ {f=1; next} f && NF {print} f && !NF {exit}' | nl -v 0
    )

    eval "url_primary_channel='$(echo "$meshtastic_info" | sed -n 's/^Primary channel URL: //p')'"
    [[ "$1" != *"quiet"*  ]] && echo "url_primary_channel:$url_primary_channel"
    if echo "$meshtastic_info" | grep -q "^Complete URL (includes all channels): "; then
      url_all_channels=$(echo "$meshtastic_info" | sed -n 's/^Complete URL (includes all channels): //p')
      [[ "$1" != *"quiet"* ]] && echo "url_all_channels:$url_all_channels"
    fi
  fi
}

# Parse options
while getopts ":hiC:gkl:q:uU:rR:aA:cpo:sM:Stwuxm" opt; do
  case ${opt} in
    h) # Option -h (help)
      echo -e "$help"
      ;;
    i) # Option -i (Get important node info)
      get_meshtastic_settings quiet,nodeinfo,settings
      echo -e "\
Service:$(femto-meshtasticd-config.sh -S)
Version:$metadata_firmwareVersion
Node name:$myInfo_owner
NodeID:$nodeinfo_user_id
Nodenum:$myInfo_myNodeNum
TX enabled:$lora_txEnabled
Use preset:$lora_usePreset
Preset:$lora_modemPreset
Bandwidth:$lora_bandwidth
Spread factor:$lora_spreadFactor
Coding rate:$lora_codingRate
Role:$device_role
Freq offset:$lora_frequencyOffset
Region:$lora_region
Hop limit:$lora_hopLimit
Freq slot:$lora_channelNum
Override freq:$lora_overrideFrequency
Public key:$security_publicKey
Nodes in db:$metadata_nodedbCount"

      ;;
    C) # Option -C (Complete node config)
      get_meshtastic_settings $OPTARG
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