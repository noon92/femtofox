#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Try \`sudo femto-meshtasticd-config\`."
   exit 1
fi

export NCURSES_NO_UTF8_ACS=1
export TERM=xterm-256color
export LANG=C.UTF-8

loading() {
  dialog --no-collapse --infobox "$1" 5 45
}

send_settings() {
  if [ -n "$command" ]; then
    set -o pipefail
    echo "meshtastic --host $command"
    output=$(eval "femto-meshtasticd-config.sh -m '$command' 5 'Save Meshtastic settings'" | tee /dev/tty)
    exit_status=$?
    set +o pipefail
    if [ $exit_status -eq 1 ]; then
      dialog --no-collapse --colors --title "$title" --msgbox "$(echo -e "\Z1Command FAILED!\Zn\n\nLog:\n$output")" 0 0
    elif [ $exit_status -eq 0 ]; then
      dialog --no-collapse --colors --title "$title" --msgbox "$(echo -e "\Z4Command Successful!\Zn\n\nLog:\n$output")" 0 0
    fi
  fi

  [ "$1" = "wizard" ] && dialog --no-collapse --title "$title" --colors --msgbox "Meshtastic $2 Settings Wizard complete!" 6 50 # if in wizard mode AND there are no script arguments, display the message
}

# ingest meshtastic config
get_current_meshtastic_config() {
  dialog --no-collapse --infobox "Getting current settings from Meshtasticd.\n\nThis can take a minute..." 6 50
  while IFS=':' read -r key value; do
    eval "${key}=\"${value}\"" # Create a variable with the key name and assign it the value
  done < <(femto-meshtasticd-config.sh -C all)
}

config_url() {
  femto-config -c &&  (
    newurl=$(dialog --no-collapse --colors --title "Meshtastic URL" --inputbox "The Meshtastic configuration URL allows for automatic configuration of all Meshtastic LoRa settings and channels.\nEntering a URL may \Z1\ZuOVERWRITE\Zn your LoRa settings and channels!\n\nNew Meshtastic LoRa configuration URL (SHIFT+INS to paste):" 13 63 3>&1 1>&2 2>&3)
    if [ -n "$newurl" ]; then #if a URL was entered
      command+="--seturl $newurl "
    fi
    # if we're in wizard mode AND there are no script arguments, then display a message
    send_settings $1
  )
}

