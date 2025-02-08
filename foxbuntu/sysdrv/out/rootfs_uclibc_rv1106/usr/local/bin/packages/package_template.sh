#!/bin/bash
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Try \`sudo\`."
   exit 1
fi
if [ $# -eq 0 ]; then
  echo "No arguments provided."
  echo -e "$help"
  exit 1
fi

args="$@" # arguments to this script
interactive="true"
help=$(cat <<EOF
Arguments:
-h          This message
    Environment - must be first argument:
-x          User UI is not terminal (script interaction unavailable)
    Actions:
-i          Install
-u          Uninstall
-a          Interactive initialization script: code that must be run to initialize the installation prior to use, but can only be run from terminal
-g          Upgrade
-e          Enable service, if applicable
-d          Disable service, if applicable
-s          Stop service
-r          Start/Restart
-l          Command to run software
    Information:
-N          Get name
-A          Get author
-D          Get description
-U          Get URL
-O          Get options supported by this script
-S          Get service status
-L          Get install location
-P          Get package name
-C          Get Conflicts
-I          Check if installed. Returns an error if not installed
EOF
)

### For package maintainer:
# Fill the following fields and choose the options that are in use by this package
# Populate the install, uninstall and upgrade functions
# Remember that this script may be launched in terminal, via web UI or another method, so inputs aren't really possible
# Arguments to the script are stored in $args
# This system supports both interactive and non-interactive installs. For non-interactive installs, $interaction="false". In this cause special instructions to the user should be given as user_message, such as `After installation, edit /opt/software/config.ini`
# Successful operations should `exit 0`, fails should `exit 1`
# Messages to the user (such as configuration instructions, explanatory error messages, etc) should be given as: `echo "user_message: text"`
# Everything following `user_message: ` will be displayed prominently to the user, so it must the last thing echoed

name="name"                     # software name
author="author"                 # software author - OPTIONAL
description="description"       # software description - OPTIONAL (but strongly recommended!)
URL="URL"                       # software URL. Can contain multiple URLs - OPTIONAL
options="hxiuagedsrlNADUOSLPCI"  # script options in use by software package. For example, for a package with no service, exclude `edsrS`
launch="/opt/package/run.sh"    # command to launch software, if applicable
service_name="service_name"     # the name of the service/s, such as `chrony`. REQUIRED if service options are in use. If multiple services, separate by spaces "service1 service2"
package_name="apt_package"      # apt package name, if applicable. Can be multiple packages separated by spaces, but if at least one is installed the package will show as "installed" even if the others aren't
location="/opt/location"        # install location REQUIRED if not apt installed. Generally, we use `/opt/software-name`
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
  # the following works for cloned repos, but not for apt installs
  if [ -d "$location" ]; then
    exit 0
  else
    exit 1
  fi

  # this works for apt packages
  if dpkg-query -W -f='${Status}' $package_name 2>/dev/null | grep -q "install ok installed"; then
    exit 0
  else
    exit 1
  fi
}

while getopts ":$options" opt; do
  case ${opt} in
    h) # Option -h (help)
      echo -e "$help"
      ;;
    x) # Option -x (no user interaction available)
      interaction="false"
      ;;
    i) # Option -i (install)
      install
      ;;
    u) # Option -u (uninstall)
      uninstall
      ;;
    a) # Option -a (interactive initialization)
      interactive_init
      ;;
    g) # Option -g (upgrade)
      upgrade
      ;;
    e) # Option -e (Enable service, if applicable)
      systemctl enable $service_name
      ;;
    d) # Option -d (Disable service, if applicable)
      systemctl disable $service_name
      ;;
    s) # Option -s (Stop service)
      systemctl stop $service_name
      ;;
    r) # Option -r (Start/Restart)
      systemctl restart $service_name
      ;;
    l) # Option -l (Run software)
      echo "Launching $name..."
      sudo -u ${SUDO_USER:-$(whoami)} $launch 
      ;;
    N) echo -e $name ;;
    A) echo -e $author ;;
    D) echo $description ;;
    U) echo -e $URL ;;
    O) echo -e $options ;;
    S) # Option -S (Get service status)
      systemctl status $service_name
    ;;
    L) echo -e $location ;;
    P) echo -e $package_name ;;
    C) echo -e $conflicts ;;
    I) # Option -I (Check if already installed)
      check
    ;;
  esac
done

exit 0