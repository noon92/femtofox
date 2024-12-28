#!/bin/bash
wpa_supplicant_conf="/etc/wpa_supplicant/wpa_supplicant.conf"
help="Options are -v (verbose mode), -s (ssid), -p (PSK), -c (country)."

# Initialize variables
verbose="false"
updated_wifi="false"
ssid=""
psk=""
country=""

if [ $# -eq 0 ]; then
  echo "No arguments provided."
  echo "$help"
  exit 1
fi

# Parse options
while getopts ":s:p:c:" opt; do
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
    \?)  # Invalid option
      echo "Invalid option: -$OPTARG."
      echo "$help"
      exit 1
      ;;
    :) # Missing argument for option
      echo "Option -$OPTARG requires an argument."
      echo "$help"
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
