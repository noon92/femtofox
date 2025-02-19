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


femtofox="\
┌──────────┬────┬─────┬────┬───────────────┬───┬───────────────┐\n\
│⚪:♥KILL ●│●   │USB-C│   ●│●       PWR-IN │✚ ▬│ 3.3-5V      ⚪│\n\
├───────┐ ●│●   └─────┘   ●│●              └───┘               │\n\
│ USB-C │ ●│●             ●│●  ┌─────────────────────────────┐ │\n\
│ PWR ♥ │ ●│●   LUCKFOX   ●│●  │       ┌─────────────┐       │ │\n\
│ DEBUG │ ●│●  PICO MINI  ●│●  │       │             │       │ │\n\
├───────┘ ●│●             ●│●  │       │             │       │ │\n\
├───┐     ●│●   FOXHOLE   ●│●  │   E   │             │       │ │\n\
│ ● │GND  ●│●             ●│●  │   2   │ E22-900M22S │       │ │\n\
│ ● │3V3  ●│●             ●│●  │   2   │             │       │ │\n\
│ ● │TX4  ●│●             ●│●  │   |   │             │       │ │\n\
│ ● │RX4  ●│●             ●│●  │   9   │             │       │ │\n\
├───┘      └───●─●─●─●─●───┘   │   0   └─────────────┘       │ │\n\
│⚪                            │   0    ┌───────────┐        │ │\n\
├──────────────────┐           │   M    │           │        │ │\n\
│ ● RX-            │ I2C GROVE │   3    │   SEEED   │        │ │\n\
│ ● RX+            │ ┌───────┐ │   0    │WIO  SX1262│        │ │\n\
│ ● GND  ETHERNET  │ │● ● ● ●│ │   S    │           │        │ │\n\
│ ● TX-            │ ╞═══════╡ │        └───────────┘        │ │\n\
│ ● TX+            │ │● ● ● ●│ │                             │ │\n\
├──────────────────┘ └───────┘ └─────────────────────────────┘ │\n\
│  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ■  │\n\
│⚪●  ●  ●  ●  ●  ●  ♥  ♥  ♥  ●  ●  ♥  ♥  ●  ●  ●  ●  ●  ●  ●⚪│\n\
└──────────────────────────────────────────────────────────────┘\n\
               R              M  M                              \n\
   G           X        G  C  I  O  3           G     S  S  3   \n\
   N           E        N  L  S  S  V           N     C  D  V   \n\
   D           N        D  K  O  I  3           D     L  A  3   \n\
   ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ■   \n\
   ●  ●  ●  ●  ●  ●  ♥  ♥  ♥  ●  ●  ♥  ♥  ●  ●  ●  ●  ●  ●  ●   \n\
   C  B  I  G  G  G  G  S  S     G  R  T  G  R  R  T  G  5  5   \n\
   S  U  R  N  P  N  P  R  R     N  X  X  N  S  X  X  N  V  V   \n\
   0  S  Q  D  I  D  I  A  A     D  2  2  D  T  4  4  D         \n\
      Y        O     O  1  0                                    \n\
♥ Denotes Pro features:                                         \n\
On Community Edition, PWR/DEBUG USB-C replaced by 4pin UART2.   \n\
PWR/DEBUG USB-C also carries serial with no added adapter.      \n\
KILL: add PWR switch or thermal cutoff/fuse & remove resistor."



femtofox_zero="\
         ┌────┐               ┌────┐         \n\
         │⚪   \             /   ⚪│        \n\
         │      \           /      │         \n\
         │       └─────────┘       │         \n\
         │   ┌─────────────────┐   │         \n\
         │  ●│●     USB-C     ●│●  │         \n\
         │  ●│●               ●│●  │         \n\
         │  ●│●               ●│●  │         \n\
         │  ●│●    LUCKFOX    ●│●  │         \n\
         │  ●│●   PICO MINI   ●│●  │         \n\
         │  ●│●               ●│●  │         \n\
         │  ●│●    FOXHOLE    ●│●  │         \n\
         │  ●│●               ●│●  │         \n\
         │  ●│●               ●│●  │         \n\
         │  ●│●               ●│●  │         \n\
         │  ●│●               ●│●  │         \n\
         │   └────●─●─●─●─●────┘   │         \n\
         ├───┐ ┌─────────────┐ ┌───┤         \n\
     GND │ ● │ │   HT-RA62   │ │ ● │ GND     \n\
     3V3 │ ● │ │  ┌───────┐  │ │ ● │ 3V3     \n\
UART4-RX │ ● │ │  │       │  │ │ ● │ I2C SDA \n\
UART4-TX │ ● │ │  │  WIO  │  │ │ ● │ I2C SCL \n\
         ├───┘ │  │SX 1262│  │ └───┤         \n\
         │     │  └───────┘  │   ● │ UNUSED  \n\
         │     └─────────────┘   ● │ GND     \n\
         │⚪         ETH         ⚪│        \n\
         └────────●─●─●─●─●────────┘         \n\
                  R R G T T                  \n\
                  X X N X X                  \n\
                  - + D - +                  "

femtofox_tiny="coming soon"

luckfox="\
                    ┌────┬───────┬────┐                      \n\
       VBUS 3.3-5V ●│●   │ USB-C │   ●│● 1V8 OUT             \n\
               GND ●│●   │       │   ●│● GND                 \n\
        3V3 IN/OUT ●│●   └───────┘   ●│● 145, SARADC-IN1 1.8V\n\
UART2-TX DEBUG, 42 ●│●               ●│● 144, SARADC-IN0 1.8V\n\
UART2-RX DEBUG, 43 ●│●        [BTN]  ●│● 4                   \n\
           CS0, 48 ●│●               ●│● 55, IRQ             \n\
           CLK, 49 ●│●               ●│● 54, BUSY            \n\
          MOSI, 50 ●│●               ●│● 59, I2C SCL         \n\
          MISO, 51 ●│●               ●│● 58, I2C SDA         \n\
      UART4-RX, 52 ●│●               ●│● 57, NRST, UART3-RX  \n\
      UART4-TX, 53 ●│●      ETH      ●│● 56, RXEN, UART3-TX  \n\
                    └──●──●──●──●──●──┘                      \n\
                       R  R  G  T  T                         \n\
                       X  X  N  X  X                         \n\
                       -  +  D  -  +                         \n\
GPIO BANK 0 (3.3v): 4                                        \n\
GPIO BANK 1 (3.3v): 42 43 48 49 50 51 52 53 54 55 56 57 58 59\n\
GPIO BANK 4 (1.8v): 144 145                                  "

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
exit