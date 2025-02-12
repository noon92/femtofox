#!/bin/bash

### For package maintainer:
# Fill the following fields and choose the options that are in use by this package
# Populate the install, uninstall and upgrade functions
# Remember that this script may be launched in terminal, via web UI or another method, so inputs aren't really possible
# This system supports both interactive and non-interactive installs. For non-interactive installs, $interactive="false". In this cause special instructions to the user should be given as user_message, such as `After installation, edit /opt/software/config.ini`
# Successful operations should `exit 0`, fails should `exit 1`
# Messages to the user (such as configuration instructions, explanatory error messages, etc) should be given as: `echo "user_message: text"`
# Everything following `user_message: ` will be displayed prominently to the user, so it must the last thing echoed


name="Contact"   # software name
author="pdxlocations"   # software author - OPTIONAL
description="A Text-Based Console UI for Meshtastic Nodes. Formerly called Curses Client.\nAfter install, run \`contact\` to launch."   # software description - OPTIONAL (but strongly recommended!)
URL="https://github.com/pdxlocations/contact/"   # software URL. Can contain multiple URLs - OPTIONAL
options="xiuglNADUOLGTCI"   # script options in use by software package. For example, for a package with no service, exclude `edsrS`
launch="python /opt/contact/main.py --host"   # command to launch software, if applicable
service_name=""   # the name of the service/s, such as `chrony`. REQUIRED if service options are in use. If multiple services, separate by spaces "service1 service2"
location="/opt/contact"   # install location REQUIRED if not apt installed. Generally, we use `/opt/software-name`
license="$location/LICENSE"     # file to cat to display license
license_name="GPL3"             # license name, such as MIT, GPL3, custom, whatever. short text string.
conflicts=""   # comma delineated plain-text list of packages with which this package conflicts. Blank if none. Use the name as it appears in the $name field of the other package. Extra plaintext is allowed, such as "packageA, packageB, any other software that uses the Meshtastic CLI"


if [ $# -eq 0 ]; then
  echo "No arguments provided."
  echo -e "$help"
  exit 1
fi


# install script
install() {
  if ! git clone https://github.com/pdxlocations/contact.git /opt/contact; then
    echo "user_message: Git clone failed. Is internet connected?"
    exit 1
  fi
  pip install -r $location/requirements.txt
  chown -R femto $location #give ownership of installation directory to $user
  git config --global --add safe.directory $location # prevents git error when updating
  echo "Creating \`contact\` shortcut."
  echo -e "#!/bin/bash\n\
export NCURSES_NO_UTF8_ACS=1\n\
export TERM=xterm-256color\n\
export LANG=C.UTF-8\n\
$launch" | sudo tee /usr/local/bin/contact > /dev/null
  chmod +x /usr/local/bin/contact
  echo "user_message: To launch, run \`contact\`."
  exit 0 # should be `exit 1` if the installation failed
}


# uninstall script
uninstall() {
  rm -rf $location
  echo "Removed \`$location\`."
  rm /usr/local/bin/contact
  echo "Removed \`contact\` shortcut."
  echo "user_message: All files removed."
  exit 0 # should be `exit 1` if the installation failed
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
    #echo "Already installed"
    exit 0
  else
    #echo "Not installed"
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