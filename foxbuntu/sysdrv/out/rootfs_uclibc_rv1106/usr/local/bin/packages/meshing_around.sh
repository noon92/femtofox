#!/bin/bash
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Try \`sudo femto-meshtasticd-config\`."
   exit 1
fi

args="$@"
help=$(cat <<EOF
Arguments:
    Actions:
-h          This message
-i          Install
-u          Uninstall
-g          Upgrade
-e          Enable service, if applicable
-d          Disable service, if applicable
-s          Stop service
-r          Start/Restart
    Information:
-N          Get name
-A          Get author
-D          Get description
-U          Get URL
-O          Get options supported by this script
-S          Get service status
-L          Install location
-C          Conflicts
-I          Check if installed. Returns an error if already installed
EOF
)

### For package maintainer:
# Fill the following fields and choose the options that are in use by this package
# Populate the install, uninstall and upgrade functions
# Remember that this script may be launched in terminal, via web UI or another method, so inputs aren't really possible
# Arguments to the script are stored in $args
# For install/uninstall/upgrade, output should be given as echo or printf
# Successful operations should `exit 0`, fails should `exit 1`

name="Meshing Around" # software name
author="Spud" # software author - OPTIONAL
description="Meshing Around is a feature-rich bot designed to enhance your Meshtastic network experience with a variety of powerful tools and fun features. Connectivity and utility through text-based message delivery. Whether you're looking to perform network tests, send messages, or even play games, mesh_bot.py has you covered." # software description - OPTIONAL (but strongly recommended!)
URL="https://github.com/SpudGunMan/meshing-around" # software URL. Can contain multiple URLs - OPTIONAL
options="iugedsrNADUOSLCI" # script options in use by software package. For example, for a package with no service, exclude `edsr`
service_name="mesh_bot pong_bot" # the name of the service, such as `chrony`. REQUIRED if service options are in use. If multiple services, separate by spaces "service1 service2"
location="/opt/meshing-around" # install location REQUIRED if not apt installed. Generally, we use `/opt/software-name`
conflicts="TC²-BBS, any other \"full control\" style bots" # comma delineated plain-text list of packages with which this package conflicts. Use the name as it appears in the $name field of the other package. Extra plaintext is allowed, such as "packageA, packageB, any other software that uses the Meshtastic CLI"

if [ $# -eq 0 ]; then
  echo "No arguments provided."
  echo -e "$help"
  exit 1
fi


install() {
  failedInstall=false
      #check if /opt/meshing-around exists if not git clone
  if [ ! -d /opt/meshing-around ]; then
    dialog --title "$software" --yesno "\nInstallation requires internet connection.\n\nLearn more at \nIf software is already present, will attempt to update.\n\nInstall?" 0 0
    if [ $? -eq 0 ]; then #unless cancel/no
      if ! git clone https://github.com/spudgunman/meshing-around /opt/meshing-around; then
        dialog --title "$software" --msgbox "\nCloning of Meshing Around git repo failed.\nCheck internet connectivity." 10 60
        failedInstall=true
      fi
    fi
  else
    # /opt/meshing-around exists, check for updates
    cd /opt/meshing-around
    if ! sudo git pull; then
      dialog --title "$software" --msgbox "\nFailed to update Meshing Around.\nCheck internet connectivity." 10 60
      failedInstall=true
    fi
    # check if /opt/meshing-around/data has any .pkl files if so assume it's installed
    if [ -n "$(find /opt/meshing-around/data -name '*.pkl' -print -quit)" ]; then
      # todo uninstall?
      dialog --title "$software" --yesno "Meshing Around appears installed and updated, do you want to edit the config file? (press ctl+o,enter to save, ctl+x to exit nano)" 0 0
      if [ $? -eq 0 ]; then #unless cancel/no
        sudo nano /opt/meshing-around/config.ini
      fi
      # set flag to not run install.sh
      installed=true
      echo "Restarting services..."
      sudo systemctl restart mesh_bot
      sudo systemctl restart pong_bot
    fi
  fi
  # if /opt/meshing-around exists
  if [ -f /opt/meshing-around/install.sh ] && [ "$installed" != true ] && [ "$failedInstall" != true ]; then
    # ask what type of bot mesh or pong
    dialog --title "$software" --yesno "Meshing Around can be configured to run as mesh_bot or pong_bot.\n\nRun mesh_bot?" 0 0
    if [ $? -eq 0 ]; then #unless cancel/no
      /opt/meshing-around/install.sh mesh
      dialog --title "$software" --yesno "Would you like to edit the config file? (press ctl+s save, ctl+x to exit editor)" 0 0
      if [ $? -eq 0 ]; then #unless cancel/no
        sudo nano /opt/meshing-around/config.ini
        echo "Restarting services..."
        sudo systemctl restart mesh_bot
      fi
      # finished. display the contents of install_notes.txt
      dialog --title "$software" --textbox /opt/meshing-around/install_notes.txt 20 60
    else
      /opt/meshing-around/install.sh pong
      dialog --title "$software" --yesno "Would you like to edit the config file? (press ctl+s save, ctl+x to exit editor)" 0 0
      if [ $? -eq 0 ]; then #unless cancel/no
        sudo nano /opt/meshing-around/config.ini
        echo "Restarting services..."
        sudo systemctl restart pong_bot
      fi
      # finished. display the contents of install_notes.txt
      dialog --title "$software" --textbox /opt/meshing-around/install_notes.txt 20 60
    fi
  fi
}


uninstall() {
echo placeholder
}


upgrade() {
echo placeholder
}

# Check if already installed. `exit 1` if yes, `exit 0` if no
check() {
  if [ -d "$location" ]; then
    #echo "Already installed"
    exit 1
  else
    #echo "Not installed"
    exit 0
  fi
}

while getopts ":h$options" opt; do
  case ${opt} in
    h) # Option -h (help)
      echo -e "$help"
      ;;
    i) # Option -i (install)
      install
      ;;
    u) # Option -u (uninstall)
      uninstall
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
    N) echo -e $name ;;
    A) echo -e $author ;;
    D) echo -e $description ;;
    U) echo -e $URL ;;
    O) echo -e $options ;;
    S) # Option -S (Get service status)
      systemctl status $service_name
    ;;
    L) echo -e $location ;;
    C) echo -e $conflicts ;;
    I) # Option -I (Check if already installed)
      check
    ;;
  esac
done

exit 0