security_menu() {
  title="Meshtastic User Settings"

  security_menu_choice=""   # zero the choice before loading the submenu
  while true; do
    security_menu_choice=$(dialog --no-collapse --cancel-label "Back" --default-item "$security_menu_choice" --title "Meshtastic Security Settings" --item-help --menu "" 17 40 5 \
      1 "View/change private key" "" \
      2 "View/change public key" "" \
      3 "View/add remote admin key" "" \
      4 "Clear admin keys" "" \
      5 "Legacy admin channel" "" \
      6 "Managed mode" "" \
      7 "Serial console" "" \
      8 "Debug log API" "" \
      " " "" "" \
      9 "Back to previous menu" "" 3>&1 1>&2 2>&3)
    [ $? -eq 1 ] && break # Exit the loop if the user selects "Cancel" or closes the dialog
    if femto-config -c; then
      case $security_menu_choice in
        1) # view/change private key)
          dialog --no-collapse --colors --title "Meshtastic private key" --yesno "The private key of the device, used to create a shared key with a remote device for secure communication.\n\n\Z1This key should be kept confidential.\nSetting an invalid key will lead to unexpected behaviors.\Zn\n\nCurrent private key:\n${security_privateKey:-unknown}\n\nSet new key?" 15 63
          if [ $? -eq 0 ]; then #unless cancel/no
            key=$(dialog --no-collapse --colors --title "$title" --cancel-label "Cancel" --inputbox "Private key  (default: random)" 8 60 "${security_privateKey:-unknown}" 3>&1 1>&2 2>&3)
            if [ $? -eq 0 ]; then #unless cancel/no
              loading "Sending command..."
              dialog --no-collapse --colors --title "Meshtastic private key" --msgbox "$(femto-meshtasticd-config.sh -R "$key" && echo -e "\n\Z4Command successful!\Zn\n" || echo -e "\n\Z1Command failed.\Zn\n")" 0 0
            fi
          fi
        ;;
        2) # view/change public key)
          dialog --no-collapse --colors --title "Meshtastic public key" --yesno "The public key of the device, shared with other nodes on the mesh to allow them to compute a shared secret key for secure communication. Generated automatically to match private key.\n\n\Z1Don't change this if you don't know what you're doing.\Zn\n\nCurrent public key:\n${security_publicKey:-unknown}\n\nSet new key?" 16 60
          if [ $? -eq 0 ]; then #unless cancel/no
            input=$(dialog --no-collapse --colors --title "$title" --cancel-label "Cancel" --inputbox "Public key  (default: generated from private key)" 8 60 "${security_publicKey:-unknown}" 3>&1 1>&2 2>&3)
            if [ $? -eq 0 ]; then #unless cancel/no
              loading "Sending command..."
              dialog --no-collapse --colors --title "Meshtastic public key" --msgbox "$(femto-meshtasticd-config.sh -U "$key" && echo -e "\n\Z4Command successful!\Zn\n" || echo -e "\n\Z1Command failed.\Zn\n")" 0 0
            fi
          fi
        ;;
        3) # view/add admin keys)
          loading "Getting Admin Keys..."
          admin_keys="$(femto-meshtasticd-config.sh -a | tail -n 1 | sed 's/|n/\\n/g')"
          key=$(dialog --no-collapse --title "Admin Keys" --inputbox "Current remote admin keys:\n$admin_keys\n\nUp to 3 are permitted, more will be ignored. List can be cleared with \"Clear remote admin keys\".\n\nRemote admin key (SHIFT+INS to paste)  (default: none):" 0 0 3>&1 1>&2 2>&3)
          if [ -n "$key" ] && [[ " $admin_keys " != *" $key "* ]]; then #if a key was entered
            loading "Sending command..."
            dialog --no-collapse --colors --title "$title" --msgbox "$(femto-meshtasticd-config.sh -A "$key" && echo -e "\n\Z4Command successful!\Zn\n" || echo -e "\n\Z1Command failed.\Zn\n")" 0 0
          fi
        ;;
        4) # clear admin keys)
          dialog --no-collapse --colors --title "$title" --yesno "A Meshtastic node can have up to 3 admin keys. If more are added, they will be ignored.\n\n\Z1This will DISABLE remote administration until a new key is added\Zn unless using legacy admin.\n\nClear admin key list?\n" 12 69
          if [ $? -eq 0 ]; then #unless cancel/no
            loading "Sending command..."
            dialog --no-collapse --colors --title "$title" --msgbox "$(femto-meshtasticd-config.sh -c && echo -e "\n\Z4Command successful!\Zn\n" || echo -e "\n\Z1Command failed.\Zn\n")" 0 0
          fi
        ;;
        5) # legacy admin)
          choice=""   # zero the choice before loading the submenu
          while true; do
            choice=$(dialog --no-collapse --title "$title" --cancel-label "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" --default-item "$(echo "${security_adminChannelEnabled:-False}" | sed 's/^./\U&/')" --item-help --menu "If the node you Femtofox needs to administer or be administered by is running 2.4.x or earlier, you should set this to Enabled. Requires a secondary channel named \"admin\" be present on both nodes.\n\nEnable legacy admin channel?  (current: ${security_adminChannelEnabled:-unknown})" 0 0 0 \
              "True" "" "" \
              "False" "(default)" "" \
              " " "" "" \
              "Cancel" "" "" 3>&1 1>&2 2>&3)
            [ $? -eq 1 ] || [ "$choice" == "Cancel" ] && break # Exit the loop if the user selects "Cancel" or closes the dialog
            [ "$choice" == " " ] && continue #restart loop if no choice made
            if [[ "$security_adminChannelEnabled" != "$choice " ]]; then
              security_adminChannelEnabled="$choice"
              command="--set security.admin_channel_enabled $(echo "$choice" | tr '[:upper:]' '[:lower:]') "
            fi
            send_settings not_wizard Security
            break
          done
        ;;
        6) # Managed mode)
          choice=""   # zero the choice before loading the submenu
          while true; do
            choice=$(dialog --no-collapse --colors --title "$title" --cancel-label "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" --default-item "$(echo "${security_isManaged:-False}" | sed 's/^./\U&/')" --item-help --menu "Enabling Managed Mode blocks client applications from writing configurations to a radio(they may be read). Once enabled, radio configurations can only be changed via remote ode administration, this menu or CLI. \Z4This setting is not required for remote node administration.\Zn\n\n\Before enabling Managed Mode, verify that the node can be controlled via Remote Admin or legacy Admin channel, and that all functions are working properly to \Z1prevent being locked out.\Zn\n\nEnable managed mode?  (current: ${security_isManaged:-unknown})" 0 0 0 \
              "True" "" "" \
              "False" "(default)" "" \
              " " "" "" \
              "Cancel" "" "" 3>&1 1>&2 2>&3)
            [ $? -eq 1 ] || [ "$choice" == "Cancel" ] && break # Exit the loop if the user selects "Cancel" or closes the dialog
            [ "$choice" == " " ] && continue #restart loop if no choice made
            if [[ "$security_isManaged" != "$choice " ]]; then
              security_isManaged="$choice"
              command="--set security.is_managed $(echo "$choice" | tr '[:upper:]' '[:lower:]') "
            fi
            send_settings not_wizard Security
            break
          done
       ;;
        7) # Serial console)
          choice=""   # zero the choice before loading the submenu
          while true; do
            choice=$(dialog --no-collapse --title "$title" --cancel-label "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" --default-item "$(echo "${security_serialEnabled:-True}" | sed 's/^./\U&/')" --item-help --menu "Enable serial console?  (current: ${security_serialEnabled:-unknown})" 8 46 0 \
              "True" "(default)" "" \
              "False" "" "" \
              " " "" "" \
              "Cancel" "" "" 3>&1 1>&2 2>&3)
            [ $? -eq 1 ] || [ "$choice" == "Cancel" ] && break # Exit the loop if the user selects "Cancel" or closes the dialog
            [ "$choice" == " " ] && continue #restart loop if no choice made
            if [[ "$security_serialEnabled" != "$choice " ]]; then
              security_serialEnabled="$choice"
              command="--set security.serial_enabled $(echo "$choice" | tr '[:upper:]' '[:lower:]') "
            fi
            send_settings not_wizard Security
            break
          done
        ;;
        8) # Managed mode)
          choice=""   # zero the choice before loading the submenu
          while true; do
            choice=$(dialog --no-collapse --title "$title" --cancel-label "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" --default-item "$(echo "${security_debugLogApiEnabled:-False}" | sed 's/^./\U&/')" --item-help --menu "Set this to true to continue outputting live debug logs over serial or Bluetooth when the API is active.\n\nEnable debug log?  (current: ${security_debugLogApiEnabled:-unknown})" 0 0 0 \
              "True" "" "" \
              "False" "(default)" "" \
              " " "" "" \
              "Cancel" "" "" 3>&1 1>&2 2>&3)
            [ $? -eq 1 ] || [ "$choice" == "Cancel" ] && break # Exit the loop if the user selects "Cancel" or closes the dialog
            [ "$choice" == " " ] && continue #restart loop if no choice made
            security_debugLogApiEnabled="$choice"
            command="--set security.debug_log_api_enabled $(echo "$choice" | tr '[:upper:]' '[:lower:]') "
            send_settings not_wizard Security
            break
          done
        ;;
        9) # return to previous menu)
          break
        ;;            
      esac
    fi
  done
}

