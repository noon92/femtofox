#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Try \`sudo femto-meshtasticd-config\`."
   exit 1
fi

args=$@

loading() {
  dialog --no-collapse --infobox "$1" 5 45
}

config_url() {
  femto-config -c &&  (
    newurl=$(dialog --no-collapse --title "Meshtastic URL" --inputbox "The Meshtastic configuration URL allows for automatic configuration of all Meshtastic LoRa settings and channels.\n\nNew Meshtastic LoRa configuration URL (SHIFT+INS to paste):" 11 63 3>&1 1>&2 2>&3)
    if [ -n "$newurl" ]; then #if a URL was entered
      dialog --no-collapse --title "$title" --yesno "New Meshtastic LoRa configuration URL:\n$newurl\n\nConfirm?" 15 60
      if [ $? -eq 0 ]; then #unless cancel/no
        loading "Sending command..."
        dialog --no-collapse --colors --title "Meshtastic URL" --msgbox "$(femto-meshtasticd-config.sh -q "$newurl" && echo -e "\n\Z4Command successful!\Zn\n" || echo -e "\n\Z1Command failed.\Zn\n")" 0 0
      fi
    fi
    return
  )
}

#set lora radio
set_lora_radio() {
  choice=""   # zero the choice before loading the submenu
  while true; do
    echo "Checking LoRa radio..."
    #Display filename, if exists: $(files=$(ls /etc/meshtasticd/config.d/* 2>/dev/null) && [ -n "$files" ] && echo "\n\nConfiguration files in use:\n$files" | paste -sd, -))
    choice=$(dialog --no-collapse --colors --cancel-label "Cancel" --default-item "$choice" --title "Meshtastic LoRa radio" --item-help --menu "Currently configured LoRa radio:\n$(femto-utils.sh -R "$(femto-meshtasticd-config.sh -k)")$(ls -1 /etc/meshtasticd/config.d 2>/dev/null | grep -v '^femto_' | paste -sd ', ' - | sed 's/^/ (/; s/$/)/; s/,/, /g' | grep -v '^ ()$')" 22 50 10 \
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
      "Cancel" "" "" 3>&1 1>&2 2>&3)
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
      return
    fi
  done
}

