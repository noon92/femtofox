#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Try \`sudo femto-meshtasticd-config\`."
   exit 1
fi

export NCURSES_NO_UTF8_ACS=1
export TERM=xterm-256color
export LANG=C.UTF-8

title="Meshtastic LoRa Settings"
args=$@

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

  [ "$1" = "wizard" ] && [ -z "$args" ] && dialog --no-collapse --title "$title" --colors --msgbox "Meshtastic LoRa Settings Wizard complete!" 6 50 # if in wizard mode AND there are no script arguments, display the message
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

lora_settings_actions() {
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
        [ "$choice" == "" ] && continue #restart loop if no choice made
        [ "$choice" == "Manual configuration" ] && break
        [ "$choice" == "Automatic configuration with URL" ] && config_url "$1"
        return
      done
    fi

    dialog --no-collapse --infobox "Getting current settings from Meshtasticd.\n\nThis can take a minute..." 6 50
    while IFS=':' read -r key value; do
      eval "${key}=\"${value}\"" # Create a variable with the key name and assign it the value
    done < <(sudo femto-meshtasticd-config.sh -C settings)

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
        [ "$choice" == "" ] && continue # Restart loop if no choice made
        command+="--set lora.region $choice "
        break
      done
    fi

    if [ "$1" = "use_modem_preset" ] || [ "$1" = "wizard" ]; then
      choice=""   # zero the choice before loading the submenu
      while true; do
        choice=$(dialog --no-collapse --title "$title" --cancel-label "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" --default-item "${lora_usePreset^}" --item-help --menu "Presets are pre-defined modem settings (Bandwidth, Spread Factor, and Coding Rate) which influence both message speed and range. The vast majority of users use a preset.\n\nUse modem preset?  (current: ${lora_usePreset:-unknown})" 0 0 0 \
          "True" "(default)" "" \
          "False" "" "" \
          " " "" "" \
          "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" "" "" 3>&1 1>&2 2>&3)
        [ $? -eq 1 ] || [ "$choice" == "Cancel" ] || [ "$choice" == "Skip" ] && break # Exit the loop if the user selects "Cancel" or closes the dialog
        [ "$choice" == "" ] && continue #restart loop if no choice made
        using_preset=$choice
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
          choice=$(dialog --no-collapse --title "$title" --cancel-label "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" --default-item "${lora_modemPreset^}" --item-help --menu "The default preset will provide a strong mixture of speed and range, for most users.\n\nPreset?  (current: ${lora_modemPreset:-unknown})" 0 0 0 \
            "${menu_items[@]}" 3>&1 1>&2 2>&3)
          [ $? -eq 1 ] || [ "$choice" == "Cancel" ] || [ "$choice" == "Skip" ] && break # Exit the loop if the user selects "Cancel" or closes the dialog
          [ "$choice" == "" ] && continue # Restart loop if no choice made
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
          [ "$choice" == "" ] && continue # Restart loop if no choice made
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
          [ "$choice" == "" ] && continue # Restart loop if no choice made
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
          [ "$choice" == "" ] && continue # Restart loop if no choice made
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
        command+="--set lora.hop_limit $input "
      fi
    fi

    if [ "$1" = "tx_enabled" ] || [ "$1" = "wizard" ]; then
      choice=""   # zero the choice before loading the submenu
      while true; do
        choice=$(dialog --no-collapse --title "$title" --cancel-label "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" --default-item "${lora_txEnabled^}" --item-help --menu "Enables/disables the radio chip. Useful for hot-swapping antennas.\n\nEnable TX?  (current: ${lora_txEnabled:-unknown})" 0 0 0 \
          "True" "(default)" "" \
          "False" "" "" \
          " " "" "" \
          "$([[ "$1" == "wizard" ]] && echo "Skip" || echo "Cancel")" "" "" 3>&1 1>&2 2>&3)
        [ $? -eq 1 ] || [ "$choice" == "Cancel" ] || [ "$choice" == "Skip" ] && break # Exit the loop if the user selects "Cancel" or closes the dialog
        [ "$choice" == "" ] && continue #restart loop if no choice made
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
        [ "$choice" == "" ] && continue #restart loop if no choice made
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
        [ "$choice" == "" ] && continue #restart loop if no choice made
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
        [ "$choice" == "" ] && continue #restart loop if no choice made
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
        [ "$choice" == "" ] && continue #restart loop if no choice made
        command+="--set lora.config_ok_to_mqtt $(echo "$choice" | tr '[:upper:]' '[:lower:]') "
        break
      done
    fi

    send_settings $1
  fi
}


# Parse options
help="If script is run without arguments, menu will load.\n\
Options are:\n\
-h           This message\n\
-w           Wizard mode (skips main menu)\
"
while getopts ":hw" opt; do
  case ${opt} in
    h) # Option -h (help)
      echo -e $help
      ;;
    w) # Option -w (Wizard mode)
      lora_settings_actions "wizard"
    ;;
    \?) # Unknown option)
      echo -e "Unknown argument $1.\n$help"
    ;;
  esac
done
[ -n "$1" ] && exit # if there were arguments, exit before loading the menu

command="" # initialize command
LoRa_menu_choice=""   # zero the choice before loading the submenu
while true; do
  command="" # initialize command
  LoRa_menu_choice=$(dialog --no-collapse --title "Meshtastic LoRa Settings" --default-item "$LoRa_menu_choice" --cancel-label "Back" --item-help --menu "Select a LoRa setting or run the wizard" 30 50 20 \
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
    20 "Back to Meshtastic Menu" "" 3>&1 1>&2 2>&3)
  [ $? -eq 1 ] && break # Exit the loop if the user selects "Cancel" or closes the dialog
  case $LoRa_menu_choice in
    1) # Wizard (set all)
      lora_settings_actions "wizard"
    ;;
    2) # Set LoRa radio model)
      lora_settings_actions "set_lora_radio_model"
    ;;
    3) # Configure automatically with URL)
      config_url
    ;;
    4) # Region)
      lora_settings_actions "region"
    ;;
    5) # Use modem preset)
      lora_settings_actions "use_modem_preset"
    ;;
    6) # Preset)
      lora_settings_actions "preset"
    ;;
    7) # Bandwidth)
      lora_settings_actions "bandwidth"
    ;;
    8) # Spread factor)
      lora_settings_actions "spread_factor"
    ;;
    9) # Coding rate)
      lora_settings_actions "coding_rate"
    ;;
    10) # Frequency offset)
      lora_settings_actions "frequency_offset"
    ;;
    11) # Hop limit)
      lora_settings_actions "hop_limit"
    ;;
    12) # Enable/disable TX)
      lora_settings_actions "tx_enabled"
    ;;
    13) # TX power)
      lora_settings_actions "tx_power"
    ;;
    14) # Frequency slot)
      lora_settings_actions "frequency_slot"
    ;;
    15) # Override duty cycle)
      lora_settings_actions "override_duty_cycle"
    ;;
    16) # SX126X RX boosted gain)
      lora_settings_actions "sx126x_rx_boosted_gain"
    ;;
    17) # Override frequency)
      lora_settings_actions "override_frequency"
    ;;
    18) # Ignore MQTT)
      lora_settings_actions "ignore_mqtt"
    ;;
    19) # OK to MQTT)
      lora_settings_actions "ok_to_mqtt"
    ;;
    20) break ;;
  esac
done

