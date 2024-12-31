#!/bin/bash

help=$(cat <<EOF
Options are:
-h             This message
-a             Display all pinouts
-l             Luckfox pinout
-f             Femtofox pinout
-z             Femtofox Smol/Zero pinout
-t             Femtofox Tiny pinout
EOF
)

if [ $# -eq 0 ]; then
  echo "No arguments provided."
  echo -e "$help"
  exit 1
fi

luckfox="\
|Pin #|Pin ID |Function      | Luckfox |Pin #|Pin ID |Function      |\n\
|-----|-------|--------------|---------|-----|-------|--------------|\n\
|1    |VBus   |5V in/out     |   USB   |22   |1V8    |1.8V out      |\n\
|2    |GND    |              |         |21   |GND    |              |\n\
|3    |3V3    |3.3V out      |         |20   |4C1    |1v8 IO, SARADC|\n\
|4/42 |1B2    |Debug UART2-TX|         |19   |4C0    |1v8 IO, SARADC|\n\
|5/43 |1B3    |Debug UART2-RX|     [b] |18/4 |0A4    |3v3 IO        |\n\
|6/48 |1C0    |CS0, IO       |         |17/55|1C7    |IRQ, IO       |\n\
|7/49 |1C1    |CLK, IO       |         |16/54|1C6    |BUSY, IO      |\n\
|8/50 |1C2    |MOSI, IO      |         |15/59|1D3    |i2c SCL       |\n\
|9/51 |1C3    |MISO, IO      |         |14/58|1D2    |i2c SDA       |\n\
|10/52|1C4    |UART4-TX      |         |13/57|1D1    |UART3-RX, NRST|\n\
|11/53|1C5    |UART4-RX      |   ETH   |12/56|1D0    |UART3-TX, RXEN|\n\
|-----|-------|--------------|---------|-----|-------|--------------|\n\
                              R R G T T\n\
                              X X N X X\n\
                              - + D - +"

femtofox="coming soon"

femtofox_zero="coming soon"

femtofox_tiny="coming soon"


# Parse options
while getopts "halfzt" opt; do
  case ${opt} in
    h) # Option -h (help)
      echo -e "$help"
      ;;
    a)  # Option -s (ssid)
      echo "$luckfox"
      echo "\n"
      echo "$femtofox"
      echo "\n"
      echo "$femtofox_zero"
      echo "\n"
      echo "$femtofox_tiny"
      ;;
    l)  # Option -p (psk)
      sed -i "/psk=/s/\".*\"/\"$OPTARG\"/" "$wpa_supplicant_conf"
      echo "Setting PSK to $OPTARG."
      updated_wifi="true"
      ;;
    f) # Option -c (country)
      sed -i "/country=/s/=[^ ]*/=$OPTARG/" "/etc/wpa_supplicant/wpa_supplicant.conf"
      echo "Setting country to $OPTARG."
      updated_wifi="true"
      ;;
    z) # Option -r (restart wifi)
      updated_wifi="true"
      ;;
    t) # Option -r (restart wifi)
      updated_wifi="true"
      ;;
    \?)  # Invalid option
      echo "Invalid option: -$OPTARG"
      echo -e "$help"
      exit 1
      ;;
  esac
done