#!/bin/bash

help=$(cat <<EOF
Options are:
-h             This message
-f             Femtofox pinout
-z             Femtofox Smol/Zero pinout
-t             Femtofox Tiny pinout
-l             Luckfox pinout
EOF
)

if [ $# -eq 0 ]; then
  echo "No arguments provided."
  echo -e "$help"
  exit 1
fi

# luckfox="\
# |Pin #|Pin ID |Function      | Luckfox |Pin #|Pin ID |Function      |\n\
# |-----|-------|--------------|---------|-----|-------|--------------|\n\
# |1    |VBus   |5V in/out     |   USB   |22   |1V8    |1.8V out      |\n\
# |2    |GND    |              |         |21   |GND    |              |\n\
# |3    |3V3    |3.3V out      |         |20   |4C1    |1v8 IO, SARADC|\n\
# |4/42 |1B2    |Debug UART2-TX|         |19   |4C0    |1v8 IO, SARADC|\n\
# |5/43 |1B3    |Debug UART2-RX|     [b] |18/4 |0A4    |3v3 IO        |\n\
# |6/48 |1C0    |CS0, IO       |         |17/55|1C7    |IRQ, IO       |\n\
# |7/49 |1C1    |CLK, IO       |         |16/54|1C6    |BUSY, IO      |\n\
# |8/50 |1C2    |MOSI, IO      |         |15/59|1D3    |i2c SCL       |\n\
# |9/51 |1C3    |MISO, IO      |         |14/58|1D2    |i2c SDA       |\n\
# |10/52|1C4    |UART4-TX      |         |13/57|1D1    |UART3-RX, NRST|\n\
# |11/53|1C5    |UART4-RX      |   ETH   |12/56|1D0    |UART3-TX, RXEN|\n\
# |-----|-------|--------------|---------|-----|-------|--------------|\n\
#                               R R G T T\n\
#                               X X N X X\n\
#                               - + D - +"

luckfox="
                     ─────────────────                      \n\
           VBUS 5V ●│●   │ USB-C │   ●│● 1V8 OUT            \n\
               GND ●│●   │       │   ●│● GND                \n\
        3V3 IN/OUT ●│●    ───────    ●│● 145 (1.8V)         \n\
UART-TX2 DEBUG, 42 ●│●               ●│● 144 (1.8V)         \n\
UART-RX2 DEBUG, 43 ●│●        [BTN]  ●│● 4                  \n\
           CS0, 48 ●│●               ●│● 55, IRQ            \n\
           CLK, 49 ●│●               ●│● 54  BUSY           \n\
          MOSI, 50 ●│●               ●│● 59, I2C SCL        \n\
          MISO, 51 ●│●               ●│● 58, I2C SDA        \n\
      UART4-RX, 52 ●│●               ●│● 57, UART3-RX, NRST \n\
      UART4-TX, 53 ●│●      ETH      ●│● 56, UART3-TX  RXEN \n\
                     ──●──●──●──●──●──                      \n\
                       R  R  G  T  T                        \n\
                       X  X  N  X  X                        \n\
                       -  +  D  -  +                        \n\
GPIO BANK 0: 4                                              \n\
GPIO BANK 1: 42 43 48 49 50 51 52 53 54 55 56 57 58 59      \n\
GPIO BANK 4: 144 145                                           "

femtofox="\
 ──────────────────────────────────────────────────────────────── \n\
│( ):FUSE ●│●    USB-C    ●│●         PWR-IN |+ -| 3.3-5V     ( )│\n\
│───────  ●│●             ●│●                 ───                │\n\
│ USB-C │ ●│●             ●│●     ─────────────────────────────  │\n\
│ POWER │ ●│●   LUCKFOX   ●│●    │        _____________        │ │\n\
│───────  ●│●  PICO MINI  ●│●    │       │             │       │ │\n\
│───      ●│●             ●│●    │   E   │             │       │ │\n\
│ ● │GND  ●│●   FOXHOLE   ●│●    │   2   │             │       │ │\n\
│ ● │3V3  ●│●             ●│●    │   2   │ E22 900M22S │       │ │\n\
│ ● │TX4  ●│●             ●│●    │   |   │             │       │ │\n\
│ ● │RX4  ●│●             ●│●    │   9   │             │       │ │\n\
│───      ●│●             ●│●    │   0   │_____________│       │ │\n\
│( )        ───●─●─●─●─●───      │   0     ___________         │ │\n\
│──────────────────              │   M    │           │        │ │\n\
│ ● RX-            │  I2C GROVE  │   3    │   SEEED   │        │ │\n\
│ ● RX+            │   ───────   │   0    │WIO  SX1262│        │ │\n\
│ ● GND  ETHERNET  │  │● ● ● ●│  │   S    │           │        │ │\n\
│ ● TX-            │  │───────│  │        │___________│        │ │\n\
│ ● TX+            │  │● ● ● ●│  │                             │ │\n\
│──────────────────    ───────    ─────────────────────────────  │\n\
│   ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●   │\n\
│( )●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●( )│\n\
 ──────────────────────────────────────────────────────────────── \n\
                                                                  \n\
                R              M  M                               \n\
    G           X        G  C  O  I  3           G     S  S  3    \n\
    N           E        N  L  S  S  V           N     C  D  V    \n\
    D           N        D  K  I  O  3           D     L  A  3    \n\
    ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●    \n\
    ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●    \n\
    C  B  I  G     G              G        G  R  R  T  G  5  5    \n\
    S  U  R  N     N              N        N  S  X  X  N  V  V    \n\
    0  S  Q  D     D              D        D  T  4  4  D          \n\
       Y                                                          "
femtofox_zero="coming soon"

femtofox_tiny="coming soon"


# Parse options
while getopts "hlfzt" opt; do
  case ${opt} in
    h) # Option -h (help)
      echo -e "$help"
      ;;
    f) # Option -f (femtofox)
      echo "$femtofox"
      ;;
    z) # Option -z (femtofox zero)
      echo "$femtofox_zero"
      ;;
    t) # Option -t (femtofox tiny)
      echo "$femtofox_tiny"
      ;;
    l)  # Option -l (luckfox)
      echo "$luckfox"
      ;;
    \?)  # Invalid option
      echo "Invalid option: -$OPTARG"
      echo -e "$help"
      exit 1
      ;;
  esac
done