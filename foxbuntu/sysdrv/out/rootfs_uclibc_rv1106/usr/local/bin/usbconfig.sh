#!/bin/bash

# Set the mount point
mount_point="/mnt/usb"

# Function to log both to the screen and syslog
log_message() {
  echo "USB config: $1"  # Echo to the screen
  logger "USB config: $1"  # Log to the system log
  echo "$(date +"%Y-%m-%d %H:%M:%S") $1" >> /tmp/femtofox-config.log # Log to file
}

exit_script() {
  if [ ! -z "$usb_path" ]; then #if usb path is populated
    if ! df -T /mnt/usb 2>/dev/null | grep -qw 'ntfs'; then
      log_message "USB configuration script complete. Copying femtofox-config.log to USB drive."
      cat /tmp/femtofox-config.log >> /mnt/usb/femtofox-config.log
      rm /tmp/femtofox-config.log #maybe replace this with logrotate to preserve a local log, though that would be a duplicate of logger
    else
      log_message "USB configuration script complete. Unable to copy femtofox-config.log to USB drive with NTFS filesystem."
      rm /tmp/femtofox-config.log #maybe replace this with logrotate to preserve a local log, though that would be a duplicate of logger
    fi
  fi
  exit $1
}

#Blink
blink() {
  echo 1 > /sys/class/gpio/gpio34/value; #LED on
  sleep "$1"; #wait
  echo 0 > /sys/class/gpio/gpio34/value; #LED off
}

escape_sed() {
  echo "$1" | sed -e 's/[]\/$*.^[]/\\&/g'
}

# Check if the mount point exists and if a USB drive is plugged in
usb_path=$(lsblk -o NAME,FSTYPE,SIZE,TYPE,MOUNTPOINT | grep -E "vfat|ext4|ntfs|exfat" | grep -E "sd[a-z]([0-9]*)" | awk '{print $1}' | sed 's/[^a-zA-Z0-9]//g' | head -n 1)
full_device_path="/dev/$usb_path" # Construct the full device path

#if [ -d "$mount_point" ]; then
#  rmdir "$mount_point"
#  log_message "/mnt/usb deleted."
#fi

# If no USB device is found, exit
if [ -z "$usb_path" ]; then
  message="No USB drive found."
  echo "USB config: $message"
  logger "USB config: $message"
  exit_script 0
fi

# Create the mount point if it doesn't exist
if [ ! -d "$mount_point" ]; then
  mkdir -p "$mount_point"
fi

# Debugging: Log and echo the extracted device name
log_message "USB device found: $full_device_path"

# Check if the USB drive is already mounted
if mount | grep "$full_device_path" > /dev/null; then
  log_message "USB drive is already mounted."
else
  # Mount the USB drive to the specified mount point
  mount "$full_device_path" "$mount_point"
  if [ $? -eq 0 ]; then
    log_message "USB drive mounted successfully at $mount_point."
  else
    log_message "Failed to mount USB drive."
    blink "5" && sleep "0.5" #boot code
    exit_script 1
  fi
fi

wpa_supplicant_conf="/etc/wpa_supplicant/wpa_supplicant.conf"
usb_config="/tmp/femtofox-config.txt"