lora_menu() {

  lora_settings() {
    title="Meshtastic LoRa Settings"
    command=""

    if [ "$1" = "set_lora_radio_model" ] || [ "$1" = "wizard" ]; then
      choice=""   # zero the choice before loading the submenu
      while true; do
        echo "Checking LoRa radio..."
        #Display filename, if exists: $(files=$(ls /etc/meshtasticd/config.d/* 2>/dev/null) && [ -n "$files" ] && echo "\n\nConfiguration files in use:\n$files" | paste -sd, -))
        choice=$(dialog --no-collapse --colors --cancel-label "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" --default-item "$choice" --title "Meshtastic LoRa radio" --item-help --menu "Currently configured LoRa radio:\n$(femto-utils.sh -R "$(femto-meshtasticd-config.sh -k)")$(ls -1 /etc/meshtasticd/config.d 2>/dev/null | grep -v '^femto_' | paste -sd ', ' - | sed 's/^/ (/; s/$/)/; s/,/, /g' | grep -v '^ ()$')" 22 50 10 \
          "Radio name:" "Configuration:" "" \
          "" "" "" \
          "Ebyte e22-900m30s" "(SX1262_TCXO)" "Included in Femtofox Pro" \
          "Ebyte e22-900m22s" "(SX1262_TCXO)" "" \
          "Ebyte e80-900m22s" "(SX1262_XTAL)" "" \
          "Heltec ht-ra62" "(SX1262_TCXO)" "" \
          "Seeed wio-sx1262" "(SX1262_TCXO)" "" \
          "Waveshare sx126x-xxxm" "(SX1262_XTAL)" "Not recommended due issues with sending longer messages" \
          "AI Thinker ra-01sh" "(SX1262_XTAL)" "" \
          "LoRa Meshstick 1262" "(meshstick-1262)" "USB based LoRa radio from Mark Birss. https://github.com/markbirss/MESHSTICK" \
          "Simulated radio" "(none)" "" \
          " " "" "" \
          "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" "" "" 3>&1 1>&2 2>&3)
        [ $? -eq 1 ] && break # Exit the loop if the user selects "Cancel" or closes the dialog
        local radio=""
        case $choice in
          "Ebyte e22-900m30s")
            radio="sx1262_tcxo"
          ;;
          "Ebyte e22-900m22s")
            radio="sx1262_tcxo"
          ;;
          "Ebyte e80-900m22s")
            radio="sx1262_xtal"
          ;;
          "Heltec ht-ra62")
            radio="sx1262_tcxo"
          ;;
          "Seeed wio-sx1262")
            radio="sx1262_tcxo"
          ;;
          "Waveshare sx126x-xxxm")
            radio="sx1262_xtal"
          ;;
          "AI Thinker ra-01sh")
            radio="femto_sx1262_xtal"
          ;;
          "LoRa Meshstick 1262")
            radio="lora-meshstick-1262"
          ;;
          "Simulated radio")
            radio="none"
          ;;
          "Skip")
            return
          ;;
        esac
        if [ -n "$radio" ]; then #if a radio was selected
          femto-meshtasticd-config.sh -l "$radio" -s # set the radio, then restart meshtasticd
          dialog --no-collapse --colors --title "$title" --msgbox "$(echo -e "Radio \Zu$choice\Zn selected.\nMeshtasticd service restarted.\Zn")" 7 45
          break
        fi
      done
      [ "$1" = "set_lora_radio_model" ] && return
    fi

    if femto-config -c; then

      if [ "$1" = "wizard" ]; then
        choice=""   # zero the choice before loading the submenu
        while true; do
          choice=$(dialog --no-collapse --title "$title" --cancel-label "Cancel" --default-item "True" --item-help --menu "Meshtastic configuration method" 8 50 0 \
            "Automatic configuration with URL" "" "" \
            "Manual configuration" "" "" \
            " " "" "" \
            "Cancel" "" "" 3>&1 1>&2 2>&3)
          [ $? -eq 1 ] || [ "$choice" == "Cancel" ] && return # Exit the loop if the user selects "Cancel" or closes the dialog
          [ "$choice" == " " ] && continue #restart loop if no choice made
          [ "$choice" == "Manual configuration" ] && break
          [ "$choice" == "Automatic configuration with URL" ] && config_url "$1"
          return
        done
      fi

      #get_current_meshtastic_config

      if [ "$1" = "region" ] || [ "$1" = "wizard" ]; then
        options=("UNSET" "US" "EU_433" "EU_868" "CN" "JP" "ANZ" "KR" "TW" "RU" "IN" "NZ_865" "TH" "LORA_24" "UA_433" "UA_868" "MY_433" "MY_919" "SG_923")
        menu_items=()
        # Create menu options from the array
        for i in "${!options[@]}"; do 
          if [ $i -eq 0 ]; then
            menu_items+=("${options[$i]}" "(default)" "")  # First item with "(default)"
          else
            menu_items+=("${options[$i]}" "" "")  # Other items without "(default)"
          fi
        done
        menu_items+=("" "" "" "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" "" "")
        while true; do
          choice=$(dialog --no-collapse --title "$title" --cancel-label "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" --default-item "$lora_region" --item-help --menu "Sets the region for your node. As long as this is not set, the node will display a message and not transmit any packets.\n\nRegion?  (current: ${lora_region})" 0 0 0 \
            "${menu_items[@]}" 3>&1 1>&2 2>&3)
          [ $? -eq 1 ] || [ "$choice" == "Cancel" ] || [ "$choice" == "Skip" ] && break # Exit the loop if the user selects "Cancel" or closes the dialog
          [ "$choice" == " " ] && continue # Restart loop if no choice made
          lora_region="$choice"
          command+="--set lora.region $choice "
          break
        done
      fi

      if [ "$1" = "use_modem_preset" ] || [ "$1" = "wizard" ]; then
        choice=""   # zero the choice before loading the submenu
        while true; do
          choice=$(dialog --no-collapse --title "$title" --cancel-label "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" --default-item "$(echo "${lora_usePreset:-False}" | sed 's/^./\U&/')" --item-help --menu "Presets are pre-defined modem settings (Bandwidth, Spread Factor, and Coding Rate) which influence both message speed and range. The vast majority of users use a preset.\n\nUse modem preset?  (current: ${lora_usePreset:-unknown})" 0 0 0 \
            "True" "(default)" "" \
            "False" "" "" \
            " " "" "" \
            "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" "" "" 3>&1 1>&2 2>&3)
          [ $? -eq 1 ] || [ "$choice" == "Cancel" ] || [ "$choice" == "Skip" ] && break # Exit the loop if the user selects "Cancel" or closes the dialog
          [ "$choice" == " " ] && continue #restart loop if no choice made
          using_preset="$choice"
          lora_usePreset="$choice"
          command+="--set lora.use_preset $(echo "$choice" | tr '[:upper:]' '[:lower:]') "
          break
        done
      fi

      if [ "$1" = "wizard" ] && [ "$using_preset" = "False" ]; then
        dialog --no-collapse --title "$title" --colors --msgbox "Not using preset, so skipping Preset setting." 6 50
      else
        if [ "$1" = "preset" ] || [ "$1" = "wizard" ]; then
          options=("LONG_FAST" "LONG_SLOW" "VERY_LONG_SLOW" "MEDIUM_SLOW" "MEDIUM_FAST" "SHORT_SLOW" "SHORT_FAST" "SHORT_TURBO")
          menu_items=()
          # Create menu options from the array
          for i in "${!options[@]}"; do 
            if [ $i -eq 0 ]; then
              menu_items+=("${options[$i]}" "(default)" "")  # First item with "(default)"
            else
              menu_items+=("${options[$i]}" "" "")  # Other items without "(default)"
            fi
          done
          menu_items+=("" "" "" "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" "" "")
          while true; do
            choice=$(dialog --no-collapse --title "$title" --cancel-label "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" --default-item "$lora_modemPreset" --item-help --menu "The default preset will provide a strong mixture of speed and range, for most users.\n\nPreset?  (current: ${lora_modemPreset:-unknown})" 0 0 0 \
              "${menu_items[@]}" 3>&1 1>&2 2>&3)
            [ $? -eq 1 ] || [ "$choice" == "Cancel" ] || [ "$choice" == "Skip" ] && break # Exit the loop if the user selects "Cancel" or closes the dialog
            [ "$choice" == " " ] && continue # Restart loop if no choice made
            lora_modemPreset="$choice"
            command+="--set lora.modem_preset $choice "
            break
          done
        fi
      fi
      
      if [ "$1" = "wizard" ] && [ "$using_preset" = "True" ]; then
        dialog --no-collapse --title "$title" --colors --msgbox "Using preset, so skipping Bandwidth, Spread Factor and Coding Rate settings." 7 50
      else
        if [ "$1" = "bandwidth" ] || [ "$1" = "wizard" ]; then
          while true; do
            choice=$(dialog --no-collapse --title "$title" --cancel-label "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" --item-help --default-item $lora_bandwidth --menu "Width of the frequency \"band\" used around the calculated center frequency. Only used if modem preset is disabled.\n\nBandwidth?  (current: ${lora_bandwidth:-unknown})" 0 0 0 \
              0 "(default, automatic)" "" \
              31 "" "" \
              62 "" "" \
              125 "" "" \
              250 "" "" \
              500 "" "" \
              " " "" "" \
              "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" "" "" 3>&1 1>&2 2>&3)
            [ $? -eq 1 ] || [ "$choice" == "Cancel" ] || [ "$choice" == "Skip" ] && break # Exit the loop if the user selects "Cancel" or closes the dialog
            [ "$choice" == " " ] && continue # Restart loop if no choice made
            lora_bandwidth="$choice"
            command+="--set lora.bandwidth $choice "
            break
          done
        fi

        if [ "$1" = "spread_factor" ] || [ "$1" = "wizard" ]; then
          while true; do
            choice=$(dialog --no-collapse --title "$title" --cancel-label "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" --item-help --default-item $lora_spreadFactor --menu "Indicates the number of chirps per symbol. Only used if modem preset is disabled.\n\nSpread factor?  (current: ${lora_spreadFactor:-unknown})" 0 0 0 \
              0 "(default, automatic)" "" \
              7 "" "" \
              8 "" "" \
              9 "" "" \
              10 "" "" \
              11 "" "" \
              12 "" "" \
              " " "" "" \
              "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" "" "" 3>&1 1>&2 2>&3)
            [ $? -eq 1 ] || [ "$choice" == "Cancel" ] || [ "$choice" == "Skip" ] && break # Exit the loop if the user selects "Cancel" or closes the dialog
            [ "$choice" == " " ] && continue # Restart loop if no choice made
            lora_spreadFactor="$choice"
            command+="--set lora.spread_factor $choice "
            break
          done
        fi

        if [ "$1" = "coding_rate" ] || [ "$1" = "wizard" ]; then
          while true; do
            choice=$(dialog --no-collapse --title "$title" --cancel-label "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" --item-help --default-item $lora_codingRate --menu "The proportion of each LoRa transmission that contains actual data - the rest is used for error correction.\n\nCoding rate (only used if modem preset is disabled)?  (current: ${lora_codingRate:-unknown})" 0 0 0 \
              0 "(default, automatic)" "" \
              5 "" "" \
              6 "" "" \
              7 "" "" \
              8 "" "" \
              " " "" "" \
              "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" "" "" 3>&1 1>&2 2>&3)
            [ $? -eq 1 ] || [ "$choice" == "Cancel" ] || [ "$choice" == "Skip" ] && break # Exit the loop if the user selects "Cancel" or closes the dialog
            [ "$choice" == " " ] && continue # Restart loop if no choice made
            lora_codingRate="$choice"
            command+="--set lora.coding_rate $choice "
            break
          done
        fi
      fi

      if [ "$1" = "frequency_offset" ] || [ "$1" = "wizard" ]; then
        while true; do
          input=$(dialog --no-collapse --title "$title" --cancel-label "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" --inputbox "This parameter is for advanced users with advanced test equipment.\n\nFrequency offset (default: 0)" 0 0 ${lora_frequencyOffset:-unknown} 3>&1 1>&2 2>&3)
          [[ -z $input || ($input =~ ^([0-9]{1,6})(\.[0-9]+)?$ && $(echo "$input <= 1000000" | bc -l) -eq 1) ]] && break # exit loop if user input a number between 0 and 1000000. Decimals allowed
          dialog --no-collapse --title "$title" --msgbox "Must be between 0-1000000. Decimals allowed." 6 50
        done
        if [ $? -ne 1 ] && [ -n "$input" ]; then
          lora_frequencyOffset="$input"
          command+="--set lora.frequency_offset $input "
        fi
      fi

      if [ "$1" = "hop_limit" ] || [ "$1" = "wizard" ]; then
        while true; do
          input=$(dialog --no-collapse --colors --title "$title" --cancel-label "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" --inputbox "The maximum number of intermediate nodes between Femtofox and a node it is sending to. Does not impact received messages.\n\n\Z1WARNING:\Zn Excessive hop limit increases congestion!\n\nHop limit. Must be 0-7 (default: 3)" 0 0 ${lora_hopLimit:-unknown} 3>&1 1>&2 2>&3)
          [[ -z $input || ($input =~ ^[0-7]$) ]] && break # exit loop if user input an integer between 0 and 7
          dialog --no-collapse --title "$title" --msgbox "Must be an integer between 0 and 7." 6 50
        done
        if [ $? -ne 1 ] && [ -n "$input" ]; then
          lora_hopLimit="$input"
          command+="--set lora.hop_limit $input "
        fi
      fi

      if [ "$1" = "tx_enabled" ] || [ "$1" = "wizard" ]; then
        choice=""   # zero the choice before loading the submenu
        while true; do
          choice=$(dialog --no-collapse --title "$title" --cancel-label "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" --default-item "$(echo "${lora_txEnabled:-False}" | sed 's/^./\U&/')" --item-help --menu "Enables/disables the radio chip. Useful for hot-swapping antennas.\n\nEnable TX?  (current: ${lora_txEnabled:-unknown})" 0 0 0 \
            "True" "(default)" "" \
            "False" "" "" \
            " " "" "" \
            "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" "" "" 3>&1 1>&2 2>&3)
          [ $? -eq 1 ] || [ "$choice" == "Cancel" ] || [ "$choice" == "Skip" ] && break # Exit the loop if the user selects "Cancel" or closes the dialog
          [ "$choice" == " " ] && continue #restart loop if no choice made
          lora_txEnabled="$choice"
          command+="--set lora.tx_enabled $(echo "$choice" | tr '[:upper:]' '[:lower:]') "
          break
        done
      fi

      if [ "$1" = "tx_power" ] || [ "$1" = "wizard" ]; then
        while true; do
          input=$(dialog --no-collapse --colors --title "$title" --cancel-label "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" --inputbox "\
\Z1\ZuWARNING!\Zn\n\
Setting a 33db radio above 8db will \Zupermanently\Zn damage it.\n\
ERP above 27db violates EU law.\n\
ERP above 36db violates US (unlicensed) law.\n\
\n\
If 0, will use the maximum continuous power legal in your region.
\n\
\n\
TX power in dBm. Must be 0-30 (0 for automatic)" 0 0 ${lora_txPower:-unknown} 3>&1 1>&2 2>&3)
          [[ -z $input || $input =~ ^([12]?[0-9]|30)$ ]] && break # exit loop if user input an integer between 0 and 30
          dialog --no-collapse --title "$title" --msgbox "Must be an integer between 0 and 30." 6 50
        done
        if [ $? -ne 1 ] && [ -n "$input" ]; then
          lora_txPower="$input"
          command+="--set lora.tx_power $input "
        fi
      fi

      if [ "$1" = "frequency_slot" ] || [ "$1" = "wizard" ]; then
        while true; do
          input=$(dialog --no-collapse --title "$title" --cancel-label "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" --inputbox "Determines the exact frequency the radio transmits and receives. If unset or set to 0, determined automatically by the primary channel name.\n\nFrequency slot (0 for automatic)" 0 0 ${lora_channelNum:-unknown} 3>&1 1>&2 2>&3)
          [[ -z $input || ($input =~ ^[0-9]+$) ]] && break # exit loop if user input an integer 0 or higher
          dialog --no-collapse --title "$title" --msgbox "Must be an integer 0 or higher." 6 50
        done
        if [ $? -ne 1 ] && [ -n "$input" ]; then
          lora_channelNum="$input"
          command+="--set lora.channel_num $input "
        fi
      fi

      if [ "$1" = "override_duty_cycle" ] || [ "$1" = "wizard" ]; then
        while true; do
          choice=$(dialog --no-collapse --title "$title" --cancel-label "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" --default-item "$(echo "${lora_overrideDutyCycle:-False}" | sed 's/^./\U&/')" --item-help --menu "May have legal ramifications.\n\nOverride duty cycle?  (current: ${lora_overrideDutyCycle:-unknown})" 0 0 0 \
            "True" "" "" \
            "False" "(default)" "" \
            " " "" "" \
            "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" "" "" 3>&1 1>&2 2>&3)
          [ $? -eq 1 ] || [ "$choice" == "Cancel" ] || [ "$choice" == "Skip" ] && break # Exit the loop if the user selects "Cancel" or closes the dialog
          [ "$choice" == " " ] && continue #restart loop if no choice made
          lora_overrideDutyCycle="$choice"
          command+="--set lora.override_duty_cycle $(echo "$choice" | tr '[:upper:]' '[:lower:]') "
          break
        done
      fi

      if [ "$1" = "sx126x_rx_boosted_gain" ] || [ "$1" = "wizard" ]; then
        while true; do
          choice=$(dialog --no-collapse --title "$title" --cancel-label "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" --default-item "$(echo "${lora_sx126xRxBoostedGain:-True}" | sed 's/^./\U&/')" --item-help --menu "This is an option specific to the SX126x chip series which allows the chip to consume a small amount of additional power to increase RX (receive) sensitivity.\n\nEnable SX126X RX boosted gain?  (current: ${lora_sx126xRxBoostedGain:-unknown})" 0 0 0 \
            "True" "(default)" "" \
            "False" "" "" \
            " " "" "" \
            "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" "" "" 3>&1 1>&2 2>&3)
          [ $? -eq 1 ] || [ "$choice" == "Cancel" ] || [ "$choice" == "Skip" ] && break # Exit the loop if the user selects "Cancel" or closes the dialog
          [ "$choice" == " " ] && continue #restart loop if no choice made
          lora_sx126xRxBoostedGain="$choice"
          command+="--set lora.sx126x_rx_boosted_gain $(echo "$choice" | tr '[:upper:]' '[:lower:]') "
          break
        done
      fi

      if [ "$1" = "override_frequency" ] || [ "$1" = "wizard" ]; then
        while true; do
          input=$(dialog --no-collapse --title "$title" --cancel-label "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" --inputbox "Overrides frequency slot. May have legal ramifications.\n\nOverride frequency in MHz (0 for none)." 0 0 ${lora_overrideFrequency:-unknown} 3>&1 1>&2 2>&3)
          [[ -z $input || ($input =~ ^[0-9]+(\.[0-9]+)?$) ]] && break # exit loop if user input a number 0 or higher (decimals allowed)
          dialog --no-collapse --title "$title" --msgbox "Must be a number 0 or higher. Decimals allowed." 6 53
        done
        if [ $? -ne 1 ] && [ -n "$input" ]; then
          lora_overrideFrequency="$input"
          command+="--set lora.override_frequency $input "
        fi
      fi

      if [ "$1" = "ignore_mqtt" ] || [ "$1" = "wizard" ]; then
        while true; do
          choice=$(dialog --no-collapse --title "$title" --cancel-label "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" --default-item "$(echo "${lora_ignoreMqtt:-unknown}" | sed 's/^./\U&/')" --item-help --menu "Ignores any messages it receives via LoRa that came via MQTT somewhere along the path towards the device.\n\nIgnore MQTT?  (current: ${lora_ignoreMqtt:-unknown})" 0 0 0 \
            "True" "" "" \
            "False" "(default)" "" \
            " " "" "" \
            "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" "" "" 3>&1 1>&2 2>&3)
          [ $? -eq 1 ] || [ "$choice" == "Cancel" ] || [ "$choice" == "Skip" ] && break # Exit the loop if the user selects "Cancel" or closes the dialog
          [ "$choice" == " " ] && continue #restart loop if no choice made
          lora_ignoreMqtt="$choice"
          command+="--set lora.ignore_mqtt $(echo "$choice" | tr '[:upper:]' '[:lower:]') "
          break
        done
      fi

      if [ "$1" = "ok_to_mqtt" ] || [ "$1" = "wizard" ]; then
        while true; do
          choice=$(dialog --no-collapse --title "$title" --cancel-label "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" --default-item "$(echo "${lora_configOkToMqtt:-unknown}" | sed 's/^./\U&/')" --item-help --menu "Indicates that the user approves their packets to be uplinked to MQTT brokers.\n\nOK to MQTT?  (current: ${lora_configOkToMqtt:-unknown})" 0 0 0 \
            "True" "" "" \
            "False" "(default)" "" \
            " " "" "" \
            "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" "" "" 3>&1 1>&2 2>&3)
          [ $? -eq 1 ] || [ "$choice" == "Cancel" ] || [ "$choice" == "Skip" ] && break # Exit the loop if the user selects "Cancel" or closes the dialog
          [ "$choice" == " " ] && continue #restart loop if no choice made
          lora_configOkToMqtt="$choice"
          command+="--set lora.config_ok_to_mqtt $(echo "$choice" | tr '[:upper:]' '[:lower:]') "
          break
        done
      fi

      [ -n "$command" ] && send_settings $1 LoRa
    fi
  }

  command="" # initialize command
  lora_menu_choice=""   # zero the choice before loading the submenu
  while true; do
    command="" # initialize command
    lora_menu_choice=$(dialog --no-collapse --title "Meshtastic LoRa Settings" --default-item "$lora_menu_choice" --cancel-label "Back" --item-help --menu "Select a LoRa setting or run the wizard" 30 50 20 \
      1 "Wizard (set all)" "" \
      2 "Set LoRa radio model" "" \
      3 "Configure automatically with URL" "" \
      4 "Region" "" \
      5 "Use modem preset" "" \
      6 "Preset" "" \
      7 "Bandwidth" "" \
      8 "Spread factor" "" \
      9 "Coding rate" "" \
      10 "Frequency offset" "" \
      11 "Hop limit" "" \
      12 "Enable/disable TX" "" \
      13 "TX power" "" \
      14 "Frequency slot" "" \
      15 "Override duty cycle" "" \
      16 "SX126X RX boosted gain " "" \
      17 "Override frequency" "" \
      18 "Ignore MQTT" "" \
      19 "OK to MQTT" "" \
      " " "" "" \
      20 "Back to Settings Menu" "" 3>&1 1>&2 2>&3)
    [ $? -eq 1 ] && break # Exit the loop if the user selects "Cancel" or closes the dialog
    case $lora_menu_choice in
      1) # Wizard (set all)
        lora_settings "wizard"
      ;;
      2) # Set LoRa radio model)
        lora_settings "set_lora_radio_model"
      ;;
      3) # Configure automatically with URL)
        config_url
      ;;
      4) # Region)
        lora_settings "region"
      ;;
      5) # Use modem preset)
        lora_settings "use_modem_preset"
      ;;
      6) # Preset)
        lora_settings "preset"
      ;;
      7) # Bandwidth)
        lora_settings "bandwidth"
      ;;
      8) # Spread factor)
        lora_settings "spread_factor"
      ;;
      9) # Coding rate)
        lora_settings "coding_rate"
      ;;
      10) # Frequency offset)
        lora_settings "frequency_offset"
      ;;
      11) # Hop limit)
        lora_settings "hop_limit"
      ;;
      12) # Enable/disable TX)
        lora_settings "tx_enabled"
      ;;
      13) # TX power)
        lora_settings "tx_power"
      ;;
      14) # Frequency slot)
        lora_settings "frequency_slot"
      ;;
      15) # Override duty cycle)
        lora_settings "override_duty_cycle"
      ;;
      16) # SX126X RX boosted gain)
        lora_settings "sx126x_rx_boosted_gain"
      ;;
      17) # Override frequency)
        lora_settings "override_frequency"
      ;;
      18) # Ignore MQTT)
        lora_settings "ignore_mqtt"
      ;;
      19) # OK to MQTT)
        lora_settings "ok_to_mqtt"
      ;;
      20) break ;;
    esac
  done
}

