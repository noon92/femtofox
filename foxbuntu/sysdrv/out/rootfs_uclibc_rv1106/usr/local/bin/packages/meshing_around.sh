#!/bin/bash

### For package maintainer:
# Fill the following fields and choose the options that are in use by this package
# Populate the install, uninstall and upgrade functions
# Remember that this script may be launched in terminal, via web UI or another method, so inputs aren't always possible
# This system supports both interactive and non-interactive installs. For non-interactive installs, $interactive="false". In this cause special instructions to the user should be given as user_message, such as `After installation, edit /opt/software/config.ini`
# Successful operations should `exit 0`, fails should `exit 1`
# Messages to the user (such as configuration instructions, explanatory error messages, etc) should be given as: `echo "user_message: text"`
# Everything following `user_message: ` will be displayed prominently to the user, so it must the last thing echoed

name="Meshing Around" # software name
author="Spud" # software author - OPTIONAL
description="Meshing Around is a feature-rich bot designed to enhance your Meshtastic network experience with a variety of powerful tools and fun features. Connectivity and utility through text-based message delivery. Whether you're looking to perform network tests, send messages, or even play games, mesh_bot.py has you covered." # software description - OPTIONAL (but strongly recommended!)
URL="https://github.com/SpudGunMan/meshing-around" # software URL. Can contain multiple URLs - OPTIONAL
options="xiugedsrNADUOSELGTCI"   # script options in use by software package. For example, for a package with no service, exclude `edsr`
launch=""   # command to launch software, if applicable
service_name="mesh_bot" # the name of the service, such as `chrony`. REQUIRED if service options are in use. If multiple services, separate by spaces "service1 service2"
location="/opt/meshing-around" # install location REQUIRED if not apt installed. Generally, we use `/opt/software-name`
license="$location/LICENSE"     # file to cat to display license
license_name="GPL3"             # license name, such as MIT, GPL3, custom, whatever. short text string
conflicts="TC²-BBS, any other \"full control\" style bots" # comma delineated plain-text list of packages with which this package conflicts. Use the name as it appears in the $name field of the other package. Extra plaintext is allowed, such as "packageA, packageB, any other software that uses the Meshtastic CLI"

# install script
install() {
  if ! git clone https://github.com/spudgunman/meshing-around $location; then
    echo "user_message: Git clone failed. Is internet connected?"
    exit 1
  fi
  pip install -r $location/requirements.txt
  if [ "$interactive" = "true" ]; then #interactive install
    "$location/install.sh" | tee /dev/tty
    echo "user_message: To change settings, run \`sudo nano $location/config.ini\`"
    exit 0
  else
    echo "user_message: IMPORTANT: To complete installation, run \`sudo $location/install.sh\`\nTo change settings, run \`sudo nano $location/config.ini\`"
    exit 0
  fi
}

# uninstall script
uninstall() {
  # stop, disable and remove the service, reload systemctl daemon, remove the installation directory and quit
  for service in $service_name; do
    systemctl stop $service
    systemctl disable $service
    rm "/etc/systemd/system/$service.service"
  done
  systemctl daemon-reload
  systemctl reset-failed
  gpasswd -d meshbot dialout
  gpasswd -d meshbot tty
  gpasswd -d meshbot bluetooth
  groupdel meshbot
  userdel meshbot
  rm -rf /opt/meshing-around
  rm -rf $location
  echo "user_message: Service removed, all files deleted."
  exit 0
}

# code that must be run to initialize the installation prior to use, but can only be run from terminal
interactive_init() {
  exit 0
}

#upgrade script
upgrade() {
  cd $location
  if ! git pull; then
    echo "user_message: Git pull failed. Is internet connected?"
    exit 1
  fi
  exit 0
}

# Check if already installed. `exit 0` if yes, `exit 1` if no
check() {
  #the following works for cloned repos, but not for apt installs
  if [ -d "$location" ]; then
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