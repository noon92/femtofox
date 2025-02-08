#!/bin/bash

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Try \`sudo femto-meshtasticd-config\`."
  exit 1
fi

help=$(cat <<EOF
Options are:
-h             This message
-a "enable"    Enable/disable ACT LED. Options: "enable" "disable" "check". If no argument is specified, setting in /etc/femto.conf will be used
-r             Reboot
-s             Shutdown
-l "enable"    Enable/disable logging. Options: "enable" "disable" "check"
-i             System info (all)
-p             Peripherals info
-c             CPU info
-n             Networking info
-o             OS info
-S             Storage & RAM info
-t "enable"    Enable/disable/start/stop/check ttyd (web terminal).  Options: "enable" "disable" "start" "stop" "check"
-E             Generate/overwrite SSH encryption keys
-C "service"   Check if service is enabled, disabled, running
-R "command"   Replace colors for dialog menus
EOF
)

if [ $# -eq 0 ]; then
  echo "No arguments provided."
  echo -e "$help"
  exit 1
fi

act_led() {
  if [ "$1" = "disable" ]; then
    echo "none" > /sys/class/leds/work/trigger
    grep -qE '^act_led=' /etc/femto.conf && sed -i -E 's/^act_led=.*/act_led=disable/' /etc/femto.conf || echo 'act_led=disable' | tee -a /etc/femto.conf > /dev/null 
    echo "Disabled activity LED."
    exit 0
  elif [ "$1" = "enable" ]; then
    echo "activity" > /sys/class/leds/work/trigger
    grep -qE '^act_led=' /etc/femto.conf && sed -i -E 's/^act_led=.*/act_led=enable/' /etc/femto.conf || echo 'act_led=enable' | tee -a /etc/femto.conf > /dev/null 
    echo "Enabled activity LED."
    exit 0
  elif [ "$1" = "check" ]; then
    if grep -qE '^act_led=enable' /etc/femto.conf; then
      echo -e "\033[0;34menabled\033[0m"
    elif grep -qE '^act_led=disable' /etc/femto.conf; then
      echo -e "\033[0;31mdisabled\033[0m"
    else
      echo "unknown"
    fi
  elif [ -z $1 ]; then
    local state=$(act_led "check" 2>/dev/null)
    if [[ "$state" =~ "enabled" ]]; then
      act_led "enable"
    elif [[ "$state" =~ "disabled" ]]; then
      act_led "disable"
    fi
  fi
}

cpu_info() {
  local core="$(cat /sys/firmware/devicetree/base/model | tr -d '\0')"
  local cpu_model="$(dmesg | grep "soc_id" | sed -n 's/.*soc_id: //p' | tr -d '\0')"; cpu_model="${cpu_model:-$(cat /proc/device-tree/compatible | sed 's/.*,\([^,]*\)$/\1/' | tr -d '\0')}"
  local cpu_architecture="$(uname -m) ($(dpkg --print-architecture) $(python3 -c "import platform; print(platform.architecture()[0])"))"
  local cpu_temp="$(echo "scale=1; $(cat /sys/class/thermal/thermal_zone0/temp) / 1000" | bc)°C"
  local cpu_speed="$(lscpu | grep "CPU min MHz" | awk '{print int($4)}')-$(lscpu | grep "CPU max MHz" | awk '{print int($4)}')mhz"
  local cpu_serial="$(awk '/Serial/ {print $3}' /proc/cpuinfo)"

  echo -e "\
Core:$core\n\
Model:$cpu_model\n\
Architecture:$cpu_architecture\n\
Speed:$cpu_speed x $(nproc) cores\n\
Temperature:$cpu_temp\n\
Serial #:$cpu_serial"
}

storage_info() {
  local microsd_size="$(df --block-size=1 / | awk 'NR==2 {total=$2; avail=$4; total_human=sprintf("%.2f", total/1024/1024/1024); avail_human=sprintf("%.2f", avail/1024/1024/1024); printf "%.2f GB (%.2f%% free)", total_human, (avail/total)*100}')"
  local memory="$(free -m | awk 'NR==2{printf "%d MB (%.2f%% free)\n", $2, 100 - (($3/$2)*100)}')"
  local swap="$(free -m | awk 'NR==3 {if ($2 > 1000) {printf "%.2f GB    (%.2f%% free)", $2/1024, ($4/$2)*100} else {printf "%d MB (%.2f%% free)", $2, ($4/$2)*100}}')"
  local mounted_drives="$( [ "$(for dir in /mnt/*/; do [ -d "$dir" ] && echo -n "/mnt${dir#"/mnt"} "; done)" ] && echo "$(for dir in /mnt/*/; do [ -d "$dir" ] && echo -n "/mnt${dir#"/mnt"} "; done | sed 's/\/$//')" || echo "none" )"

  echo -e "\
microSD size:$microsd_size\n\
Memory:$memory\n\
Swap:$swap\n\
Mnted drives:$mounted_drives"
}

os_info() {
  local os_version="Foxbuntu v$(grep -oP 'major=\K[0-9]+' /etc/foxbuntu-release).$(grep -oP 'minor=\K[0-9]+' /etc/foxbuntu-release)$(output=$(grep -o 'patch=[1-9][0-9]*' /etc/foxbuntu-release | cut -d= -f2) && [ -n "$output" ] && echo ".$output")$(grep -oP 'hotfix=\K[a-z]+' /etc/foxbuntu-release) ($(lsb_release -d | awk -F'\t' '{print $2}') $(lsb_release -c | awk -F'\t' '{print $2}'))"
  local system_uptime="$(uptime -p | awk '{$1=""; print $0}' | sed -e 's/ day\b/d/g' -e 's/ hour\b/h/g' -e 's/ hours\b/h/g' -e 's/ minute\b/m/g' -e 's/ minutes\b/m/g' | sed 's/,//g')"
  local kernel_active_modules="$(lsmod | awk 'NR>1 {print $1}' | tr '\n' ' ' && echo)"
  local kernel_boot_modules="$(modules=$(sed -n '6,$p' /etc/modules | sed ':a;N;$!ba;s/\n/, /g;s/, $//'); [ -z "$modules" ] && echo "none" || echo "$modules")"
  local ttyd_enabled="$(femto-utils.sh -C "ttyd")"
  local logging_enabled="$(logging "check" | sed 's/\x1b\[[0-9;]*m//g')"
  local act_led="$(femto-utils.sh -a "check" | sed -r 's/\x1B\[[0-9;]*[mK]//g')" #remove color from output

  echo -e "\
OS:$os_version\n\
Kernel ver:$(uname -r)\n\
Uptime:$system_uptime\n\
System time:$(date)\n\
K mods active:$kernel_active_modules\n\
K boot mods:$kernel_boot_modules\n\
Web terminal:$ttyd_enabled\n\
Logging:$logging_enabled\n\
Activity LED:$act_led"
}

networking_info() {
  local wifi_status="$(femto-network-config.sh -w | grep -v '^$' | grep -v '^Hostname')" #remove hostname line, as it's identical to the one in ethernet settings
  local eth_status="$(femto-network-config.sh -e)"
  echo -e "$wifi_status\n\

$eth_status"
}

peripherals_info() {
  local usb_mode="$(cat /sys/devices/platform/ff3e0000.usb2-phy/otg_mode)"
  local spi0_state="$([ "$(awk -F= '/^SPI0_M0_STATUS/ {print $2}' /etc/luckfox.cfg)" -eq 1 ] && echo "enabled" || echo "disabled")"
  local spi0_speed="$((0x$(xxd -p /sys/firmware/devicetree/base/spi@ff500000/spidev@0/spi-max-frequency | tr -d '\n')))"
  local i2c3_state="$([ "$(awk -F= '/^I2C3_M1_STATUS/ {print $2}' /etc/luckfox.cfg)" -eq 1 ] && echo "enabled" || echo "disabled")"
  local i2c3_speed="$(awk -F= '/^I2C3_M1_SPEED/ {print $2}' /etc/luckfox.cfg)"
  local uart3_state="$([ "$(awk -F= '/^UART3_M1_STATUS/ {print $2}' /etc/luckfox.cfg)" -eq 1 ] && echo "enabled" || echo "disabled")"
  local uart4_state="$([ "$(awk -F= '/^UART4_M1_STATUS/ {print $2}' /etc/luckfox.cfg)" -eq 1 ] && echo "enabled" || echo "disabled")"
  local lora_radio="$(femto-meshtasticd-config.sh -k)"
  local usb_devices="$(lsusb | grep -v 'root hub' | awk 'NR>0{printf "USB:"; for(i=7;i<=NF;i++) printf "%s ", $i; print ""} END {if (NR == 0) printf "USB:none detected"}')"
  # gather i2c addresses
  i2c_addresses=""    # initialize empty string to collect populated addresses
  while IFS= read -r line; do    # iterate over each row of output (captured at end of while loop)
    if [[ "$line" =~ ^[0-9a-f]+: ]]; then    # check if the row contains addresses (skip header row)
      columns=($line)    # split the line into columns based on spaces
      row="${columns[0]:0:1}"    # use the first numeral of the row number
      for col_idx in "${!columns[@]}"; do    # iterate columns
        if [[ $col_idx -gt 0 && "${columns[$col_idx]}" != "--" ]]; then    # skip first column (row numbers)
          [[ "$row" == "0" ]] && col_idx=$((col_idx + 8))    # if first row, we start at #7, so add 8 to the column number reported
          i2c_addresses+="0x$(printf "%x" "$((16#$row))")$(printf "%x" $((col_idx - 1))) "    # calculate hexadecimal with '0x'
        fi
      done
    fi
  done <<< "$(echo "$(sudo i2cdetect -y 3)")"
  [[ -z "$i2c_addresses" ]] && i2c_addresses="none detected"    # if no addresses found, "none detected"

  echo -e "LoRa radio:$lora_radio\n\
$usb_devices\n\
i2c devices:$i2c_addresses\n\
USB mode:$usb_mode\n\
SPI-0 state:$spi0_state\n\
SPI-0 speed:$spi0_speed\n\
i2c-3 state:$i2c3_state\n\
i2c-3 speed:$i2c3_speed\n\
UART-3 state:$uart3_state\n\
UART-4 state:$uart4_state"
}

all_system_info() {
  echo -e "\
            Femtofox\n\
    CPU:\n\
$(cpu_info)\n\
\n\
    Operating System:\n\
$(os_info)\n\
\n\
    Storage:\n\
$(storage_info)\n\)
\n\
    Networking (wlan0 & eth0):\n\
$(networking_info)\n\
\n\
    Peripherals:\n\
$(peripherals_info)\n\
\n\
    Meshtasticd:\n\
$(femto-meshtasticd-config.sh -i)"
}

# enable/disable/check system logging
logging() {
  if [ "$1" = "disable" ]; then
    msg="Disabling system logging by making /var/log immutable."
    logger $msg
    echo $msg
    chattr +i /var/log
    return 0
  elif [ "$1" = "enable" ]; then
    chattr -i /var/log
    msg="Enabling system logging by making /var/log writable."
    logger $msg
    echo $msg
    return 0
  elif [ "$1" = "check" ]; then
    lsattr -d /var/log | grep -q 'i' && echo -e "\033[0;31mdisabled\033[0m" || echo -e "\033[0;34menabled\033[0m"
  else
    echo "\`$1\` is not a valid argument for -L. Options are \"enable\" and \"disable\"."
    echo -e "$help"
  fi
}

# Dialog uses a different method to display colors, and is limited to only these 8.
replace_colors() {
  input="$1"
  input="${input//$(echo -e '\033[0;30m')/\\Z0}"   # black
  input="${input//$(echo -e '\033[0;31m')/\\Z1}"   # red
  input="${input//$(echo -e '\033[0;32m')/\\Z2}"   # green
  input="${input//$(echo -e '\033[0;33m')/\\Z3}"   # yellow
  input="${input//$(echo -e '\033[0;34m')/\\Z4}"   # blue
  input="${input//$(echo -e '\033[0;35m')/\\Z5}"   # magenta
  input="${input//$(echo -e '\033[0;36m')/\\Z6}"   # cyan
  input="${input//$(echo -e '\033[0;37m')/\\Z7}"   # white
  input="${input//$(echo -e '\033[7m')/\\Zr}"      # invert
  input="${input//$(echo -e '\033[4m')/\\Zu}"      # underline
  input="${input//$(echo -e '\e[39m')/\\Z0}"      # reset colors not underline
    input="${input//$(echo -e '\033[0m')/\\Zn}"      # reset all
  echo "$input"
}

while getopts ":harsl:ipcnoSEC:R:" opt; do
  case ${opt} in
    h) # Option -h (help)
      echo -e "$help"
      ;;
    a) # Option -a (ACT LED enable/disable/check)
      act_led $2
      exit 0 # exit immediately for boot speed
    ;;
    r) # Option -r (reboot)
      echo -e "Rebooting..."
      reboot
    ;;
    s) # Option -s (shutdown)
      echo -e "Shutting down...\n\nPower consumption will not stop."        
      logger "User requested system halt"
      halt
    ;;
    l) logging $OPTARG ;; # Option -l (Logging enable/disable/check)
    i) all_system_info ;; # Option -i (sysinfo)
    p) peripherals_info ;; # Option -p (Peripherals info)
    c) cpu_info ;; # Option -c (CPU info)
    n) networking_info ;; # Option -n (Networing info)
    o) os_info ;; # Option -o (OS info)
    S) storage_info ;; # Option -S (Storage & RAM info)
    E) # Option -E (new SSH encryption keys)
      rm /etc/ssh/ssh_host_*
      ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ""
      ssh-keygen -t rsa -b 4096 -f /etc/ssh/ssh_host_rsa_key -N ""
      chmod 600 /etc/ssh/ssh_host_*_key
      chmod 644 /etc/ssh/ssh_host_*_key.pub
      chown root:root /etc/ssh/ssh_host_*
      systemctl restart ssh
    ;;
    C) # Option -C (Check service status)
      if systemctl is-enabled $OPTARG &>/dev/null; then
        state_message="\033[0;34m\033[4menabled\e[39m, "
      else
        state_message="\033[0;31m\033[4mdisabled\e[39m, "
        exit_state=1
      fi
      full_status=$(systemctl status $OPTARG)
      if echo $full_status | grep -q "active (running)"; then
        state_message+="\033[0;34mrunning\e[0m"
        exit_state=0
      elif echo $full_status | grep -q "inactive (dead)"; then
        state_message+="\033[0;31mnot running\e[0m"
        exit_state=1
      elif echo $full_status | grep -q "failed"; then
        state_message+="\033[0;31mfailed\e[0m"
        exit_state=1
      elif echo $full_status | grep -q "activating"; then
        state_message+="activating\e[0m"
        exit_state=2
      else
        state_message+="unknown\e[0m"
        exit_state=2
      fi
      echo -e "$state_message"
      exit $exit_state
    ;;
    R) 
      replace_colors "$OPTARG"
    ;;
    \?) # Unknown option)
      echo -e "Unknown argument $1.\n$help"
    ;;
  esac
done