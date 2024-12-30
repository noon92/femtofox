#!/bin/bash
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Try \`sudo femto-wifi-config\`."
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
-u             Upgrade Meshtasticd
-r             Uninstall Meshtasticd
EOF
)

if [ $# -eq 0 ]; then
  echo "No arguments provided."
  echo -e "$help"
  exit 1
fi

# Parse options
while getopts ":hgkl:q:va:cedur" opt; do
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
      updatemeshtastic.sh "--seturl $OPTARG" 10 "Set URL"
      ;;
    v) # Option -v (view admin keys)
      echo "Getting admin keys..."
      keys=$(meshtastic --host --get security.admin_key | grep -oP '(?<=base64:)[^,"]+' | sed "s/'//g" | sed "s/]//g" | nl -w1 -s'. ' | sed 's/^/|n/' | tr '\n' ' ')
      echo "${keys:-none}"
      ;;
    a) # Option -a (add admin key)
      updatemeshtastic.sh "--set security.admin_key base64:$OPTARG" 10 "Set admin key"
      ;;
    c) # Option -c (clear admin key list)
      updatemeshtastic.sh "--set security.admin_key 0" 10 "Set admin key"
      ;;
    e) # Option -e (enable legacy admin)
      updatemeshtastic.sh "--set security.admin_channel_enabled true" 10 "Enable legacy admin"
      ;;
    d) # Option -d (disable legacy admin)
      updatemeshtastic.sh "--set security.admin_channel_enabled false" 10 "Disable legacy admin"
      ;;
    u) # Option -u (upgrade meshtasticd)
      apt update
      apt install --only-upgrade meshtasticd
      ;;
    r) # Option -r (uninstall meshtasticd)

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