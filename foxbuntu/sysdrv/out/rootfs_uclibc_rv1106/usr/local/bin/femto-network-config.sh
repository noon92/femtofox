#!/bin/bash
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Try \`sudo femto-wifi-config\`."
  exit 1
fi

wpa_supplicant_conf="/etc/wpa_supplicant/wpa_supplicant.conf"
help=$(cat <<EOF
Options are:
-h             This message
-s "SSID"      Set wifi SSID
-p "PSK"       Set wifi PSK (password)
-c "COUNTRY"   Set wifi 2-letter country code (such as US, DE)
-r             Restart wifi
-e             Get ethernet settings
-w             Get wifi settings
-t             Test internet connection

To set wifi settings, use -r as last argument to trigger reset after wpa_supplicant.conf is modified.
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
while getopts ":hs:p:c:ewtr" opt; do
  case ${opt} in
    h) # Option -h (help)
      echo -e "$help"
      ;;
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
    e) # Option -e (ethernet settings)
      echo "IPv4 Address: $(ifconfig eth0 | grep 'inet ' | awk '{print $2}')\n
IPv6 Address: $(ifconfig eth0 | grep 'inet6 ' | awk '{print $2}')\n\
MAC Address:  $(ifconfig eth0 | grep 'ether ' | awk '{print $2}')"
      ;;
    w) # Option -w (wifi settings)
      wifi_country=$(grep -m 1 "^country=" "$wpa_supplicant_conf" | cut -d '=' -f 2)
      wifi_ssid=$(grep -m 1 '^\s*ssid=' "$wpa_supplicant_conf" | cut -d '"' -f 2)
      wifi_psk=$(grep -m 1 '^\s*psk=' "$wpa_supplicant_conf" | cut -d '"' -f 2)
      if [ "$(cat /root/.portduino/default/prefs/config.proto | protoc --decode_raw | awk '/4 {/, /}/ {if ($1 == "1:") print $2}')" -eq 1 ]; then
        mesh_wifi_status="enabled"
      else
        mesh_wifi_status="disabled"
      fi
      echo "\
SSID:            $wifi_ssid\n\
Password:        $wifi_psk\n\
Country:         $wifi_country\n\
Meshtastic wifi: $mesh_wifi_status\n\
\n\
Connected to:    $(iwconfig 2>/dev/null | grep -i 'ESSID' | awk -F 'ESSID:"' '{print $2}' | awk -F '"' '{print $1}')\n\
Signal Strength: $(iwconfig 2>/dev/null | grep -i 'Signal level' | awk -F 'Signal level=' '{print $2}' | awk '{print $1}')\n\
MAC address:     $(ifconfig wlan0 | grep ether | awk '{print $2}')\n\
Current IP:      $(hostname -I | awk '{print $1}')\n\
For more details, enter \`iwconfig\`." 0 0
      ;;
    t) # Option -t (test internet connection)
      # Define ping targets and initialize counter
      targets=("1.1.1.1" "8.8.8.8")
      successful=0
      count=0
      total=0
      # Ping each target 5 times and count successful pings
      for target in "${targets[@]}"; do
        count=$(ping -c 5 -W 1 "$target" | grep -c 'bytes from') # Count lines with successful pings
        successful=$((successful + count))
        ((total+=5))
      done
      # Use dialog to display message based on successful pings count
      if [ "$successful" -eq 0 ]; then
        echo "No internet connection detected."
      else
        echo "Internet connection is up.\n\nPinged $(echo "${targets[*]}" | sed 's/ /, /g').\nReceived $successful/$total responses."
      fi
      ;;
    r) # Option -r (restart wifi)
      updated_wifi="true"
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
  echo "    Wifi restarted. Enabling Meshtastic wifi setting."
  femto-meshtasticd-config.sh -m "--set network.wifi_enabled true" 10 "USB config" #| tee -a /tmp/femtofox-config.log
  # if [ $? -eq 1 ]; then
  #   echo "Update of Meshtastic FAILED."
  #   exit 1
  # else
  #   echo "Updated Meshtastic successfully."
  #   exit 0
  # fi
fi
