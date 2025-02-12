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
interactive="true" # by default, we're in interactive mode

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
-E          Get service name
-L          Get install location
-G          Get license
-T          Get license name
-P          Get package name
-C          Get Conflicts
-I          Check if installed. Returns an error if not installed
EOF
)

while getopts ":$options" opt; do
  case ${opt} in
    h) # Option -h (help)
      echo -e "$help"
      ;;
    x) # Option -x (no user interaction available)
      interactive="false"
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
    E) # Option -E (Get service name)
      echo $service_name
    ;;
    L) echo -e $location ;;
    G) # Option -G (Get license) 
      license
    ;;
    T) # Option -T (Get license name) 
      echo $license_name
    ;;
    P) echo -e $package_name ;;
    C) echo -e $conflicts ;;
    I) # Option -I (Check if already installed)
      check
    ;;
    \?) exit 1 ;; # Unknown option)
  esac
done