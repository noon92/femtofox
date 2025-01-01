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

anykey="echo -e \"\nPress any key to continue...\n\" && read -n 1 -s -r"

femtofox_short_license="\
Femtofox and Foxbuntu are published under CC BY-NC-ND - noncommercial.\n\
For more information, visit us at www.femtofox.com.\n\
\n\
Summary:\n\
You can share Femtofox and Foxbuntu or make modifications, but can't sell it except by arrangement (license) with us.\n\
In this context, Foxbuntu refers to the modifications to Ubuntu made as part of the Femtofox project.\n\
\n\
Boilerplate:\n\
Attribution — You must give appropriate credit, provide a link to the license, and indicate if changes were made.\n\
You may do so in any reasonable manner, but not in any way that suggests the licensor endorses you or your use.\n\
NonCommercial — You may not use the material for commercial purposes.\n\
NoDerivatives — If you remix, transform, or build upon the material, you may not distribute the modified material (for commercial purposes).\n\
\n\
Contact us to license Femtofox."

meshtastic_license="\
Meshtastic is a registered trademark of Meshtastic LLC. Meshtastic software components are released under various licenses, see GitHub for details. No warranty is provided - use at your own risk."

luckfox_license="Luckfox and Luckfox Pico Mini are property of Luckfox Technology. Femtofox does not represent Luckfox Technology in any way, shape or form. Visit their website at https://www.luckfox.com/."

ubuntu_license="Ubuntu is a trademark of Canonical. Femtofox does not represent Ubuntu or Canonical in any way, shape or form. Find Ubuntu's license information on their site, https://ubuntu.com/legal. Licenses are also available in \`/usr/share/common-licenses\`."

# Parse options
while getopts ":hafFmlu" opt; do
  case ${opt} in
    h) # Option -h (help)
      echo -e "$help"
      ;;
    a)  # Option -a (about)
      echo "The Luckfox Pico Mini is a compact and power efficient Linux capable board, capable of running Ubuntu. Femtofox is an expansion of the Luckfox's capabilities, combining a customized Ubuntu image with a custom PCB, integrating it with a LoRa radio to create a power efficient, cheap and small Meshtastic Linux node."
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
    \?)  # Invalid option
      echo "Invalid option: -$OPTARG"
      echo -e "$help"
      exit 1
      ;;
  esac
done

# if no arguments, show all licenses
if [ $# -eq 0 ]; then
  echo "$femtofox_short_license"
  eval $anykey
  echo "$(cat /usr/share/doc/femtofox/long_license)"
  eval $anykey
  echo "$meshtastic_license"
  eval $anykey
  echo "$luckfox_license"
  eval $anykey
  eval "$ubuntu_license"
  eval $anykey
fi