user_menu() {

  user_settings() {
    title="Meshtastic User Settings"
    command=""
    
    if femto-config -c; then
      if [ "$1" = "long_name" ] || [ "$1" = "wizard" ]; then
        input=$(dialog --no-collapse --colors --title "$title" --cancel-label "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" --inputbox "If you are a licensed HAM operator and have enabled HAM mode, this must be set to your HAM operator call sign.\n\nNode long name (default: Meshtastic ${nodeinfo_user_id: -4})" 0 0 "${nodeinfo_user_longName:-unknown}" 3>&1 1>&2 2>&3)
        if [ $? -ne 1 ] && [ -n "$input" ]; then
          nodeinfo_user_longName="$input"
          command+="--set-owner $input "
        fi
      fi

      if [ "$1" = "short_name" ] || [ "$1" = "wizard" ]; then
        while true; do
          input=$(dialog --no-collapse --colors --title "$title" --cancel-label "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" --inputbox "Must be up to 4 bytes. Usually this is the same as 4 characters, if not using non-latin characters and emoji.\n\nNode short name (default: ${nodeinfo_user_id: -4})" 0 0 "${nodeinfo_user_shortName:-unknown}" 3>&1 1>&2 2>&3)
          [ $? -eq 1 ] || [[ ${#input} -le 4 ]] && break # break if valid input
          dialog --no-collapse --title "$title" --msgbox "Must be up to 4 bytes.\n\nUsually this is 4 characters, if using latin characters and no emojis." 9 50
        done
        if [ $? -ne 1 ] && [ -n "$input" ]; then
          nodeinfo_user_shortName="$input"
          command+="--set-owner-short $input "
        fi
      fi

      if [ "$1" = "ham_mode" ] || [ "$1" = "wizard" ]; then
        choice=""   # zero the choice before loading the submenu
        while true; do
          choice=$(dialog --no-collapse --colors --title "$title" --help-button --cancel-label "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" --default-item "$(echo "${nodeinfo_user_isLicensed:-False}" | sed 's/^./\U&/')" --item-help --menu "\Z1IMPORTANT: Read Help text before enabling.\Zn\n\nEnable licensed amateur (HAM) mode?  (current: ${nodeinfo_user_isLicensed:-unknown})" 0 0 0 \
            "True" "" "" \
            "False" "(default)" "" \
            " " "" "" \
            "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" "" "" 3>&1 1>&2 2>&3)
            exit_status=$? # This line checks the exit status of the dialog command
            if [ $exit_status -eq 1 ] || [ "$choice" == "Cancel" ] || [ "$choice" == "Skip" ]; then # Exit the loop if the user selects "Cancel" or closes the dialog
              break
            elif [ $exit_status -eq 2 ]; then # Help button
              dialog --no-collapse --colors --title "HAM mode help" --msgbox "\
HAM radio mode has both privileges and restrictions:\n\
* Higher transmit power (up to 10W in the US)\n\
* Higher Gain Antennas.\n\
* No encryption\n\
* Automatically transmits your callsign every 10 minutes\n\
\n\
When using HAM mode, you must set your node's Long Name to your HAM callsign and remove encryption from all your channels. Not doing so may violate the law." 0 0
            else
              [ "$choice" == " " ] && continue #restart loop if no choice made
              nodeinfo_user_isLicensed="${choice,,}"
              command+="--set --set-ham $nodeinfo_user_longName"
              break
            fi
        done
      fi
      
      [ -n "$command" ] && send_settings $1 User
    fi
  }

  command="" # initialize command
  user_menu_choice=""   # zero the choice before loading the submenu
  while true; do
    command="" # initialize command
    user_menu_choice=$(dialog --no-collapse --title "Meshtastic User Settings" --default-item "$user_menu_choice" --cancel-label "Back" --item-help --menu "Select a User setting or run the wizard" 14 50 20 \
      1 "Wizard (set all)" "" \
      2 "Long name" "" \
      3 "Short name" "" \
      4 "Licensed amateur radio (ham) mode" "" \
      " " "" "" \
      5 "Back to Settings Menu" "" 3>&1 1>&2 2>&3)
    [ $? -eq 1 ] && break # Exit the loop if the user selects "Cancel" or closes the dialog
    case $user_menu_choice in
      1) # Wizard (set all)
        user_settings "wizard"
      ;;
      2) # Long name)
        user_settings "long_name"
      ;;
      3) # Short name)
        user_settings "short_name"
      ;;
      4) # Enable/disable licensed amateur radio (ham) mode)
        user_settings "ham_mode"
      ;;
      5) break ;;
    esac
  done
}

