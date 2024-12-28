#!/bin/bash

# Function to handle Wi-Fi settings
wifi_settings() {

  local option=""
  option=$(dialog --menu "Wifi settings" 15 40 4 \
    1 "View wifi settings" \
    2 "Change wifi settings" \
    3 "Back to Main Menu" 3>&1 1>&2 2>&3)
  
  case $option in
    1)
      local name=""
      name=$(dialog --inputbox "Enter device name:" 8 40 3>&1 1>&2 2>&3)
      dialog --msgbox "Device name set to: $name" 8 40
    ;;
    2)
      local wpa_supplicant_conf="/etc/wpa_supplicant/wpa_supplicant.conf"
      local wifi_ssid=""
      local wifi_psk=""
      local wifi_country=""
      wifi_ssid=$(dialog --title "Wifi settings" --inputbox "Enter Wi-Fi SSID:" 8 40 3>&1 1>&2 2>&3)
      wifi_psk=$(dialog --title "Wifi settings" --passwordbox "Enter Wi-Fi Password:" 8 40 3>&1 1>&2 2>&3)
      wifi_country=$(dialog --title "Wifi settings" --inputbox "Enter Country Code (e.g., US, DE):" 8 40 3>&1 1>&2 2>&3)
      sed -i "/country=/s/\".*\"/\"$wifi_country\"/" "$wpa_supplicant_conf"
      sed -i "/ssid=/s/\".*\"/\"$wifi_ssid\"/" "$wpa_supplicant_conf"
      sed -i "/psk=/s/\".*\"/\"$wifi_psk\"/" "$wpa_supplicant_conf"
      systemctl restart wpa_supplicant
      wpa_cli -i wlan0 reconfigure
      echo "wpa_supplicant.conf updated and wifi restarted. Enabling Meshtastic wifi setting."
      timeout 30s dhclient -v
      updatemeshtastic.sh "--set network.wifi_enabled true" 10 "USB config" #| tee -a /tmp/femtofox-config.log
      if [ $? -eq 1 ]; then
        echo "Update of Meshtastic FAILED."
      else
        echo "Updated Meshtastic successfully."
      fi
      dialog --title "Wifi settings" --msgbox "Wi-Fi Settings Saved:\nSSID: $wifi_ssid\nPassword: (hidden)\nCountry: $wifi_country\nMeshtastic wifi setting set to ON" 10 40
    ;;
    3)
      return
    ;;
  esac

}

# Function to handle region settings
region_settings() {
  local region=""
  region=$(dialog --inputbox "Enter Region Code (e.g., US, EU):" 8 40 3>&1 1>&2 2>&3)
  
  dialog --msgbox "Region set to: $region" 8 40
}

# Function to handle timezone settings
timezone_settings() {
  local timezone=""
  timezone=$(dialog --inputbox "Enter Timezone (e.g., America/Los_Angeles):" 8 40 3>&1 1>&2 2>&3)
  
  dialog --msgbox "Timezone set to: $timezone" 8 40
}

# Function to handle Meshtastic CLI settings
meshtastic_settings() {
  local option=""
  option=$(dialog --menu "Meshtastic CLI Options" 15 40 4 \
    1 "Set device name" \
    2 "Configure channel" \
    3 "Check node info" \
    4 "Back to Main Menu" 3>&1 1>&2 2>&3)
  
  case $option in
    1)
      local name=""
      name=$(dialog --inputbox "Enter device name:" 8 40 3>&1 1>&2 2>&3)
      dialog --msgbox "Device name set to: $name" 8 40
    ;;
    2)
      local channel=""
      channel=$(dialog --inputbox "Enter channel ID:" 8 40 3>&1 1>&2 2>&3)
      dialog --msgbox "Channel ID set to: $channel" 8 40
    ;;
    3)
      dialog --msgbox "Node info retrieved successfully!" 8 40
    ;;
    4)
      return
    ;;
  esac
}


export NCURSES_NO_UTF8_ACS=1 # prevents weirdness over tty

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root."
   echo "Try \`sudo femto-config\`."
   exit 1
fi


# Main menu
while true; do
  choice=$(dialog --menu "Femtofox Config" 15 40 5 \
    1 "Wi-Fi" \
    2 "Meshtasticd" \
    3 "Misc" \
    4 "Install third party apps" \
    5 "Run OEM luckfox-config" \
    6 "Help" \
    7 "Exit" 3>&1 1>&2 2>&3)
  
  exit_status=$? # This line checks the exit status of the dialog command
  
  if [ $exit_status -ne 0 ]; then # Exit the loop if the user selects "Cancel" or closes the dialog
    break
  fi
  
  case $choice in
    1) wifi_settings ;;
    2) meshtasticd_settings ;;
    3) misc_settings ;;
    4) 3rd_party ;;
    5) luckfox-config ;;
    6) femto_help ;;
    7) break ;;
    *) dialog --msgbox "Invalid choice, please try again." 8 40 ;;
  esac
done

clear
echo "Goodbye!"