#!/bin/bash

### For package maintainer:
# Fill the following fields and choose the options that are in use by this package
# Populate the install, uninstall and upgrade functions
# Remember that this script may be launched in terminal, via web UI or another method, so inputs aren't always possible
# This system supports both interactive and non-interactive installs. For non-interactive installs, $interaction="false". In this cause special instructions to the user should be given as user_message, such as `After installation, edit /opt/software/config.ini`
# Successful operations should `exit 0`, fails should `exit 1`
# Messages to the user (such as configuration instructions, explanatory error messages, etc) should be given as: `echo "user_message: text"`
# Everything following `user_message: ` will be displayed prominently to the user, so it must the last thing echoed

user_message="To connect to network share, enter \`\\\\femtofox\\home\` in Windows, \`smb://$(hostname)/home\` in MacOS or \`smbclient //$(hostname)/femto -U femto\` in Linux. Default configuration shares /home/femto. Edit \`/etc/samba/smb.conf\` to add other shares.\n\nTroubleshooting: if Windows refuses to connect after succeeding previously, hit [win]+R and enter \`net use * /delete\`."
init_instructions="To enable file sharing, run \`Initialize\` in the femto-config Samba menu to set a Samba password."

name="Samba File Sharing"   # software name
author="Software Freedom Conservancy"   # software author - OPTIONAL
description="Femtofox comes with Samba preinstalled but disabled. $init_instructions\n\n$user_message"   # software description - OPTIONAL (but strongly recommended!)
URL="https://www.samba.org/"   # software URL. Can contain multiple URLs - OPTIONAL
options="xiuagedsrNADUOSEGTPCI"   # script options in use by software package. For example, for a package with no service, exclude `edsr`
launch=""   # command to launch software, if applicable
service_name="smbd nmbd"   # the name of the service/s, such as `chrony`. REQUIRED if service options are in use. If multiple services, separate by spaces "service1 service2"
location=""   # install location REQUIRED if not apt installed. Generally, we use `/opt/software-name`
license="/usr/share/doc/samba/copyright"     # file to cat to display license
license_name="GPL3"             # license name, such as MIT, GPL3, custom, whatever. short text string
package_name="samba"   # apt package name, if applicable
conflicts=""   # comma delineated plain-text list of packages with which this package conflicts. Blank if none. Use the name as it appears in the $name field of the other package. Extra plaintext is allowed, such as "packageA, packageB, any other software that uses the Meshtastic CLI"

# install script
install() {
  echo "apt update can take a long while..."
 # DEBIAN_FRONTEND=noninteractive apt-get update -y 2>&1 | tee /dev/tty | grep -q "Err" && { echo "user_message: apt update failed. Is internet connected?"; exit 1; }
 # DEBIAN_FRONTEND=noninteractive apt-get install $package_name -y 2>&1 | tee /dev/tty | grep -q "Err" && { echo "user_message: apt install failed. Is internet connected?"; exit 1; }
  if [ "$interactive" = "true" ]; then # interactive install
    interactive_init
  else # noninteractive installation (such as web-UI)
    echo -e "user_message: IMPORTANT: $init_instructions\n\n$user_message"
    exit 0 # should be `exit 1` if operation failed
  fi
}

# uninstall script
uninstall() {
  DEBIAN_FRONTEND=noninteractive apt remove -y $package_name 2>&1 | tee /dev/tty
  echo "user_message: Some files may remain on system. To remove, run \`sudo apt remove --purge $package_name -y\` and \`sudo apt autoremove -y\`."
  exit 0 # should be `exit 1` if operation failed
}

# code that must be run to initialize the installation prior to use, but can only be run from terminal
interactive_init() {
  echo -e "\nSet user \`Femto\` login password:"
  smbpasswd -a femto
  /usr/local/bin/packages/samba.sh -e
  /usr/local/bin/packages/samba.sh -r
  echo -e "user_message: Samba initialized, and service enabled and started. $user_message"
  exit 0
}

# upgrade script
upgrade() {
  echo "apt update can take a long while..."
  DEBIAN_FRONTEND=noninteractive apt-get update -y 2>&1 | tee /dev/tty | grep -q "Err" && { echo "user_message: apt update failed. Is internet connected?"; exit 1; }
  DEBIAN_FRONTEND=noninteractive apt upgrade -y $package_name 2>&1 | tee /dev/tty | grep -q "Err" && { echo "user_message: apt upgrade failed. Is internet connected?"; exit 1; }
  exit 0 # should be `exit 1` if operation failed
}

# Check if already installed. `exit 0` if yes, `exit 1` if no
check() {
if dpkg-query -W -f='${Status}' $package_name 2>/dev/null | grep -q "install ok installed"; then
  exit 0
else
  exit 1
fi
}

# display license
license() {
  echo -e "Contents of $license:\n\n   $([[ -f "$license" ]] && awk -v max=2000 -v file="$license" '{ len += length($0) + 1; if (len <= max) print; else if (!cut) { cut=1; printf "%s...\n\nFile truncated, see %s for complete license.", substr($0, 1, max - len + length($0)), file; exit } }' "$license")"
}

# parse arguments
source /usr/local/bin/packages/femto_argument_parse.sh "$@"

exit 0