device_menu() {

  device_settings() {
    title="Meshtastic Device Settings"
    command=""

    if femto-config -c; then

      if [ "$1" = "role" ] || [ "$1" = "wizard" ]; then
        options=("CLIENT" "CLIENT_MUTE" "CLIENT_HIDDEN" "TRACKER" "LOST_AND_FOUND" "SENSOR" "TAK" "TAK_TRACKER" "ROUTER" "ROUTER_LATE" "REPEATER")
        menu_items=()
        # Create menu options from the array
        for i in "${!options[@]}"; do 
          if [ $i -eq 0 ]; then
            menu_items+=("${options[$i]}" "(default)" "")  # First item with "(default)"
          else
            menu_items+=("${options[$i]}" "" "")  # Other items without "(default)"
          fi
        done
        menu_items+=("" "" "" "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" "" "")
        while true; do
          choice=$(dialog --no-collapse --title "$title" --cancel-label "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" --default-item "${device_role:-CLIENT}" --item-help --menu "For the vast majority of users, the correct choice is CLIENT. For more information, visit https://meshtastic.org/blog/choosing-the-right-device-role/\n\nDevice role  (current: ${device_role:-unknown})" 0 0 0 \
            "${menu_items[@]}" 3>&1 1>&2 2>&3)
          [ $? -eq 1 ] || [ "$choice" == "Cancel" ] || [ "$choice" == "Skip" ] && break # Exit the loop if the user selects "Cancel" or closes the dialog
          [ "$choice" == " " ] && continue # Restart loop if no choice made
          device_role="$choice"
          command+="--set device.role $choice "
          break
        done
      fi

      if [ "$1" = "button_gpio" ] || [ "$1" = "wizard" ]; then
        while true; do
          input=$(dialog --no-collapse --colors --title "$title" --cancel-label "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" --inputbox "GPIO pin for user button  (0 for automatic)" 0 0 "${device_buttonGpio:-unknown}" 3>&1 1>&2 2>&3)
          [ $? -eq 1 ] || [[ "$input" =~ ^[0-9]+$ ]] && (( input >= 0 && input <= 34 )) && break # break if valid input
          dialog --no-collapse --title "$title" --msgbox "Must be an integer between 0 and 34." 6 50
        done
        if [ $? -ne 1 ] && [ -n "$input" ]; then
          device_buttonGpio="$input"
          command+="--set device.button_gpio $input "
        fi
      fi
      
      if [ "$1" = "buzzer_gpio" ] || [ "$1" = "wizard" ]; then
        while true; do
          input=$(dialog --no-collapse --colors --title "$title" --cancel-label "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" --inputbox "GPIO pin for user buzzer  (0 for automatic)" 0 0 "${device_buzzerGpio:-unknown}" 3>&1 1>&2 2>&3)
          [ $? -eq 1 ] || [[ "$input" =~ ^[0-9]+$ ]] && (( input >= 0 && input <= 34 )) && break # break if valid input
          dialog --no-collapse --title "$title" --msgbox "Must be an integer between 0 and 34." 6 50
        done
        if [ $? -ne 1 ] && [ -n "$input" ]; then
          device_buzzerGpio="$input"
          command+="--set device.buzzer_gpio $input "
        fi
      fi

      if [ "$1" = "rebroadcast_mode" ] || [ "$1" = "wizard" ]; then
        while true; do
          choice=$(dialog --no-collapse --title "$title" --cancel-label "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" --default-item "${device_rebroadcastMode:-ALL}" --item-help --menu "This setting defines the device's behavior for how messages are rebroadcasted.\n\nRebroadcast mode?  (current: ${device_rebroadcastMode:-unknown})" 0 0 0 \
            "ALL" "(default)" "Will rebroadcast ALL messages, regardless of whether it can decrypt them" \
            "ALL_SKIP_DECODING" "" "Same as ALL, but skips decryption (only works with REPEATER role)" \
            "LOCAL_ONLY" "" "Only rebroadcasts messages from nodes with shared channels" \
            "KNOWN_ONLY" "" "Like LOCAL_ONLY but also ignores nodes not in nodeDB" \
            "NONE" "" "Does not rebroadcast. Only for SENSOR, TRACKER and TAK_TRACKER roles" \
            "CORE_PORTNUMS_ONLY" "" "Ignores packets using non-standard portnums (such as range tests)" \
            " " "" "" \
            "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" "" "" 3>&1 1>&2 2>&3)
          [ $? -eq 1 ] || [ "$choice" == "Cancel" ] || [ "$choice" == "Skip" ] && break # Exit the loop if the user selects "Cancel" or closes the dialog
          [ "$choice" == " " ] && continue # Restart loop if no choice made
          device_rebroadcastMode="$choice"
          command+="--set device.rebroadcast_mode $choice "
          break
        done
      fi

      if [ "$1" = "Nodeinfo_broadcast_interval" ] || [ "$1" = "wizard" ]; then
        while true; do
          input=$(dialog --no-collapse --colors --title "$title" --cancel-label "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" --inputbox "This is the number of seconds between NodeInfo message broadcasts. Femtofox will still send nodeinfo in response to new nodes on the mesh.\n\nNodeinfo broadcast interval in seconds  (default: 10800, 0 for automatic)" 0 0 "${device_nodeInfoBroadcastSecs:-unknown}" 3>&1 1>&2 2>&3)
          [ $? -eq 1 ] || [[ "$input" =~ ^[0-9]+$ ]] && (( input >= 0 && input <= 4294967295 )) && break # break if valid input
          dialog --no-collapse --title "$title" --msgbox "Must be an integer between 0 and 4294967295." 6 50
        done
        if [ $? -ne 1 ] && [ -n "$input" ]; then
          device_nodeInfoBroadcastSecs="$input"
          command+="--set device.node_info_broadcast_secs $input "
        fi
      fi

      if [ "$1" = "double_tap_as_button" ] || [ "$1" = "wizard" ]; then
        while true; do
          choice=$(dialog --no-collapse --title "$title" --cancel-label "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" --default-item "$(echo "${device_doubleTapAsButtonPress:-false}" | sed 's/^./\U&/')" --item-help --menu "This option will enable a double tap, when a supported accelerometer is attached to the device, to be treated as a button press.\n\nDouble Tap as Button Press?  (current: ${device_doubleTapAsButtonPress:-unknown})" 0 0 0 \
            "True" "" "" \
            "False" "(default)" "" \
            " " "" "" \
            "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" "" "" 3>&1 1>&2 2>&3)
          [ $? -eq 1 ] || [ "$choice" == "Cancel" ] || [ "$choice" == "Skip" ] && break # Exit the loop if the user selects "Cancel" or closes the dialog
          [ "$choice" == " " ] && continue #restart loop if no choice made
          device_doubleTapAsButtonPress="$choice"
          command+="--set device.double_tap_as_button_press $(echo "$choice" | tr '[:upper:]' '[:lower:]') "
          break
        done
      fi

      if [ "$1" = "disable_triple_click" ] || [ "$1" = "wizard" ]; then
        while true; do
          choice=$(dialog --no-collapse --colors --title "$title" --cancel-label "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" --default-item "$(echo "${device_disableTripleClick:-true}" | sed 's/^./\U&/')" --item-help --menu "\ZuNote: this setting does not apply to the button on the Luckfox Pico Mini.\Zn\n\nDisable the triple click action on button?  (current: ${device_disableTripleClick:-unknown})" 0 0 0 \
            "True" "(default)" "" \
            "False" "" "" \
            " " "" "" \
            "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" "" "" 3>&1 1>&2 2>&3)
          [ $? -eq 1 ] || [ "$choice" == "Cancel" ] || [ "$choice" == "Skip" ] && break # Exit the loop if the user selects "Cancel" or closes the dialog
          [ "$choice" == " " ] && continue #restart loop if no choice made
          device_disableTripleClick="$choice"
          command+="--set device.disable_triple_click $(echo "$choice" | tr '[:upper:]' '[:lower:]') "
          break
        done
      fi

      if [ "$1" = "posix_timezone" ] || [ "$1" = "wizard" ]; then
        input=$(dialog --no-collapse --colors --title "$title" --cancel-label "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" --inputbox "Uses the TZ Database format to display the correct local time on the device display and in its logs.\n\nPOSIX TZDEF Timezone Definition (default: blank)" 0 0 "$device_tzdef" 3>&1 1>&2 2>&3)
        if [ $? -ne 1 ] && [ -n "$input" ]; then
          device_tzdef="$input"
          command+="--set device.tzdef $input "
        fi
      fi

      [ -n "$command" ] && send_settings $1 Device
    fi
  }

  command="" # initialize command
  device_menu_choice=""   # zero the choice before loading the submenu
  while true; do
    command="" # initialize command
    device_menu_choice=$(dialog --no-collapse --title "Meshtastic Device Settings" --default-item "$device_menu_choice" --cancel-label "Back" --item-help --menu "Select a Device setting or run the wizard" 20 50 20 \
      1 "Wizard (set all)" "" \
      2 "Role" "" \
      3 "GPIO for user button" "Has not been tested on Femtofox" \
      4 "GPIO for PWM Buzzer" "Has not been tested on Femtofox" \
      5 "Rebroadcast mode" "" \
      6 "Nodeinfo broadcast interval" "" \
      7 "Double tap as button press" "Has not been tested on Femtofox" \
      8 "Disable triple click" "" \
      9 "POSIX Timezone" "" \
      " " "" "" \
      10 "Back to Settings Menu" "" 3>&1 1>&2 2>&3)
    [ $? -eq 1 ] && break # Exit the loop if the user selects "Cancel" or closes the dialog
    case $device_menu_choice in
      1) device_settings "wizard" ;; # Wizard
      2) device_settings "role" ;;
      3) device_settings "button_gpio" ;;
      4) device_settings "buzzer_gpio" ;;
      5) device_settings "rebroadcast_mode" ;;
      6) device_settings "Nodeinfo_broadcast_interval" ;;
      7) device_settings "double_tap_as_button_press" ;;
      8) device_settings "disable_triple_click" ;;
      9) device_settings "posix_timezone" ;;
      10) break ;;
    esac
  done
}

