#!/bin/bash

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