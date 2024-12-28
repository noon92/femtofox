#!/bin/bash
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Try \`sudo femto-config\`."
   exit 1
fi

wpa_supplicant_conf="/etc/wpa_supplicant/wpa_supplicant.conf"
help=$(cat <<EOF
Options are:
-h             This message
-s "SSID"      Set wifi SSID
-p "PSK"       Set wifi PSK (password)
-c "COUNTRY"   Set wifi 2-letter country code (such as US, DE)
EOF
)

# Initialize variables
verbose="false"
updated_wifi="false"
ssid=""
psk=""
country=""

if [ $# -eq 0 ]; then
  echo "No arguments provided."
  echo -e "$help"
  exit 1
fi

# Parse options
while getopts ":s:p:c:h" opt; do
  case ${opt} in
    s)  # Option -s (ssid)
      sed -i "/ssid=/s/\".*\"/\"$OPTARG\"/" "$wpa_supplicant_conf"
      echo "Setting SSID to $OPTARG."
      updated_wifi="true"
      ;;
    p)  # Option -p (psk)
      sed -i "/psk=/s/\".*\"/\"$OPTARG\"/" "$wpa_supplicant_conf"
      echo "Setting PSK to $OPTARG."
      updated_wifi="true"
      ;;
    c) # Option -c (country)
      sed -i "/country=/s/=[^ ]*/=$OPTARG/" "/etc/wpa_supplicant/wpa_supplicant.conf"
      echo "Setting country to $OPTARG."
      updated_wifi="true"
      ;;
    h) # Option -h (help)
      echo -e "$help"
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

if [ "$updated_wifi" = true ]; then
  systemctl restart wpa_supplicant
  wpa_cli -i wlan0 reconfigure # <-------- add watch for FAIL response, error out
  timeout 30s dhclient -v
  echo "wpa_supplicant.conf updated and wifi restarted. Enabling Meshtastic wifi setting."
  updatemeshtastic.sh "--set network.wifi_enabled true" 10 "USB config" #| tee -a /tmp/femtofox-config.log
  if [ $? -eq 1 ]; then
    echo "Update of Meshtastic FAILED."
  else
    echo "Updated Meshtastic successfully."
  fi
fi