if ! echo $(femto-utils.sh -C "meshtasticd") | sed 's/\x1b\[[0-9;]*m//g' | grep -q ", running"; then
  dialog --no-collapse --title "Meshtasticd service" --yesno "Meshtasticd service is not running but is required.\n\nStart service?" 9 50
  if [ $? -eq 0 ]; then #unless cancel/no
    femto-meshtasticd-config.sh -s
    echo "Waiting for meshtasticd service to start..."
    sleep 3
    if ! echo $(femto-utils.sh -C "meshtasticd") | sed 's/\x1b\[[0-9;]*m//g' | grep -q ", running"; then
      dialog --no-collapse --colors --title "Meshtasticd service" --msgbox "Meshtasticd service ($(femto-utils.sh -R "$(femto-utils.sh -C "meshtasticd")")) failed to run, but is required." 7 50
    fi
  fi
fi

if echo $(femto-utils.sh -C "meshtasticd") | sed 's/\x1b\[[0-9;]*m//g' | grep -q ", running"; then
  get_current_meshtastic_config
fi

# Main menu
while true; do

  meshtastic_settings_menu_choice=$(dialog --no-collapse --cancel-label "Back" --default-item "$meshtastic_settings_menu_choice" --item-help --menu "Meshtastic settings" 16 40 5 \
    1 "User" "" \
    2 "Channels" "" \
    3 "Device" "" \
    4 "LoRa" "" \
    5 "Security" "" \
    " " "" "" \
    6 "Back to previous menu" "" 3>&1 1>&2 2>&3)
  [ $? -eq 1 ] && break # Exit the loop if the user selects "Cancel" or closes the dialog
  case $meshtastic_settings_menu_choice in
    1) user_menu ;;
    2) channels_menu ;;
    3) device_menu ;;
    4) lora_menu ;;
    5) security_menu ;;
    6) break ;;
  esac
done