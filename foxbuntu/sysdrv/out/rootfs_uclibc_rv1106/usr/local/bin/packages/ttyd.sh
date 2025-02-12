#!/bin/bash

### For package maintainer:
# Fill the following fields and choose the options that are in use by this package
# Populate the install, uninstall and upgrade functions
# Remember that this script may be launched in terminal, via web UI or another method, so inputs aren't always possible
# This system supports both interactive and non-interactive installs. For non-interactive installs, $interaction="false". In this cause special instructions to the user should be given as user_message, such as `After installation, edit /opt/software/config.ini`
# Successful operations should `exit 0`, fails should `exit 1`
# Messages to the user (such as configuration instructions, explanatory error messages, etc) should be given as: `echo "user_message: text"`
# Everything following `user_message: ` will be displayed prominently to the user, so it must the last thing echoed

name="ttyd Web Terminal"                 # software name
author="Shuanglei Tao"                   # software author - OPTIONAL
description="ttyd is a simple command-line tool for sharing terminal over the web.\n\nWhen running, ttyd is available at https://$(hostname).local:7681\nttyd is installed and enabled by default on Foxbuntu.\n\nSSL encryption is provided by keys generated during first-boot or during installation. Your browser may give a warning (net::ERR_CERT_AUTHORITY_INVALID) about the self-signed encryption certificate. This is normal. In Chromium (Chrome, Edge) click \"Advanced\" and \"Continue to femtofox.local (unsafe)\""       # software description - OPTIONAL (but strongly recommended!)
URL="https://github.com/tsl0922/ttyd"    # software URL. Can contain multiple URLs - OPTIONAL
options="hxiugedsrNADUOSELGTCIk"            # script options in use by software package. For example, for a package with no service, exclude `edsrS`
launch=""                                # command to launch software, if applicable
service_name="ttyd"                      # the name of the service/s, such as `chrony`. REQUIRED if service options are in use. If multiple services, separate by spaces "service1 service2"
package_name=""                          # apt package name, if applicable. Can be multiple packages separated by spaces, but if at least one is installed the package will show as "installed" even if the others aren't
location="/opt/ttyd"                     # install location REQUIRED if not apt installed. Generally, we use `/opt/software-name`
license="$location/LICENSE"              # file to cat to display license
license_name="MIT"             # license name, such as MIT, GPL3, custom, whatever. short text string
conflicts=""                             # comma delineated plain-text list of packages with which this package conflicts. Blank if none. Use the name as it appears in the $name field of the other package. Extra plaintext is allowed, such as "packageA, packageB, any other software that uses the Meshtastic CLI"

# install script
install() {
  mkdir $location
  if ! wget -P "$location/" https://raw.githubusercontent.com/tsl0922/ttyd/refs/heads/main/LICENSE; then # we are required by ttyd to download and store the license
    echo "user_message: Download failed. Is internet connected?"
    exit 1
  fi
  if ! wget -qO- https://api.github.com/repos/tsl0922/ttyd/releases/latest | grep "browser_download_url" | grep "armhf" | cut -d '"' -f 4 | xargs wget -O $location/ttyd; then
    echo "user_message: Download failed. Is internet connected?"
    exit 1
  fi
  chmod +x /opt/ttyd/ttyd
  echo "Generating SSL keys..."
  generate_keys
  systemctl enable ttyd
  systemctl start ttyd
  echo "user_message: ttyd service started and should be available at https://$(hostname).local:7681"
  exit 0 # should be `exit 1` if operation failed
}

# uninstall script
uninstall() {
  systemctl disable ttyd
  systemctl stop ttyd
  rm -rf $location
  echo "user_message: Binary removed. Service has been disabled but service file retained. SSL encryption keys have been retained."
  exit 0 # should be `exit 1` if operation failed
}

# code that must be run to initialize the installation prior to use, but can only be run from terminal
interactive_init() {
  exit 0 # should be `exit 1` if operation failed
}

# upgrade script
upgrade() {
  systemctl stop ttyd
  if ! wget -qO- https://api.github.com/repos/tsl0922/ttyd/releases/latest | grep "browser_download_url" | grep "armhf" | cut -d '"' -f 4 | xargs wget -O $location/ttyd; then
    echo "user_message: Download failed. Is internet connected?"
    exit 1
  fi
  systemctl start ttyd
  echo "user_message: New binary downloaded and service restarted."
  exit 0 # should be `exit 1` if operation failed
}

# Check if already installed. `exit 0` if yes, `exit 1` if no
check() {
  # the following works for cloned repos, but not for apt installs
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

# custom for this package
generate_keys() {
  openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 -keyout /etc/ssl/private/ttyd.key -out /etc/ssl/certs/ttyd.crt   -subj "/CN=$(hostname)" -addext "subjectAltName=DNS:$(hostname)"
  chmod 600 /etc/ssl/private/ttyd.key
  chmod 644 /etc/ssl/certs/ttyd.crt
  if systemctl is-enabled ttyd &>/dev/null; then # if service is enabled
    systemctl restart ttyd
  fi
}

# custom getopts for ttyd: generate key
if [[ "$1" == "-k" ]]; then
  generate_keys
fi

# parse arguments
source /usr/local/bin/packages/femto_argument_parse.sh "$@"

# extra help for this package
if [[ "$1" == "-h" ]]; then
  echo -e "Additional argument for this package:\n\
-k          Generate SSL keys. Must be first argument."
fi

exit 0