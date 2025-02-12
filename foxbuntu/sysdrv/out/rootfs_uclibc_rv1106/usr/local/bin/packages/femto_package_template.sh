#!/bin/bash
### For package maintainer:
# Fill the following fields and choose the options that are in use by this package
# Populate the install, uninstall and upgrade functions
# Remember that this script may be launched in terminal, via web UI or another method, so inputs aren't always possible
# This system supports both interactive and non-interactive installs. For non-interactive installs, $interaction="false". In this cause special instructions to the user should be given as user_message, such as `After installation, edit /opt/software/config.ini`
# Successful operations should `exit 0`, fails should `exit 1`
# Messages to the user (such as configuration instructions, explanatory error messages, etc) should be given as: `echo "user_message: text"`
# Everything following `user_message: ` will be displayed prominently to the user, so it must the last thing echoed

name="name"                     # software name
author="author"                 # software author - OPTIONAL
description="description"       # software description - OPTIONAL (but strongly recommended!)
URL="URL"                       # software URL. Can contain multiple URLs - OPTIONAL
options="hxiuagedsrlNADUOSELGTPCI"  # script options in use by software package. For example, for a package with no service, exclude `edsrS`
launch="/opt/package/run.sh"    # command to launch software, if applicable
license="/opt/package/license"  # file to cat to display license
service_name="service_name"     # the name of the service/s, such as `chrony`. REQUIRED if service options are in use. If multiple services, separate by spaces "service1 service2"
package_name="apt_package"      # apt package name, if applicable. Can be multiple packages separated by spaces, but if at least one is installed the package will show as "installed" even if the others aren't
location="/opt/location"        # install location REQUIRED if not apt installed. Generally, we use `/opt/software-name`
license="$location/LICENSE"     # file to cat to display license
license_name="GPL3"             # license name, such as MIT, GPL3, custom, whatever. short text string
conflicts="package1, package2"  # comma delineated plain-text list of packages with which this package conflicts. Blank if none. Use the name as it appears in the $name field of the other package. Extra plaintext is allowed, such as "packageA, packageB, any other software that uses the Meshtastic CLI"

# install script
install() {
  # for apt packages, this method allows onscreen output during install:
  # DEBIAN_FRONTEND=noninteractive apt-get update -y 2>&1 | tee /dev/tty || { echo "user_message: apt update failed. Is internet connected?"; exit 1; }
  # DEBIAN_FRONTEND=noninteractive apt-get install $package_name -y 2>&1 | tee /dev/tty || { echo "user_message: apt install failed. Is internet connected?"; exit 1; }
  echo "user_message: Exit message to user, displayed prominently in post-install"
  exit 0 # should be `exit 1` if operation failed
}

# uninstall script
uninstall() {
  echo "user_message: Exit message to user, displayed prominently in post-install"
  exit 0 # should be `exit 1` if operation failed
}

# code that must be run to initialize the installation prior to use, but can only be run from terminal
interactive_init() {
  exit 0 # should be `exit 1` if operation failed
}

# upgrade script
upgrade() {
  echo "user_message: Exit message to user, displayed prominently in post-install"
  exit 0 # should be `exit 1` if operation failed
}

# Check if already installed. `exit 0` if yes, `exit 1` if no
check() {
  ## the following works for cloned repos, but not for apt installs
  # if [ -d "$location" ]; then
  #   exit 0
  # else
  #   exit 1
  # fi

  ## this works for apt packages
  # if dpkg-query -W -f='${Status}' $package_name 2>/dev/null | grep -q "install ok installed"; then
  #   exit 0
  # else
  #   exit 1
  # fi
}

# display license - limit to 2000 chars
license() {
  echo -e "Contents of $license:\n\n   $([[ -f "$license" ]] && awk -v max=2000 -v file="$license" '{ len += length($0) + 1; if (len <= max) print; else if (!cut) { cut=1; printf "%s...\n\nFile truncated, see %s for complete license.", substr($0, 1, max - len + length($0)), file; exit } }' "$license")"
}

## custom getopts example for this package
# if [[ "$1" == "-k" ]]; then
#   generate_keys
# fi

# parse arguments
source /usr/local/bin/packages/femto_argument_parse.sh "$@"

# extra help example for this package
# if [[ "$1" == "-h" ]]; then
#   echo -e "Additional argument for this package:\n\
# -k          Generate SSL keys. Must be first argument."
# fi

exit 0