# Check if the mounted USB drive contains a file femtofox-config.txt
if [ -f "$mount_point/femtofox-config.txt" ]; then
  log_message "femtofox-config.txt found on USB drive."
  
  # Remove Windows-style carriage returns and save a temporary copy of femtofox-config.txt
  tr -d '\r' < "$mount_point/femtofox-config.txt" > $usb_config
  
  # Initialize variables
  wifi_ssid=""
  wifi_psk=""
  wifi_country=""
  meshtastic_lora_radio=""
  found_config="false"
  update_wifi="false"
  update_meshtastic_url=""
  update_meshtastic_security=""
  
  # Escape and read the fields from the USB config file if they exist
  while IFS='=' read -r key value; do
    value=$(echo "$value" | tr -d '"')
    case "$key" in
      wifi_ssid) wifi_ssid=$(escape_sed "$value") ;;
      wifi_psk) wifi_psk=$(escape_sed "$value") ;;
      wifi_country) wifi_country=$(escape_sed "$value") ;;
      meshtastic_lora_radio) meshtastic_lora_radio=$(escape_sed "$value") ;;
      timezone) timezone=$(escape_sed "$value") ;;
      meshtastic_url) meshtastic_url=$(escape_sed "$value") ;;
      meshtastic_legacy_admin) meshtastic_legacy_admin=$(escape_sed "$value") ;;
      meshtastic_admin_key) meshtastic_admin_key=$(escape_sed "$value") ;;
    esac
  done < <(grep -E '^(wifi_ssid|wifi_psk|wifi_country|meshtastic_lora_radio|timezone|meshtastic_url|meshtastic_legacy_admin|meshtastic_admin_key)=' "$usb_config")
  
  
  # Update wpa_supplicant.conf with the new values, if specified
  if [[ -n "$wifi_country" ]]; then
    # Update or add the country field
    if grep -q "^country=" "$wpa_supplicant_conf"; then
      sed -i "s/^country=.*/country=$wifi_country/" "$wpa_supplicant_conf"
      log_message "Updated Wi-Fi country in wpa_supplicant.conf to $wifi_country."
    else
      echo "country=$wifi_country" >> "$wpa_supplicant_conf"
      log_message "Added Wi-Fi country to wpa_supplicant.conf as $wifi_country."
    fi
    found_config="true"
    update_wifi="true"
  fi
  
  if [[ -n "$wifi_ssid" ]]; then
    # Update the ssid in the network block
    sed -i "/ssid=/s/\".*\"/\"$wifi_ssid\"/" "$wpa_supplicant_conf"
    log_message "Updated Wi-Fi SSID in wpa_supplicant.conf to $wifi_ssid."
    found_config="true"
    update_wifi="true"
  fi
  
  if [[ -n "$wifi_psk" ]]; then
    # Update the psk in the network block
    sed -i "/psk=/s/\".*\"/\"$wifi_psk\"/" "$wpa_supplicant_conf"
    log_message "Updated Wi-Fi PSK in wpa_supplicant.conf."
    found_config="true"
    update_wifi="true"
  fi
  
  
  #get meshtastic_lora_radio model, if specified, and copy appropriate yaml to /etc/meshtasticd/config.d/
  if [[ -n "$meshtastic_lora_radio" ]]; then
    rm -f /etc/meshtasticd/config.d/femtofox*
    found_config="true"
    meshtastic_lora_radio=$(echo "$meshtastic_lora_radio" | tr '[:upper:]' '[:lower:]')
    case "$meshtastic_lora_radio" in
      'ebyte-e22-900m30s')
        cp /etc/meshtasticd/available.d/femtofox/femtofox_SX1262_TCXO.yaml /etc/meshtasticd/config.d
      ;;
      'ebyte-e22-900m22s')
        cp /etc/meshtasticd/available.d/femtofox/femtofox_SX1262_TCXO.yaml /etc/meshtasticd/config.d
      ;;
      'heltec-ht-ra62')
        cp /etc/meshtasticd/available.d/femtofox/femtofox_SX1262_TCXO.yaml /etc/meshtasticd/config.d
      ;;
      'seeed-wio-sx1262')
        cp /etc/meshtasticd/available.d/femtofox/femtofox_SX1262_TCXO.yaml /etc/meshtasticd/config.d
      ;;
      'waveshare-sx126x-xxxm')
        cp /etc/meshtasticd/available.d/femtofox/femtofox_SX1262_XTAL.yaml /etc/meshtasticd/config.d
      ;;
      'ai-thinker-ra-01sh')
        cp /etc/meshtasticd/available.d/femtofox/femtofox_SX1262_XTAL.yaml /etc/meshtasticd/config.d
      ;;
      'ebyte-e80-900m22s')
        #not yet implemented
        cp /etc/meshtasticd/available.d/femtofox/femtofox_LR1121_TCXO.yaml /etc/meshtasticd/config.d
      ;;
      'sx1262_tcxo')
        cp /etc/meshtasticd/available.d/femtofox/femtofox_SX1262_TCXO.yaml /etc/meshtasticd/config.d
      ;;
      'sx1262_xtal')
        cp /etc/meshtasticd/available.d/femtofox/femtofox_SX1262_XTAL.yaml /etc/meshtasticd/config.d
      ;;
      'lr1121_tcxo')
        #not yet implemented
        cp /etc/meshtasticd/available.d/femtofox/femtofox_LR1121_TCXO.yaml /etc/meshtasticd/config.d
      ;;
      'none')
      ;;
      *)
        log_message "Invalid LoRa radio name: $meshtastic_lora_radio, ignoring."
        found_config="false"
      ;;
    esac
    if [ "$found_config" = "true" ]; then
      systemctl restart meshtasticd
      log_message "Set LoRa radio to $meshtastic_lora_radio, restarting Meshtasticd."
    fi
  fi
  
  if [[ -n "$timezone" ]]; then
    #sed -i "/timezone=/s/\".*\"/\"$timezone\"/" "$wpa_supplicant_conf"
    timezone=$(echo "$timezone" | sed 's/\\//g')
    log_message "Updating system timezone to $timezone."
    rm /etc/localtime
    ln -sf /usr/share/zoneinfo/$timezone /etc/localtime >> /tmp/femtofox-config.log 2>&1
    found_config="true"
  fi
  
  if [[ -n "$meshtastic_url" ]]; then
    meshtastic_url=$(echo "$meshtastic_url" | sed 's/\\//g')
    log_message "Updating Meshtastic URL."
    found_config="true"
    update_meshtastic_url="--seturl $meshtastic_url"
  fi
  
  if [[ -n "$meshtastic_admin_key" ]]; then
    meshtastic_admin_key=$(echo "$meshtastic_admin_key" | sed 's/\\//g')
    if [ "$meshtastic_admin_key" = "clear" ]; then
      log_message "Clearing Meshtastic admin key list."
      meshtastic_admin_key="0"
    else
      meshtastic_admin_key="base64:$meshtastic_admin_key"
      log_message "Updating Meshtastic admin key."
    fi
    found_config="true"
    update_meshtastic_security+=" --set security.admin_key $meshtastic_admin_key"
  fi
  
  if [[ -n "$meshtastic_legacy_admin" ]]; then
    meshtastic_legacy_admin=$(echo "$meshtastic_legacy_admin" | sed 's/\\//g')
    log_message "Updating Meshtastic legacy admin."
    found_config="true"
    update_meshtastic_security+=" --set security.admin_channel_enabled $meshtastic_legacy_admin"
  fi
  
  if [ "$found_config" = true ]; then #if we found a config file containing valid data
    
    if [ "$update_wifi" = true ]; then #if wifi config found, restart wifi
      systemctl restart wpa_supplicant 2>&1 | tee -a /tmp/femtofox-config.log
      wpa_cli -i wlan0 reconfigure 2>&1 | tee -a /tmp/femtofox-config.log
      log_message "wpa_supplicant.conf updated and wifi restarted. Enabling Meshtastic wifi setting."
      timeout 30s dhclient -v 2>&1 | tee -a /tmp/femtofox-config.log
      
      /usr/local/bin/updatemeshtastic.sh "--set network.wifi_enabled true" 10 "USB config" #| tee -a /tmp/femtofox-config.log
      if [ $? -eq 1 ]; then
        log_message "Update of Meshtastic FAILED."
      else
        log_message "Updated Meshtastic successfully."
      fi
    fi
    
    if [ "$update_meshtastic_url" != "" ]; then
      log_message "Connecting to Meshtastic radio and submitting $update_meshtastic_url"
      /usr/local/bin/updatemeshtastic.sh "$update_meshtastic_url" 10 "USB config" #| tee -a /tmp/femtofox-config.log
      if [ $? -eq 1 ]; then
        log_message "Update of Meshtastic FAILED."
      else
        log_message "Updated Meshtastic successfully."
      fi
    fi
    
    if [ "$update_meshtastic_security" != "" ]; then
      log_message "Connecting to Meshtastic radio and submitting $update_meshtastic_security"
      /usr/local/bin/updatemeshtastic.sh "$update_meshtastic_security" 10 "USB config" #| tee -a /tmp/femtofox-config.log
      if [ $? -eq 1 ]; then
        log_message "Update of Meshtastic FAILED."
      else
        log_message "Updated Meshtastic successfully."
      fi
    fi
    
		log_message "USB config complete, unplug USB drive."
    for _ in {1..10}; do #do our successful config boot code
      blink "0.125" && sleep 0.125
    done
  else #if no valid data in config file
    log_message "femtofox-config.txt does not contain valid configuration info, ignoring."
    for _ in {1..5}; do #boot code
      blink "1.5" && sleep 0.5
    done
    exit_script 1
  fi
  
else
  log_message "USB drive mounted but femtofox-config.txt not found, ignoring."
  for _ in {1..3}; do #boot code
    blink "1.5" && sleep 0.5
  done
  exit_script 1
fi

rm $usb_config #remove temporary copy of femtofox-config.txt
exit_script 0
