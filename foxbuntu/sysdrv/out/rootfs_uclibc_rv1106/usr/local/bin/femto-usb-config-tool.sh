#!/bin/bash
mount_point="/mnt/usb" # Set the mount point

# Function to log to screen, syslog and logfile to be saved to usb drive
log_message() {
  echo "USB config: $1"
  logger "USB config: $1"
  echo "$(date +"%Y-%m-%d %H:%M:%S") $1" >> /tmp/femtofox-config.log
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

  # Check if the mounted USB drive contains a file femtofox-config.log
if [ -f "$mount_point/femtofox-config.log" ]; then
  log_message "femtofox-config.log found on USB drive."
  log_exists=true
else
  log_exists=false
fi  

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
  wifi_command="femto-network-config.sh"
  meshtastic_security_command="femto-meshtasticd-config.sh"
  dont_run_if_log_exists=""
    
  # Escape and read the fields from the USB config file if they exist
  while IFS='=' read -r key value; do
    # Skip lines starting with #
    if [[ "$key" =~ ^# ]]; then
      continue
    fi
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
      dont_run_if_log_exists) dont_run_if_log_exists=$(escape_sed "$value") ;;
    esac
  done < <(grep -E '^(wifi_ssid|wifi_psk|wifi_country|meshtastic_lora_radio|timezone|meshtastic_url|meshtastic_legacy_admin|meshtastic_admin_key|dont_run_if_log_exists)=' "$usb_config")
  
  # Check if the log exits and if the dont_run_if_log_exists line is set in the script
  if $log_exists && [[ $dont_run_if_log_exists = "true" ]]; then
	log_message "\`dont_run_if_log_exists\` is set to \"true\" and log exists, ignoring."
    for _ in {1..2}; do #boot code
      blink "1.5" && sleep 0.5
    done
    exit_script 1
  fi
  
  # Update wpa_supplicant.conf with the new values, if specified
  if [[ -n "$wifi_country" ]]; then
    # Update country field
    wifi_command="$wifi_command -c \"$wifi_country\""
    log_message "Updating Wi-Fi country in wpa_supplicant.conf to $wifi_country."
    found_config="true"
    update_wifi="true"
  fi
  
  if [[ -n "$wifi_ssid" ]]; then
    # Update the ssid in the network block
    wifi_command="$wifi_command -s \"$wifi_ssid\""
    log_message "Updating Wi-Fi SSID in wpa_supplicant.conf to \`$wifi_ssid\`."
    found_config="true"
    update_wifi="true"
  fi
  
  if [[ -n "$wifi_psk" ]]; then
    # Update the psk in the network block
    wifi_command="$wifi_command -p \"$wifi_psk\""
    log_message "Updating Wi-Fi PSK in wpa_supplicant.conf to \`$wifi_psk\`."
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
        radio="sx1262_tcxo"
      ;;
      'ebyte-e22-900m22s')
        radio="sx1262_tcxo"
      ;;
      'heltec-ht-ra62')
        radio="sx1262_tcxo"
      ;;
      'seeed-wio-sx1262')
        radio="sx1262_tcxo"
      ;;
      'waveshare-sx126x-xxxm')
        radio="sx1262_xtal"
      ;;
      'ai-thinker-ra-01sh')
        radio="sx1262_xtal"
      ;;
      'ebyte-e80-900m22s')
        radio="lr1121_tcxo" # not yet implemented
      ;;
      'sx1262_tcxo')
        radio="sx1262_tcxo"
      ;;
      'sx1262_xtal')
        radio="sx1262_xtal"
      ;;
      'lr1121_tcxo')
        radio="lr1121_tcxo" # not yet implemented
      ;;
      'none')
        radio="none"
      ;;
      *)
        log_message "Invalid LoRa radio name: $meshtastic_lora_radio, ignoring."
      ;;
    esac
    if [[ -n "$radio" ]]; then # if a radio was found
      femto-meshtasticd-config.sh -l "$radio" -s 2>&1 | tee -a /tmp/femtofox-config.log # set the radio and restart the service
      log_message "Set LoRa radio to $meshtastic_lora_radio, restarting Meshtasticd."
    fi
  fi
  
  if [[ -n "$timezone" ]]; then # set timezone
    timezone=$(echo "$timezone" | sed 's/\\//g')
    log_message "Updating system timezone to $timezone."
    femto-set-timezone.sh -t "$timezone"
    found_config="true"
  fi
  
  if [[ -n "$meshtastic_url" ]]; then # set meshtastic URL
    meshtastic_url=$(echo "$meshtastic_url" | sed 's/\\//g') # remove weirdo windows characters
    log_message "Updating Meshtastic URL."
    found_config="true"
  fi
  
  if [[ -n "$meshtastic_admin_key" ]]; then
    meshtastic_admin_key=$(echo "$meshtastic_admin_key" | sed 's/\\//g') # remove weirdo windows characters
    if [ "$meshtastic_admin_key" = "clear" ]; then
      log_message "Clearing Meshtastic admin key list."
      meshtastic_admin_key="0"
    else
      meshtastic_admin_key="$meshtastic_admin_key"
      log_message "Updating Meshtastic admin key."
    fi
    found_config="true"
    meshtastic_security_command+=" -a \"$meshtastic_admin_key\"" # add to the command list
  fi
  
  if [[ -n "$meshtastic_legacy_admin" ]]; then
    meshtastic_legacy_admin=$(echo "$meshtastic_legacy_admin" | sed 's/\\//g') # remove weirdo windows characters
    log_message "Updating Meshtastic legacy admin."
    found_config="true"
    meshtastic_security_command+=" -o \"$meshtastic_legacy_admin\"" # add to the command list
  fi
  
  if [ "$found_config" = true ]; then #if we found a config file containing valid data
    
    if [ "$update_wifi" = true ]; then #if wifi config found, restart wifi
      log_message "Making changes to wifi settings and restarting wifi."
      wifi_command="$wifi_command -r"
      eval $wifi_command 2>&1 | tee -a /tmp/femtofox-config.log
      log_message "wpa_supplicant.conf updated and wifi restarted. Enabling Meshtastic wifi setting."
    fi
    
    if [ "$meshtastic_url" != "" ]; then
      log_message "Connecting to Meshtastic radio and submitting $meshtastic_url"
      femto-meshtasticd-config.sh -q "$meshtastic_url" 2>&1 | tee -a /tmp/femtofox-config.log
    fi
    
    if [ "$meshtastic_security_command" != "femto-meshtasticd-config.sh" ]; then
      log_message "Connecting to Meshtastic radio and submitting $meshtastic_security_command"
      eval "$meshtastic_security_command" 2>&1 | tee -a /tmp/femtofox-config.log
    fi
    
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
