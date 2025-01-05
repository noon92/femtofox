while true; do
title="Software"
  option=""
  option=$(dialog --cancel-label "Back" --menu "$title" 0 0 6 \
    1 "Meshing Around by Spud" \
    2 "The Comms Channel BBS, TC2BBS" \
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
    1) #Install Meshing Around)
          #check if /opt/meshing-around exists if not git clone
      if [ ! -d /opt/meshing-around ]; then
        dialog --title "$software" --yesno "Meshing Around is a feature-rich bot designed to enhance your Meshtastic network experience with a variety of powerful tools and fun features\nConnectivity and utility through text-based message delivery.\nWhether you're looking to perform network tests, send messages, or even play games, mesh_bot.py has you covered.\nInstallation requires internet connection.\n\nLearn more at https://github.com/SpudGunMan/meshing-around\n\nInstall?" 0 0
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
          dialog --title "$software" --yesno "Would you like to edit the config file? (press ctl+o,enter to save, ctl+x to exit nano)" 0 0
          if [ $? -eq 0 ]; then #unless cancel/no
            sudo nano /opt/meshing-around/config.ini
            echo "Restarting services..."
            sudo systemctl restart mesh_bot
          fi
          # finished. display the contents of install_notes.txt
          dialog --title "$software" --textbox /opt/meshing-around/install_notes.txt 20 60
        else
          /opt/meshing-around/install.sh pong
          dialog --title "$software" --yesno "Would you like to edit the config file? (press ctl+o,enter to save, ctl+x to exit nano)" 0 0
          if [ $? -eq 0 ]; then #unless cancel/no
            sudo nano /opt/meshing-around/config.ini
            echo "Restarting services..."
            sudo systemctl restart pong_bot
          fi
          # finished. display the contents of install_notes.txt
          dialog --title "$software" --textbox /opt/meshing-around/install_notes.txt 20 60
        fi
      fi
    ;;
    2) #Install TC2BBS)
      if git clone https://github.com/TheCommsChannel/TC2-BBS-mesh.git /opt/TC2-BBS-mesh; then
        /opt/TC2-BBS-mesh/install.sh #install script
        # config the TC2-BBS to localhost tcp TODO
        dialog --title "$software" --msgbox "\nInstallation complete.\n\nRun \`sudo nano /opt/TC2-BBS-mesh/config.ini\` to configure." 10 60
      else
        dialog --title "$software" --msgbox "\nCloning of TC2-BBS git repo failed.\nCheck internet connectivity." 10 60
      fi
    ;;
    3) #Install curses client)
      git clone https://github.com/pdxlocations/curses-client-for-meshtastic.git /opt/curses-client-for-meshtastic
      ln -s /opt/curses-client-for-meshtastic/meshtastic-curses.py ~/meshtastic-curses.py
      # config the curses client to localhost tcp TODO, permissions?
      dialog --title "$software" --msgbox "\nInstallation complete.\n\nRun \`~/meshtastic-curses.py\` to launch." 10 60
    ;;
    4) #Install mosquitto)
      apt update
      DEBIAN_FRONTEND=noninteractive apt install -y --option Dpkg::Options::="--force-confold" mosquitto mosquitto-clients
      # config mosquitto to listen on all interfaces and allow anonymous
      sudo sh -c "echo 'listener 1883 0.0.0.0\nallow_anonymous true' >> /etc/mosquitto/mosquitto.conf"
      sudo systemctl restart mosquitto
      dialog --title "$software" --msgbox "\nInstallation complete.\n\nMosquitto." 10 60
    ;;
    5) #Install gpsd)
      apt update
      DEBIAN_FRONTEND=noninteractive apt install -y --option Dpkg::Options::="--force-confold" gpsd gpsd-clients python-gps
      # do stuff TODO config gpsd and chrony
      # telemetry script
      sudo systemctl restart gpsd
      dialog --title "$software" --msgbox "\nInstallation complete.\n\nGPSD." 10 60
    ;;
    6)
      break
    ;;
  esac
done