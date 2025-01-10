  #!/bin/bash
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Try \`sudo femto-meshtasticd-config\`."
   exit 1
fi

args="$@"
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
-A          Get author
-D          Get description
-U          Get URL
-O          Get options supported by this script
-S          Get service status
EOF
)

### For package maintainer:
# Fill the following fields and choose the options that are in use by this package
# Populate the install, uninstall and upgrade functions
# Remember that this script may be launched in terminal, via web UI or another method, so inputs aren't really possible
# Arguments to the script are stored in $args

name="" # software name
author="" # software author OPTIONAL
description="" # software description OPTIONAL (but strongly recommended!)
URL="" # software URL OPTIONAL. Can contain multiple URLs
options="iugedsrNADUOS" # script options in use by software package. For example, for a package with no service, exclude `edsr`
service_name="" # the name of the service, such as `chrony`. REQUIRED if service options are in use. If multiple services, separate by spaces "service1 service2"


if [ $# -eq 0 ]; then
  echo "No arguments provided."
  echo -e "$help"
  exit 1
fi


install() {
  echo placeholder
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
  esac
done

exit 0