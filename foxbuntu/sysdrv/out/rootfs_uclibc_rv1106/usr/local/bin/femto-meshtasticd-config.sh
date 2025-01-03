#!/bin/bash
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Try \`sudo femto-meshtasticd-config\`."
   exit 1
fi

help=$(cat <<EOF
Options are:
-h             This message
-g             Gets the current configuration URL and QR code
-k             Get current LoRa radio selection
-l "RADIO"     Choose LoRa radio model. Options are \`lr1121_tcxo\`, \`sx1262_tcxo\`, \`sx1262_xtal\`, \`none\` (simradio)
-q "URL"       Set configuration URL
-v             View current admin keys
-a "KEY"       Set admin key
-c             Clear admin keys
-e             Enable legacy admin channel
-d             Disable legacy admin channel
-o "true"      Set legacy admin channel state (true/false), case sensitive
-s             Start/restart Meshtasticd Service
-t             Stop Meshtasticd Service
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
        local msg="${ref:+$ref}Meshtastic update failed, retrying ($(($retries + 1))/$attempts)..."
        echo "$msg"
        logger "$msg"
        sleep 2 # Add a small delay before retrying
      fi
    else
      local success="true"
      msg="${ref:+$ref}Meshtastic update successful!"
      echo "$msg"
      logger "$msg"
      if [ -n "$external" ]; then
        exit 0
      fi
      return
    fi
  done
  if [ -z "$success" ]; then
    msg="${ref:+$ref}Meshtastic update FAILED."
    echo "$msg"
    logger "$msg"
    if [ -n "$external" ]; then
      exit 1
    fi
  fi
}

# Parse options
while getopts ":hgkl:q:va:cedo:struxm" opt; do
  case ${opt} in
    h) # Option -h (help)
      echo -e "$help"
      ;;
    g) # Option -g (get config URL)
      echo "Getting current Meshtastic QR code and URL..."
      url=$(meshtastic --host --qr-all | grep -oP '(?<=Complete URL \(includes all channels\): )https://[^ ]+')
      echo "$url" | qrencode -o - -t UTF8 -s 1
      echo "Meshtastic configuration URL:"
      echo $url
      ;;
    k) # Option -k (get current lora radio model)
      ls /etc/meshtasticd/config.d/femtofox* | xargs -n 1 basename | sed 's/^femtofox_//;s/\.yaml$//'
      ;;
    l) # Option -l (choose lora radio model)
      prepare="rm -f /etc/meshtasticd/config.d/femtofox* && echo \"Radio type $OPTARG selected.\" && systemctl restart meshtasticd"
      if [ "$OPTARG" = "lr1121_tcxo" ]; then
        eval $prepare
        cp /etc/meshtasticd/available.d/femtofox/femtofox_LR1121_TCXO.yaml /etc/meshtasticd/config.d
      elif [ "$OPTARG" = "sx1262_tcxo" ]; then
        eval $prepare
        cp /etc/meshtasticd/available.d/femtofox/femtofox_SX1262_TCXO.yaml /etc/meshtasticd/config.d
      elif [ "$OPTARG" = "sx1262_xtal" ]; then
        eval $prepare
        cp /etc/meshtasticd/available.d/femtofox/femtofox_SX1262_XTAL.yaml /etc/meshtasticd/config.d
      elif [ "$OPTARG" = "none" ]; then
        eval $prepare
      else
        echo "$OPTARG is not a valid option. Options are \`lr1121_tcxo\`, \`sx1262_tcxo\`, \`sx1262_xtal\`, \`none\` (simradio)"
      fi
      ;;
    q) # Option -q (set config URL)
      meshtastic_update "--seturl $OPTARG" 10 "Set URL"
      ;;
    v) # Option -v (view admin keys)
      echo "Getting admin keys..."
      keys=$(meshtastic --host --get security.admin_key | grep -oP '(?<=base64:)[^,"]+' | sed "s/'//g" | sed "s/]//g" | nl -w1 -s'. ' | sed 's/^/|n/' | tr '\n' ' ')
      echo "${keys:-none}"
      ;;
    a) # Option -a (add admin key)
      meshtastic_update "--set security.admin_key base64:$OPTARG" 10 "Set admin key"
      ;;
    c) # Option -c (clear admin key list)
      meshtastic_update "--set security.admin_key 0" 10 "Set admin key"
      ;;
    e) # Option -e (enable legacy admin)
      meshtastic_update "--set security.admin_channel_enabled true" 10 "Enable legacy admin"
      ;;
    d) # Option -d (disable legacy admin)
      meshtastic_update "--set security.admin_channel_enabled false" 10 "Disable legacy admin"
      ;;
    o) # Option -o (set legacy admin true/false)
      meshtastic_update "--set security.admin_channel_enabled $OPTARG" 10 "Disable legacy admin"
      ;;
    s) # Option -s (start/restart Meshtasticd service)
      systemctl restart meshtasticd
      echo "Meshtasticd service started/restarted."
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