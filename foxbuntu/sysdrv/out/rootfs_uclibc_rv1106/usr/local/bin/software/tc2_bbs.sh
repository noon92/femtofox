#!/bin/bash
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Try \`sudo femto-meshtasticd-config\`."
   exit 1
fi

help=$(cat <<EOF
Options are:
-h          This message
-i          Install
-u          Uninstall
-g          Upgrade
-e          Enable service, if applicable
-d          Disable service, if applicable
-s          Stop service
-r          Start/Restart
-N          Get name
-D          Get description
-U          Get URL
-O          Get options supported by this script
EOF
)

name="Tc²-BBS"
author="The Comms Channel"
description="The TC²-BBS system integrates with Meshtastic devices. The system allows for message handling, bulletin boards, mail systems, and a channel directory."
URL="https://github.com/TheCommsChannel/TC2-BBS-mesh"
options="iugedsrNADUO"

if [ $# -eq 0 ]; then
  echo "No arguments provided."
  echo -e "$help"
  exit 1
fi


install() {
  dialog --title "$software" --yesno "\nInstallation requires internet connection.\n\nLearn more at \nIf software is already present, will attempt to update.\n\nInstall?" 0 0
  if [ $? -eq 0 ]; then #unless cancel/no
    if [ ! -d /opt/TC2-BBS-mesh ]; then
        if ! git clone https://github.com/TheCommsChannel/TC2-BBS-mesh.git /opt/TC2-BBS-mesh; then
          dialog --title "$software" --msgbox "\nCloning of TC²-BBS git repo failed.\nCheck internet connectivity." 10 60
          return
        fi
        chown -R femto /opt/TC2-BBS-mesh
        git config --global --add safe.directory /opt/TC2-BBS-mesh # prevents git error when updating
    else
      # /opt/meshing-around exists, check for updates
      cd /opt/TC2-BBS-mesh
      if ! sudo git pull; then
        dialog --title "$software" --msgbox "\nFailed to update TC²-BBS.\nCheck internet connectivity." 10 60
        return
      fi
    fi
  else
    return
  fi
  if [ ! -f /opt/TC2-BBS-mesh/config.ini ]; then # if the config file doesn't exist but the clone was successful, then we need to do some configuring and rejiggering
		cd /opt/TC2-BBS-mesh
		echo "Creating virtual environment. This can take a couple minutes."
		python3 -m venv venv
		source venv/bin/activate
		pip install -r requirements.txt
		mv example_config.ini config.ini
		sed -i 's/type = serial/type = tcp/' config.ini
		sed -i 's/^# hostname = 192.168.x.x/hostname = 127.0.0.1/' config.ini
  fi
  echo "Installation/upgrade successful! Adding/recreating service."
  cd /opt/TC2-BBS-mesh
  source venv/bin/activate
  sed -i "s/pi/${SUDO_USER:-$(whoami)}/g" mesh-bbs.service
  sed -i "s|/home/femto/|/opt/|g" mesh-bbs.service
  cp mesh-bbs.service /etc/systemd/system/
  sudo systemctl enable mesh-bbs.service
  sudo systemctl restart mesh-bbs.service

  # for whatever reason, this is necessary
  sleep 5
  sudo systemctl restart mesh-bbs
  
  echo -e "\nPress any key to continue..."
  read -n 1 -s -r
  dialog --title "$software" --msgbox "\nInstallation complete." 8 50
}


uninstall() {
echo placeholder
}


upgrade() {
echo placeholder
}


while getopts ":h$options" opt; do
  case ${opt} in
    h) # Option -h (help)
      echo -e "$help"
      ;;
    i) # Option -i (install)
      install
      ;;
    i) # Option -u (uninstall)
      uninstall
      ;;
    g) # Option -g (upgrade)
      upgrade
      ;;
    e) # Option -e (Enable service, if applicable)
      systemctl enable SERVICENAME
      ;;
    d) # Option -d (Disable service, if applicable)
      systemctl disable SERVICENAME
      ;;
    s) # Option -s (Stop service)
      systemctl stop SERVICENAME
      ;;
    r) # Option -r (Start/Restart)
      systemctl restart SERVICENAME
      ;;
    D) echo $description ;;
    U) echo $URL ;;
    O) echo $options ;;
  esac
done

exit 0