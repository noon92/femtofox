#!/bin/bash

### For package maintainer:
# Fill the following fields and choose the options that are in use by this package
# Populate the install, uninstall and upgrade functions
# Remember that this script may be launched in terminal, via web UI or another method, so inputs aren't always possible
# This system supports both interactive and non-interactive installs. For non-interactive installs, $interactive="false". In this cause special instructions to the user should be given as user_message, such as `After installation, edit /opt/software/config.ini`
# Successful operations should `exit 0`, fails should `exit 1`
# Messages to the user (such as configuration instructions, explanatory error messages, etc) should be given as: `echo "user_message: text"`
# Everything following `user_message: ` will be displayed prominently to the user, so it must the last thing echoed


name="TC²-BBS"   # software name
author="The Comms Channel"   # software author - OPTIONAL
description="The TC²-BBS system integrates with Meshtastic devices. The system allows for message handling, bulletin boards, mail systems, and a channel directory."   # software description - OPTIONAL (but strongly recommended!)
URL="https://github.com/TheCommsChannel/TC2-BBS-mesh"   # software URL. Can contain multiple URLs - OPTIONAL
options="xiugedsrNADUOSELGTCI"   # script options in use by software package. For example, for a package with no service, exclude `edsr`
launch="python /opt/TC2-BBS-mesh/server.py"   # command to launch software, if applicable
service_name="mesh-bbs"   # the name of the service/s, such as `chrony`. REQUIRED if service options are in use. If multiple services, separate by spaces "service1 service2"
location="/opt/TC2-BBS-mesh"   # install location REQUIRED if not apt installed. Generally, we use `/opt/software-name`
license="$location/LICENSE"     # file to cat to display license
license_name="GPL3"             # license name, such as MIT, GPL3, custom, whatever. short text string
conflicts="Meshing Around, other \"full control\" packages"   # comma delineated plain-text list of packages with which this package conflicts. Blank if none. Use the name as it appears in the $name field of the other package. Extra plaintext is allowed, such as "packageA, packageB, any other software that uses the Meshtastic CLI"

# install script
install() {
  if ! git clone https://github.com/TheCommsChannel/TC2-BBS-mesh.git $location; then
    echo "user_message: Git clone failed. Is internet connected?"
    exit 1
  fi
  pip install -r $location/requirements.txt
  chown -R femto $location #give ownership of installation directory to $user
  git config --global --add safe.directory $location # prevents git error when updating

  cd $location
  mv example_config.ini config.ini
  sed -i 's/type = serial/type = tcp/' config.ini
  sed -i 's/^# hostname = 192.168.x.x/hostname = 127.0.0.1/' config.ini
  echo "Installation/upgrade successful! Adding/recreating service."
  sed -i "s/pi/${SUDO_USER:-$(whoami)}/g" $service_name.service
  sed -i "s|/home/${SUDO_USER:-$(whoami)}/|/opt/|g" $service_name.service
  sed -i 's|/opt/TC2-BBS-mesh/venv/bin/python3|python|g' mesh-bbs.service 
  cp $service_name.service /etc/systemd/system/
  systemctl daemon-reload
  systemctl enable $service_name.service
  systemctl restart $service_name.service

  echo "user_message: Installation complete, service launched. To adjust configuration, run \`sudo nano $location/config.ini\`"
  exit 0
}


# uninstall script
uninstall() {
  # stop, disable and remove the service, reload systemctl daemon, remove the installation directory and quit
  systemctl disable $service_name
  systemctl stop $service_name
  rm /etc/systemd/system/$service_name.service
  systemctl daemon-reload
  echo "Disabled and removed \`$service_name\` service."
  rm -rf $location
  echo "Removed \`$location\`."
  echo "user_message: Service removed, all files deleted."
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