lora_settings_actions() {
  local title="Meshtastic LoRa Settings"

  meshtastic_command_result() {
    if [ $1 -eq 1 ]; then
      dialog --no-collapse --colors --title "$title" --msgbox "$(echo -e "\Z1Command FAILED!\Zn\n\nLog:\n$2")" 0 0
    elif [ $1 -eq 0 ]; then
      dialog --no-collapse --colors --title "$title" --msgbox "$(echo -e "\Z4Command Successful!\Zn")" 6 45
    fi
  }

  if [ "$1" = "set_lora_radio_model" ] || [ "$1" = "wizard" ]; then
    femto-config -c && {
      set_lora_radio
    }
    [ "$1" != "wizard" ] && return
  fi

  if [ "$1" = "config_url" ] || [ "$1" = "wizard" ]; then
    femto-config -c && {
      choice=""   # zero the choice before loading the submenu
      while true; do
        choice=$(dialog --no-collapse --title "$title" --cancel-label "Cancel" --default-item "True" --item-help --menu "Meshtastic configuration method" 8 50 0 \
          "Automatic configuration with URL" "x" "" \
          "Manual configuration" "x" "" \
          " " "" "" \
          "Cancel" "" "" 3>&1 1>&2 2>&3)
        [ $? -eq 1 ] || [ "$choice" == "Cancel" ] && return # Exit the loop if the user selects "Cancel" or closes the dialog
        [ "$choice" == "" ] && continue #restart loop if no choice made
        [ "$choice" == "Manual configuration" ] && break
        [ "$choice" == "Automatic configuration with URL" ] && config_url
        return
      done
    }
  fi

  if [ "$1" = "region" ] || [ "$1" = "wizard" ]; then
    femto-config -c && {
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
      menu_items+=("" "" "" "Cancel" "" "")
      while true; do
        choice=$(dialog --no-collapse --title "$title" --cancel-label "Cancel" --default-item "LONG_FAST" --item-help --menu "Region (default: UNSET)?" 8 40 0 \
          "${menu_items[@]}" 3>&1 1>&2 2>&3)
        [ $? -eq 1 ] || [ "$choice" == "Cancel" ] && break # Exit the loop if the user selects "Cancel" or closes the dialog
        [ "$choice" == "" ] && continue # Restart loop if no choice made
        set -o pipefail
        output=$(femto-meshtasticd-config.sh -e $choice | tee /dev/tty)
        exit_status=$?
        set +o pipefail
        meshtastic_command_result $exit_status "$output"
        break
      done
    }
    [ "$1" != "wizard" ] && return
  fi

  if [ "$1" = "use_modem_preset" ] || [ "$1" = "wizard" ]; then
    femto-config -c && {
      choice=""   # zero the choice before loading the submenu
      while true; do
        choice=$(dialog --no-collapse --title "$title" --cancel-label "Cancel" --default-item "True" --item-help --menu "Use modem preset?" 8 40 0 \
          "True" "(default)" "" \
          "False" "" "" \
          " " "" "" \
          "Cancel" "" "" 3>&1 1>&2 2>&3)
        [ $? -eq 1 ] || [ "$choice" == "Cancel" ] && break # Exit the loop if the user selects "Cancel" or closes the dialog
        [ "$choice" == "" ] && continue #restart loop if no choice made
        using_preset="$choice"
        set -o pipefail
        output=$(femto-meshtasticd-config.sh -P $(echo "$choice" | tr '[:upper:]' '[:lower:]') | tee /dev/tty) # make lower case
        exit_status=$?
        set +o pipefail
        meshtastic_command_result $exit_status "$output"
        break
      done
    }
    [ "$1" != "wizard" ] && return
  fi

  if [ "$1" = "wizard" ] && [ "$using_preset" = "False" ]; then
    dialog --no-collapse --title "$title" --colors --msgbox "Not using preset, so skipping Preset setting." 6 50
  else
    if [ "$1" = "preset" ] || [ "$1" = "wizard" ]; then
      femto-config -c && {
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
        menu_items+=("" "" "" "Cancel" "" "")
        while true; do
          choice=$(dialog --no-collapse --title "$title" --cancel-label "Cancel" --default-item "LONG_FAST" --item-help --menu "Preset?" 8 40 0 \
            "${menu_items[@]}" 3>&1 1>&2 2>&3)
          [ $? -eq 1 ] || [ "$choice" == "Cancel" ] && break # Exit the loop if the user selects "Cancel" or closes the dialog
          [ "$choice" == "" ] && continue # Restart loop if no choice made
          set -o pipefail
          output=$(femto-meshtasticd-config.sh -E $choice | tee /dev/tty)
          exit_status=$?
          set +o pipefail
          meshtastic_command_result $exit_status "$output"
          break
        done
      }
      [ "$1" != "wizard" ] && return
    fi
  fi
  
  if [ "$1" = "wizard" ] && [ "$using_preset" = "True" ]; then
    dialog --no-collapse --title "$title" --colors --msgbox "Using preset, so skipping Bandwidth, Spread Factor and Coding Rate settings." 7 50
  else
    if [ "$1" = "bandwidth" ] || [ "$1" = "wizard" ]; then
      femto-config -c && {
        options=("31" "62" "125" "250" "500")
        menu_items=()
        for option in "${options[@]}"; do
          menu_items+=("$option" "x" "")
        done
        menu_items+=("" "" "" "Cancel" "" "")
        while true; do
          choice=$(dialog --no-collapse --title "$title" --cancel-label "Cancel" --item-help --menu "Bandwidth (only used if modem preset is disabled)?" 8 40 0 \
            "${menu_items[@]}" 3>&1 1>&2 2>&3)
          [ $? -eq 1 ] || [ "$choice" == "Cancel" ] && break # Exit the loop if the user selects "Cancel" or closes the dialog
          [ "$choice" == "" ] && continue # Restart loop if no choice made
          set -o pipefail
          output=$(femto-meshtasticd-config.sh -b $choice | tee /dev/tty)
          exit_status=$?
          set +o pipefail
          meshtastic_command_result $exit_status "$output"
          break
        done
      }
      [ "$1" != "wizard" ] && return
    fi

    if [ "$1" = "spread_factor" ] || [ "$1" = "wizard" ]; then
      femto-config -c && {
        options=("7" "8" "9" "10" "11" "12")
        menu_items=()
        for option in "${options[@]}"; do
          menu_items+=("$option" "x" "")
        done
        menu_items+=("" "" "" "Cancel" "" "")
        while true; do
          choice=$(dialog --no-collapse --title "$title" --cancel-label "Cancel" --item-help --menu "Spread factor (only used if modem preset is disabled)?" 8 40 0 \
            "${menu_items[@]}" 3>&1 1>&2 2>&3)
          [ $? -eq 1 ] || [ "$choice" == "Cancel" ] && break # Exit the loop if the user selects "Cancel" or closes the dialog
          [ "$choice" == "" ] && continue # Restart loop if no choice made
          set -o pipefail
          output=$(femto-meshtasticd-config.sh -f $choice | tee /dev/tty)
          exit_status=$?
          set +o pipefail
          meshtastic_command_result $exit_status "$output"
          break
        done
      }
      [ "$1" != "wizard" ] && return
    fi

    if [ "$1" = "coding_rate" ] || [ "$1" = "wizard" ]; then
      femto-config -c && {
        options=("5" "6" "7" "8")
        menu_items=()
        for option in "${options[@]}"; do
          menu_items+=("$option" "x" "")
        done
        menu_items+=("" "" "" "Cancel" "" "")
        while true; do
          choice=$(dialog --no-collapse --title "$title" --cancel-label "Cancel" --item-help --menu "Coding rate (only used if modem preset is disabled)?" 8 40 0 \
            "${menu_items[@]}" 3>&1 1>&2 2>&3)
          [ $? -eq 1 ] || [ "$choice" == "Cancel" ] && break # Exit the loop if the user selects "Cancel" or closes the dialog
          [ "$choice" == "" ] && continue # Restart loop if no choice made
          set -o pipefail
          output=$(femto-meshtasticd-config.sh -C $choice | tee /dev/tty)
          exit_status=$?
          set +o pipefail
          meshtastic_command_result $exit_status "$output"
          break
        done
      }
      [ "$1" != "wizard" ] && return
    fi
  fi

  if [ "$1" = "frequency_offset" ] || [ "$1" = "wizard" ]; then
    femto-config -c && {
      input=$(dialog --no-collapse --title "$title" --cancel-label "Cancel" --inputbox "Frequency offset (default: 0)" 8 50 3>&1 1>&2 2>&3)
      if [ $? -ne 1 ] && [ -n "$input" ]; then
        set -o pipefail
        output=$(femto-meshtasticd-config.sh -O $input | tee /dev/tty)
        exit_status=$?
        set +o pipefail
        meshtastic_command_result $exit_status "$output"
      fi
    }
    [ "$1" != "wizard" ] && return
  fi

  if [ "$1" = "hop_limit" ] || [ "$1" = "wizard" ]; then
    femto-config -c && {
      input=$(dialog --no-collapse --title "$title" --cancel-label "Cancel" --inputbox "Hop limit (default: 3)\nExcessive hop limit increases congestion!" 9 50 3>&1 1>&2 2>&3)
      if [ $? -ne 1 ] && [ -n "$input" ]; then
        set -o pipefail
        output=$(femto-meshtasticd-config.sh -H $input | tee /dev/tty)
        exit_status=$?
        set +o pipefail
        meshtastic_command_result $exit_status "$output"
      fi
    }
    [ "$1" != "wizard" ] && return
  fi

  if [ "$1" = "tx_enabled" ] || [ "$1" = "wizard" ]; then
    femto-config -c && {
      choice=""   # zero the choice before loading the submenu
      while true; do
        choice=$(dialog --no-collapse --title "$title" --cancel-label "Cancel" --default-item "True" --item-help --menu "Enable TX?" 8 40 0 \
          "True" "(default)" "" \
          "False" "" "" \
          " " "" "" \
          "Cancel" "" "" 3>&1 1>&2 2>&3)
        [ $? -eq 1 ] || [ "$choice" == "Cancel" ] && break # Exit the loop if the user selects "Cancel" or closes the dialog
        [ "$choice" == "" ] && continue #restart loop if no choice made
        set -o pipefail
        output=$(femto-meshtasticd-config.sh -T $(echo "$choice" | tr '[:upper:]' '[:lower:]') | tee /dev/tty) # make lower case
        exit_status=$?
        set +o pipefail
        meshtastic_command_result $exit_status "$output"
        break
      done
    }
    [ "$1" != "wizard" ] && return
  fi

  if [ "$1" = "tx_power" ] || [ "$1" = "wizard" ]; then
    femto-config -c && {
      input=$(dialog --no-collapse --colors --title "$title" --cancel-label "Cancel" --inputbox "\
\Z1\ZuWARNING!\Zn\n\
Setting a 33db radio above 8db will \Zupermanently\Zn damage it.\n\
ERP above 27db violates EU law.\n\
ERP above 36db violates US (unlicensed) law.\n\
\n\
TX power in db (default: 22)" 13 62 3>&1 1>&2 2>&3)
      if [ $? -ne 1 ] && [ -n "$input" ]; then
        set -o pipefail
        output=$(femto-meshtasticd-config.sh -X $input | tee /dev/tty)
        exit_status=$?
        set +o pipefail
        meshtastic_command_result $exit_status "$output"
      fi
    }
    [ "$1" != "wizard" ] && return
  fi

  if [ "$1" = "frequency_slot" ] || [ "$1" = "wizard" ]; then
    femto-config -c && {
      input=$(dialog --no-collapse --title "$title" --cancel-label "Cancel" --inputbox "Frequency slot (0 for automatic)" 8 50 3>&1 1>&2 2>&3)
      if [ $? -ne 1 ] && [ -n "$input" ]; then
        set -o pipefail
        output=$(femto-meshtasticd-config.sh -F $input | tee /dev/tty)
        exit_status=$?
        set +o pipefail
        meshtastic_command_result $exit_status "$output"
      fi
    }
    [ "$1" != "wizard" ] && return
  fi

  if [ "$1" = "override_duty_cycle" ] || [ "$1" = "wizard" ]; then
    femto-config -c && {
      while true; do
        choice=$(dialog --no-collapse --title "$title" --cancel-label "Cancel" --default-item "False" --item-help --menu "Override duty cycle?\nMay have legal ramifications." 9 40 0 \
          "True" "" "" \
          "False" "(default)" "" \
          " " "" "" \
          "Cancel" "" "" 3>&1 1>&2 2>&3)
        [ $? -eq 1 ] || [ "$choice" == "Cancel" ] && break # Exit the loop if the user selects "Cancel" or closes the dialog
        [ "$choice" == "" ] && continue #restart loop if no choice made
        set -o pipefail
        output=$(femto-meshtasticd-config.sh -V $(echo "$choice" | tr '[:upper:]' '[:lower:]') | tee /dev/tty) # make lower case
        exit_status=$?
        set +o pipefail
        meshtastic_command_result $exit_status "$output"
        break
      done
    }
    [ "$1" != "wizard" ] && return
  fi

  if [ "$1" = "sx126x_rx_boosted_gain" ] || [ "$1" = "wizard" ]; then
    femto-config -c && {
      while true; do
        choice=$(dialog --no-collapse --title "$title" --cancel-label "Cancel" --default-item "True" --item-help --menu "Enable SX126X RX boosted gain?" 8 40 0 \
          "True" "(default)" "" \
          "False" "" "" \
          " " "" "" \
          "Cancel" "" "" 3>&1 1>&2 2>&3)
        [ $? -eq 1 ] || [ "$choice" == "Cancel" ] && break # Exit the loop if the user selects "Cancel" or closes the dialog
        [ "$choice" == "" ] && continue #restart loop if no choice made
        set -o pipefail
        output=$(femto-meshtasticd-config.sh -B $(echo "$choice" | tr '[:upper:]' '[:lower:]') | tee /dev/tty) # make lower case
        exit_status=$?
        set +o pipefail
        meshtastic_command_result $exit_status "$output"
        break
      done
    }
    [ "$1" != "wizard" ] && return
  fi

  if [ "$1" = "override_frequency" ] || [ "$1" = "wizard" ]; then
    femto-config -c && {
      input=$(dialog --no-collapse --title "$title" --cancel-label "Cancel" --inputbox "Override frequency in MHz (0 for none).\nOverrides frequency slot." 9 50 3>&1 1>&2 2>&3)
      if [ $? -ne 1 ] && [ -n "$input" ]; then
        set -o pipefail
        output=$(femto-meshtasticd-config.sh -v $input | tee /dev/tty | tee /dev/tty)
        exit_status=$?
        set +o pipefail
        meshtastic_command_result $exit_status "$output"
      fi
    }
    [ "$1" != "wizard" ] && return
  fi

  if [ "$1" = "ignore_mqtt" ] || [ "$1" = "wizard" ]; then
    femto-config -c && {
      while true; do
        choice=$(dialog --no-collapse --title "$title" --cancel-label "Cancel" --default-item "False" --item-help --menu "Ignore MQTT?" 8 40 0 \
          "True" "" "" \
          "False" "(default)" "" \
          " " "" "" \
          "Cancel" "" "" 3>&1 1>&2 2>&3)
        [ $? -eq 1 ] || [ "$choice" == "Cancel" ] && break # Exit the loop if the user selects "Cancel" or closes the dialog
        [ "$choice" == "" ] && continue #restart loop if no choice made
        set -o pipefail
        output=$(femto-meshtasticd-config.sh -G $(echo "$choice" | tr '[:upper:]' '[:lower:]') | tee /dev/tty) # make lower case
        exit_status=$?
        set +o pipefail
        meshtastic_command_result $exit_status "$output"
        break
      done
    }
    [ "$1" != "wizard" ] && return
  fi

  if [ "$1" = "ok_to_mqtt" ] || [ "$1" = "wizard" ]; then
    femto-config -c && {
      while true; do
        choice=$(dialog --no-collapse --title "$title" --cancel-label "Cancel" --default-item "False" --item-help --menu "OK to MQTT?" 8 40 0 \
          "True" "" "" \
          "False" "(default)" "" \
          " " "" "" \
          "Cancel" "" "" 3>&1 1>&2 2>&3)
        [ $? -eq 1 ] || [ "$choice" == "Cancel" ] && break # Exit the loop if the user selects "Cancel" or closes the dialog
        [ "$choice" == "" ] && continue #restart loop if no choice made
        set -o pipefail
        output=$(femto-meshtasticd-config.sh -K $(echo "$choice" | tr '[:upper:]' '[:lower:]') | tee /dev/tty) # make lower case
        exit_status=$?
        set +o pipefail
        meshtastic_command_result $exit_status "$output"
        break
      done
    }
    [ "$1" != "wizard" ] && return
  fi

  # if we're in wizard mode AND there are no script arguments, then display a message
  [ "$1" = "wizard" ] && [ -n "$args" ] && dialog --no-collapse --title "$title" --colors --msgbox "Meshtastic LoRa Settings Wizard complete!" 6 50

  [ "$1" = "wizard" ] && return # quit function if wizard
}


# Parse options
help="If script is run without arguments, menu will load.\n\
Options are:\n\
-h           This message\n\
-w           Wizard mode\
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


LoRa_menu_choice=""   # zero the choice before loading the submenu
while true; do
  LoRa_menu_choice=$(dialog --no-collapse --title "Meshtastic LoRa Settings" --default-item "$LoRa_menu_choice" --cancel-label "Back" --item-help --menu "LoRa settings can also be set automatically by entering a Meshtastic configuration URL." 30 50 20 \
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

