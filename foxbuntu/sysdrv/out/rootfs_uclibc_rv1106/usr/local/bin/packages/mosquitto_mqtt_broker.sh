#!/bin/bash

### For package maintainer:
# Fill the following fields and choose the options that are in use by this package
# Populate the install, uninstall and upgrade functions
# Remember that this script may be launched in terminal, via web UI or another method, so inputs aren't always possible
# This system supports both interactive and non-interactive installs. For non-interactive installs, $interaction="false". In this cause special instructions to the user should be given as user_message, such as `After installation, edit /opt/software/config.ini`
# Successful operations should `exit 0`, fails should `exit 1`
# Messages to the user (such as configuration instructions, explanatory error messages, etc) should be given as: `echo "user_message: text"`
# Everything following `user_message: ` will be displayed prominently to the user, so it must the last thing echoed


name="Mosquitto MQTT Broker"   # software name
author="Eclipse Foundation"   # software author - OPTIONAL
description="Eclipse Mosquitto is an open source (EPL/EDL licensed) message broker that implements the MQTT protocol versions 5.0, 3.1.1 and 3.1. Mosquitto is lightweight and is suitable for use on all devices from low power single board computers to full servers.\n\nThe MQTT protocol provides a lightweight method of carrying out messaging using a publish/subscribe model. This makes it suitable for Internet of Things messaging such as with low power sensors or mobile devices such as phones, embedded computers or microcontrollers.\n\nThe Mosquitto project also provides a C library for implementing MQTT clients, and the very popular mosquitto_pub and mosquitto_sub command line MQTT clients.\n\nMosquitto is part of the Eclipse Foundation, and is an iot.eclipse.org project. The development is driven by Cedalo."   # software description - OPTIONAL (but strongly recommended!)
URL="https://mosquitto.org/"   # software URL. Can contain multiple URLs - OPTIONAL
options="xiugedsrNADUOSEGTPCI"   # script options in use by software package. For example, for a package with no service, exclude `edsr`
launch=""   # command to launch software, if applicable
service_name="mosquitto"   # the name of the service/s, such as `chrony`. REQUIRED if service options are in use. If multiple services, separate by spaces "service1 service2"
package_name="mosquitto"   # apt package name, if applicable
location=""   # install location REQUIRED if not apt installed. Generally, we use `/opt/software-name`
license="usr/share/doc/mosquitto/copyright"     # file to cat to display license
license_name="EPL/EDL"             # license name, such as MIT, GPL3, custom, whatever. short text string
conflicts=""   # comma delineated plain-text list of packages with which this package conflicts. Blank if none. Use the name as it appears in the $name field of the other package. Extra plaintext is allowed, such as "packageA, packageB, any other software that uses the Meshtastic CLI"

# install script
install() {
  echo "apt update can take a long while..."
  DEBIAN_FRONTEND=noninteractive apt-get update -y 2>&1 | tee /dev/tty | grep -q "Err" && { echo "user_message: apt update failed. Is internet connected?"; exit 1; }
  DEBIAN_FRONTEND=noninteractive apt-get install $package_name -y 2>&1 | tee /dev/tty | grep -q "Err" && { echo "user_message: apt install failed. Is internet connected?"; exit 1; }
  echo "user_message: Installation requires more setup. For a guide, see https://docs.vultr.com/how-to-install-mosquitto-mqtt-broker-on-ubuntu-24-04"
  exit 0 # should be `exit 1` if operation failed
}


# uninstall script
uninstall() {
  DEBIAN_FRONTEND=noninteractive apt remove -y $package_name 2>&1 | tee /dev/tty
  /usr/local/bin/mosquitto_mqtt_broker.sh -s # stop service
  /usr/local/bin/mosquitto_mqtt_broker.sh -d # disable service
  echo "user_message: Some files may remain on system. To remove, run \`sudo apt remove --purge mosquitto -y\` and \`sudo apt autoremove -y\`."
  exit 0 # should be `exit 1` if operation failed
}


#upgrade script
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