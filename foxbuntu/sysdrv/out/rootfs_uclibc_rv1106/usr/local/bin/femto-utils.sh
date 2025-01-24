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
-i             System info
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
  echo "check state"
    local state=$(act_led "check" 2>/dev/null)
    if [[ "$state" =~ "enabled" ]]; then
      act_led "enable"
    elif [[ "$state" =~ "disabled" ]]; then
      act_led "disable"
    fi
  fi
}

# at some point this will have many functions instead of one giant dump
system_info() {
  local cpu_model="$(dmesg | grep "soc_id" | sed -n 's/.*soc_id: //p')"
  local cpu_architecture="$(uname -m) ($(dpkg --print-architecture) $(python3 -c "import platform; print(platform.architecture()[0])"))"
  local cpu_temp="$(echo "scale=1; $(cat /sys/class/thermal/thermal_zone0/temp) / 1000" | bc)°C"
  local cpu_speed="$(lscpu | grep "CPU min MHz" | awk '{print int($4)}')-$(lscpu | grep "CPU max MHz" | awk '{print int($4)}')mhz"
  local cpu_serial="$(awk '/Serial/ {print $3}' /proc/cpuinfo)"

  local microsd_size="$(df --block-size=1 / | awk 'NR==2 {total=$2; avail=$4; total_human=sprintf("%.2f", total/1024/1024/1024); avail_human=sprintf("%.2f", avail/1024/1024/1024); printf "%.2f GB   (%.2f%% free)", total_human, (avail/total)*100}')"
  local memory="$(free -m | awk 'NR==2{printf "%d MB      (%.2f%% free)\n", $2, 100 - (($3/$2)*100)}')"
  local swap="$(free -m | awk 'NR==3 {if ($2 > 1000) {printf "%.2f GB    (%.2f%% free)", $2/1024, ($4/$2)*100} else {printf "%d MB    (%.2f%% free)", $2, ($4/$2)*100}}')"
  local mounted_drives="$([ "$(for dir in /mnt/*/; do echo -n "/mnt${dir#"/mnt"} "; done)" ] && echo "Mounted drives:   $(for dir in /mnt/*; do echo -n "/mnt${dir#"/mnt"} "; done | sed 's/\/$//')")"

  local os_version="Foxbuntu v$(grep -oP 'major=\K[0-9]+' /etc/foxbuntu-release).$(grep -oP 'minor=\K[0-9]+' /etc/foxbuntu-release)$(output=$(grep -o 'patch=[1-9][0-9]*' /etc/foxbuntu-release | cut -d= -f2) && [ -n "$output" ] && echo ".$output")$(grep -oP 'hotfix=\K[a-z]+' /etc/foxbuntu-release) ($(lsb_release -d | awk -F'\t' '{print $2}') $(lsb_release -c | awk -F'\t' '{print $2}'))"
  local system_uptime="$(uptime -p | awk '{$1=""; print $0}' | sed -e 's/ day\b/d/g' -e 's/ hour\b/h/g' -e 's/ hours\b/h/g' -e 's/ minute\b/m/g' -e 's/ minutes\b/m/g' | sed 's/,//g')"
  local logging_enabled="$(logging "check" | sed 's/\x1b\[[0-9;]*m//g')"
  local act_led="$(femto-utils.sh -a "check" | sed -r 's/\x1B\[[0-9;]*[mK]//g')" #remove color from output
  local kernel_active_modules="$(lsmod | awk 'NR>1 {print $1}' | tr '\n' ' ' && echo)"
  local kernel_boot_modules="$(modules=$(sed -n '6,$p' /etc/modules | sed ':a;N;$!ba;s/\n/, /g;s/, $//'); [ -z "$modules" ] && echo "none" || echo "$modules")"

  local wifi_status="$(femto-network-config.sh -w | grep -v '^$' | grep -v '^Hostname')" #remove hostname line, as it's identical to the one in ethernet settings
  local eth_status="$(femto-network-config.sh -e)"

  local usb_mode="$(cat /sys/devices/platform/ff3e0000.usb2-phy/otg_mode)"
  local spi0_state="$([ "$(awk -F= '/^SPI0_M0_STATUS/ {print $2}' /etc/luckfox.cfg)" -eq 1 ] && echo "enabled" || echo "disabled")"
  local spi0_speed="$((0x$(xxd -p /sys/firmware/devicetree/base/spi@ff500000/spidev@0/spi-max-frequency | tr -d '\n')))"
  local i2c3_state="$([ "$(awk -F= '/^I2C3_M1_STATUS/ {print $2}' /etc/luckfox.cfg)" -eq 1 ] && echo "enabled" || echo "disabled")"
  local i2c3_speed="$(awk -F= '/^I2C3_M1_SPEED/ {print $2}' /etc/luckfox.cfg)"
  local uart3_state="$([ "$(awk -F= '/^UART3_M1_STATUS/ {print $2}' /etc/luckfox.cfg)" -eq 1 ] && echo "enabled" || echo "disabled")"
  local uart4_state="$([ "$(awk -F= '/^UART4_M1_STATUS/ {print $2}' /etc/luckfox.cfg)" -eq 1 ] && echo "enabled" || echo "disabled")"

  local lora_radio="$(femto-meshtasticd-config.sh -k)"
  local usb_devices="$(lsusb | grep -v 'root hub' | awk 'NR>0{printf "USB:              "; for(i=7;i<=NF;i++) printf "%s ", $i; print ""} END {if (NR == 0) printf "USB:              None detected"}')"
  local i2c_addresses="$(i2cdetect -y 3 | awk 'NR>1 {for(i=2;i<=17;i++) if ($i == "ff" || $i == "UU") { printf "0x%02x ", (i-2) + (NR-2)*16} }' | tr -d '\n' )"

  local meshtasticd_service_status="$(femto-meshtasticd-config.sh -S)"
  local meshtasticd_info="$(femto-meshtasticd-config.sh -i)"
  echo -e "\
            Femtofox\n\
Core:             $(cat /sys/firmware/devicetree/base/model)\n\
Operating System: $os_version\n\
Kernel version:   $(uname -r)\n\
Uptime:          $system_uptime\n\
Logging:          $logging_enabled\n\
Activity LED:     $act_led\n\
System time:      $(date)\n\
K modules active: $kernel_active_modules\n\
K boot modules:   $kernel_boot_modules\n\
\n\
    CPU:\n\
Model:            $cpu_model\n\
Architecture:     $cpu_architecture\n\
Speed:            $cpu_speed x $(nproc) cores\n\
Temperature:      $cpu_temp\n\
Serial #          $cpu_serial\n\
\n\
    Storage:\n\
microSD size:     $microsd_size\n\
Memory:           $memory\n\
Swap:             $swap\n\
$mounted_drives\n\
\n\
    Networking (wlan0 & eth0):\n\
$wifi_status\n\
---
$eth_status\n\
\n\
    Interfaces:\n\
USB mode:         $usb_mode\n\
SPI-0 state:      $spi0_state\n\
SPI-0 speed:      $spi0_speed\n\
i2c-3 state:      $i2c3_state\n\
i2c-3 speed:      $i2c3_speed\n\
UART-3 state:     $uart3_state\n\
UART-4 state:     $uart4_state\n\
\n\
    Attached devices:\n\
LoRa radio:       $lora_radio\n\
$usb_devices\n\
i2c devices:      $i2c_addresses\n\
\n\
    Meshtasticd:\n\
Service status:   $meshtasticd_service_status\n\
$meshtasticd_info\
"
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

while getopts ":harsl:i" opt; do
  case ${opt} in
    h) # Option -h (help)
      echo -e $help
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
    l) # Option -l (Logging enable/disable/check)
      logging $OPTARG
    ;;
    i) system_info ;; # Option -i (sysinfo)
    \?) # Unknown option)
      echo -e "Unknown argument $1.\n$help"
    ;;
  esac
done