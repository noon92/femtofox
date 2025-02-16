#!/bin/bash
help=$(cat <<EOF
Options are:
-h             This message
-a             About Femtofox
-f             Femtofox short-form license
-F             Femtofox long-form license
-m             Meshtastic licensing
-l             Luckfox license
-u             Ubuntu licenses
EOF
)

pause() {
  echo -e "\nPress any key to continue..."
  read -n 1 -s -r
}

femtofox_short_license="\
Femtofox is comprised of two projects, with two different licenses:\n\
1. Femtofox - the hardware, which is licensed \"CC BY-NC-ND - noncommercial\". Summary: you may copy and share and modify the hardware files, but cannot sell them without license from Femtofox, and must give attribution to Femtofox.\n\
2. Foxbuntu - refers to the modifications to Ubuntu made as part of the Femtofox project, which is licensed GNU GPLv3. Summary: you may use, modify and distribute (including for commercial purposes) Foxbuntu, but must give attribution to Femtofox and distribute this license with your project. Any modified version must remain open source.\n\
\n\
For more information, visit us at www.femtofox.com.\n\
\n\
View the long licenses for more information.\n\
Contact us to license Femtofox."

meshtastic_license="\
The Meshtastic firmware is licensed GPL3.\n\
\n\
Meshtastic is a registered trademark of Meshtastic LLC. Meshtastic software components are released under various licenses, see GitHub for details. No warranty is provided - use at your own risk.\n\
\n\
Some of the verbiage in the help-texts in the menus is sourced from the Meshtastic website, also licensed GPL3.\n\
\n\
For more information about Meshtastic, visit https://www.meshtastic.org\
"

luckfox_license="Luckfox and Luckfox Pico Mini are property of Luckfox Technology. Femtofox does not represent Luckfox Technology in any way, shape or form. Visit their website at https://www.luckfox.com/."

ubuntu_license="Ubuntu is a trademark of Canonical. Femtofox does not represent Ubuntu or Canonical in any way, shape or form. Find Ubuntu's license information on their site, https://ubuntu.com/legal. Licenses are also available in \`/usr/share/common-licenses\`."

# Parse options
while getopts ":hafFmlu" opt; do
  case ${opt} in
    h) # Option -h (help)
      echo -e "$help"
      ;;
    a)  # Option -a (about)
      echo "Femtofox is a Linux-based mesh development platform - a Raspberry Pi sized computer with onboard LoRa radio, capable of being run with only 0.3w, making it ideal for solar powered nodes.\n\
\n\
The Luckfox Pico Mini is the postage stamp sized heart of the Femtofox - a compact and power efficient Linux board, running a customized version of Ubuntu. Femtofox is an expansion of the Luckfox’s capabilities, utilizing a custom PCB with a 30db LoRa radio (over 6x the transmit power of a RAK Wisblock or Heltec V3) to create a power efficient, tiny and highly capable Meshtastic Linux node.\n\
\n\
https://www.femtofox.com\n\
\n\
                      .=*#%@@@%%@@%%#+:.                \n\
                .:+%%*-.           .:=#@#-.            \n\
              .#@*.                     .-@@-          \n\
            .-%#-::                  .=*%-. .+%+.       \n\
          :##:+@@@@@+:.        ..-#@@@@@*.   .+@=.     \n\
        .+@-.=@@@@@@@@@=     .=@@@@@@#:%%:     .#%.    \n\
        .##. :@#..-*@@@@@%+++*#@@@@@+.  :@-#@*-. .+%-   \n\
      .%#. .*@=.   .-@@@@@@@@@@@%-     .#-*@@@@*..-@:  \n\
      .*%.  .%%:   :#@@@@@@@@@@@@@@#:.  .+=*@@@@@@+.+@: \n\
      :%:   .%+  :#@@@@@@@@@@@@@@@%*=:   ==#@@@@@@@%:##.\n\
      **.   .#.  ....=@@@@@@@@@@=..      --@@@@@@@@@@.%-\n\
      %=.  -+-        .-@@@@@@*.         .+@@@@@@@@@@@*#\n\
      @- .#@#.   ...    .#@@@-     ...     *@@@@@@@@@@%#\n\
      @- :%@= .-%@@@#-   .%@+.  .+%@@@#:   :@@@@@@@@@@%:\n\
      %=..=@*.  .*@@@@#:  -%.  :@@@@@=.   .%@@@@@@@@@@@:\n\
      *+.+.:%-     .+@@#   :  .%@%-      -%@@@@@@@@@@@@-\n\
      :=.+#..*#.     .-%      -#.      :#@@@@@@@@@@@@@%:\n\
      .:.:%@*..*#:.    .+%@%=+-.   ..=%@@@@@@@@@@@@@@@#.\n\
        .:@@@%=.:+%*-.:@@@@@@*. .=%@@@@@@@@@@@@@@@@@@- \n\
          .+@@@@@#=-:.. :=++=+#@@@@@@@@@@@@@@@@@@@@@-  \n\
        :.   -%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@-   \n\
        .-%*-. ..:=+#%@@@@@@@@@@@@@@@@@@@@@@@@@@@*.    \n\
          .+%#%@@%%###%@@@@@@@@@@@@@@@@@@@@@@@@#:.     \n\
            .:##-#@@@@@@@@@@@@@@@@@@@@@@@@@@@=.        \n\
                :=*+--=+*######**#@@@@@@@*-.           \n\
               .:+%#****#@@@%%#*-.                     "
      ;;
    f)  # Option -f (Femtofox short-form license)
      echo "$femtofox_short_license"
      ;;
    F)  # Option -F (Femtofox long-form license)
      echo "$(cat /usr/share/doc/femtofox/long_license)"
      ;;
    m)  # Option -m (Meshtastic licensing)
      echo "$meshtastic_license"
      ;;
    l) # Option -l (Luckfox license)
      echo "$luckfox_license"
      ;;
    u) # Option -u (Ubuntu licenses)
      echo "$ubuntu_license"
      ;;
    \?)  # Invalid option)
      echo "Invalid option: -$OPTARG"
      echo -e "$help"
      exit 1
      ;;
  esac
done

# if no arguments, show all licenses
if [ $# -eq 0 ]; then
  echo "$femtofox_short_license"
  pause
  echo "$(cat /usr/share/doc/femtofox/long_license)"
  pause
  echo "$meshtastic_license"
  pause
  echo "$luckfox_license"
  pause
  eval "$ubuntu_license"
  pause
fi