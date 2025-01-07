#!/bin/bash

uninstall="false"

meshing_around() { # Install Meshing Around
  failedInstall=false
      #check if /opt/meshing-around exists if not git clone
  if [ ! -d /opt/meshing-around ]; then
    dialog --title "$software" --yesno "Meshing Around is a feature-rich bot designed to enhance your Meshtastic network experience with a variety of powerful tools and fun features\nConnectivity and utility through text-based message delivery.\nWhether you're looking to perform network tests, send messages, or even play games, mesh_bot.py has you covered.\nInstallation requires internet connection.\n\nLearn more at https://github.com/SpudGunMan/meshing-around\nIf software is already present, will attempt to update.\n\nInstall?" 0 0
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


tc2_bbs() { # Install TC²BBS
  dialog --title "$software" --yesno "The TC²-BBS system integrates with Meshtastic devices. The system allows for message handling, bulletin boards, mail systems, and a channel directory.\nInstallation requires internet connection.\n\nLearn more at https://github.com/TheCommsChannel/TC2-BBS-mesh\nIf software is already present, will attempt to update.\n\nInstall?" 0 0
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
  dialog --title "$software" --msgbox "\nInstallation complete." 8 50
}


curses_client() { # Install curses client
  git clone https://github.com/pdxlocations/curses-client-for-meshtastic.git /opt/curses-client-for-meshtastic
  ln -s /opt/curses-client-for-meshtastic/meshtastic-curses.py ~/meshtastic-curses.py
  # config the curses client to localhost tcp TODO, permissions?
  dialog --title "$software" --msgbox "\nInstallation complete.\n\nRun \`~/meshtastic-curses.py\` to launch." 10 60
}


mosquitto() { # Install mosquitto
  apt update
  DEBIAN_FRONTEND=noninteractive apt install -y --option Dpkg::Options::="--force-confold" mosquitto mosquitto-clients
  # config mosquitto to listen on all interfaces and allow anonymous
  sudo sh -c "echo 'listener 1883 0.0.0.0\nallow_anonymous true' >> /etc/mosquitto/mosquitto.conf"
  sudo systemctl restart mosquitto
  dialog --title "$software" --msgbox "\nInstallation complete.\n\nMosquitto." 10 60
}


gpsd() { # Install gpsd 
  apt update
  DEBIAN_FRONTEND=noninteractive apt install -y --option Dpkg::Options::="--force-confold" gpsd gpsd-clients python-gps
  # do stuff TODO config gpsd and chrony
  # telemetry script
  sudo systemctl restart gpsd
  dialog --title "$software" --msgbox "\nInstallation complete.\n\nGPSD." 10 60
}


help=$(cat <<EOF
If script is run without arguments, a dialog menu UI will load.
Options are:
-h        This message
-u        Uninstall - must be FIRST argument. if this is not set, the default operation is to install the software
-s        Meshing Around by Spud
-b        The Comms Channel BBS, TC²BBS
-c        Curses Client for Meshtastic
-m        Mosquitto MQTT broker
-g        GPS and Telemetry
EOF
)
# Parse options
while getopts ":husbcmg" opt; do
  case ${opt} in
    h) echo help && exit 0 ;;
    u) uninstall="true" ;;
    s) meshing_around ;;
    b) tc2_bbs ;;
    c) curses_client ;;
    m) mosquitto ;;
    g) gpsd ;;
  esac
done
if [ -n "$1" ]; then
  exit
fi


while true; do
title="Software"
  option=""
  option=$(dialog --cancel-label "Back" --menu "$title" 0 0 6 \
    1 "Meshing Around by Spud" \
    2 "The Comms Channel BBS, TC²BBS" \
    3 "Curses Client for Meshtastic" \
    4 "Mosquitto MQTT broker" \
    5 "GPS and Telemetry" \
    "" ""\
    6 "Back to Main Menu" 3>&1 1>&2 2>&3)
  
  exit_status=$? # This line checks the exit status of the dialog command
  if [ $exit_status -ne 0 ]; then # Exit the loop if the user selects "Cancel" or closes the dialog
    break
  fi
  
  case $option in
    1) meshing_around ;;
    2) tc2_bbs ;;
    3) curses_client ;;
    4) mosquitto ;;
    5) gpsd ;;
    6) break ;;
  esac
done

exit 0