#!/bin/bash

################ TODO ################
# Add more error handling
# Package selection with curses
# Switch chroot packages install
# Modify DTS etc to enable SPI1
######################################

if [[ $(id -u) != 0 ]]; then
  echo "This script must be run as root; use sudo"
  exit 1
fi

[ -f /etc/os-release ] && . /etc/os-release

if [ "$VERSION_ID" != "22.04" ] || [ "$NAME" != "Ubuntu" ]; then
    echo -e "This script is intended for Ubuntu 22.04, your operating system is not supported (but may work).\nPress Ctrl+C to cancel, or Enter to continue."
    read
fi

sudoer=$(echo $SUDO_USER)

# Check if 'dialog' is installed, install it if missing
if ! command -v dialog &> /dev/null; then
  echo "The 'dialog' package is required to run this script. Press any key to install it."
  read -n 1 -s -r
  apt update && apt install -y dialog
fi

install_prerequisites() {
  echo "Setting up Foxbuntu build environment..."
  apt update
  apt install -y git ssh make gcc gcc-multilib g++-multilib module-assistant expect g++ gawk texinfo libssl-dev bison flex fakeroot cmake unzip gperf autoconf device-tree-compiler libncurses5-dev pkg-config bc python-is-python3 passwd openssl openssh-server openssh-client vim file cpio rsync qemu-user-static binfmt-support dialog
}

clone_repos() {
  echo "Cloning repos..."
  cd /home/${sudoer}/ || return 1

  clone_with_retries() {
    local repo_url="$1"
    local retries=3
    local count=0
    local success=0

    while [ $count -lt $retries ]; do
      echo "Attempting to clone $repo_url (Attempt $((count + 1))/$retries)"
      git clone "$repo_url" && success=1 && break
      count=$((count + 1))
      echo "Retrying..."
    done

    if [ $success -eq 0 ]; then
      echo "Failed to clone $repo_url after $retries attempts."
      return 1
    fi
  }

  clone_with_retries "https://github.com/LuckfoxTECH/luckfox-pico.git" || return 1
  clone_with_retries "https://github.com/femtofox/femtofox.git" || return 1

  return 0
}

build_env() {
  echo "Setting up SDK env..."
  echo "When the menu appears to choose your board choose Luckfox Pico Mini A (1), SDCard (0) and Ubuntu (1)."
  echo "Press any key to continue building the environment..."
  read -n 1 -s -r
  cd /home/${sudoer}/luckfox-pico
  ./build.sh env
}

build_uboot() {
  echo "Building uboot..."
  cd /home/${sudoer}/luckfox-pico
  ./build.sh uboot
}

build_rootfs() {
  echo "Building rootfs..."
  cd /home/${sudoer}/luckfox-pico
  ./build.sh rootfs
}

build_firmware() {
  echo "Building firmware..."
  cd /home/${sudoer}/luckfox-pico/
  ./build.sh firmware
}

sync_foxbuntu_changes() {
  SOURCE_DIR=/home/${sudoer}/femtofox/foxbuntu
  DEST_DIR=/home/${sudoer}/luckfox-pico

  cd "$SOURCE_DIR" || exit
  git pull

  cd "$SOURCE_DIR" || exit
  git ls-files > /tmp/source_files.txt

  echo "Merging in Foxbuntu modifications..."
  rsync -aHAXv --progress --keep-dirlinks --itemize-changes /home/${sudoer}/femtofox/foxbuntu/sysdrv/ /home/${sudoer}/luckfox-pico/sysdrv/
  rsync -aHAXv --progress --keep-dirlinks --itemize-changes /home/${sudoer}/femtofox/foxbuntu/project/ /home/${sudoer}/luckfox-pico/project/
  rsync -aHAXv --progress --keep-dirlinks --itemize-changes /home/${sudoer}/femtofox/foxbuntu/output/image/ /home/${sudoer}/luckfox-pico/output/image/

  while read -r file; do
      src_file="$SOURCE_DIR/$file"
      dest_file="$DEST_DIR/$file"

      if [ ! -f "$src_file" ] && [ -f "$dest_file" ]; then
          echo "Deleting $dest_file as it is no longer in the git repository."
          rm -f "$dest_file"
      fi
  done < /tmp/source_files.txt

  rm /tmp/source_files.txt

  echo "Synchronization complete."
}

build_kernelconfig() {
  echo "Building kernelconfig... Please exit without making any changes unless you know what you are doing."
  echo "Press any key to continue building the kernel..."
  read -n 1 -s -r
  cd /home/${sudoer}/luckfox-pico
  ./build.sh kernelconfig
  ./build.sh kernel
}

modify_kernel() {
  echo "Building kernel... ."
  echo "After making kernel configuration changes, make sure to save as .config (default) before exiting."
  echo "Press any key to continue building the kernel..."
  read -n 1 -s -r
  cd /home/${sudoer}/luckfox-pico
  ./build.sh kernelconfig
  ./build.sh kernel
  build_rootfs
  build_firmware
  cp /home/${sudoer}/luckfox-pico/sysdrv/out/kernel_drv_ko/* /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/lib/modules/5.10.160/
  echo "Entering chroot..."
  mount --bind /proc /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/proc
  mount --bind /sys /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/sys
  mount --bind /dev /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/dev
  mount --bind /dev/pts /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/dev/pts
  chroot /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106 /bin/bash <<EOF
echo "Inside chroot environment..."
echo "Setting up kernel modules..."
depmod -a 5.10.160
echo "Cleaning up chroot..."
apt clean && rm -rf /var/lib/apt/lists/* && rm -rf /tmp/* && rm -rf /var/tmp/* && find /var/log -type f -exec truncate -s 0 {} + && : > /root/.bash_history && history -c
exit
EOF

  umount /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/dev/pts
  umount /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/proc
  umount /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/sys
  umount /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/dev
  build_rootfs
  build_firmware
  create_image
}

modify_chroot() {
  echo "Entering chroot... make your changes and then type exit when you are done and it will build the image with your changes."
  echo "Press any key to continue entering chroot..."
  read -n 1 -s -r
  mount --bind /proc /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/proc
  mount --bind /sys /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/sys
  mount --bind /dev /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/dev
  mount --bind /dev/pts /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/dev/pts
  chroot /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106 /bin/bash
  umount /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/dev/pts
  umount /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/proc
  umount /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/sys
  umount /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/dev
  build_rootfs
  build_firmware
  create_image
}

rebuild_chroot() {
  chroot_script=${CHROOT_SCRIPT:-/home/${sudoer}/femtofox/environment-setup/femtofox.chroot}
  if [[ ! -f $chroot_script ]]; then
    echo "Error: Chroot script $chroot_script not found."
    exit 1
  fi

  echo "Press any key to wipe and rebuild chroot..."
  read -n 1 -s -r
  cd /home/${sudoer}/luckfox-pico
  ./build.sh clean rootfs
  cd /home/${sudoer}/
  rsync -aHAXv --progress --keep-dirlinks --itemize-changes /home/${sudoer}/femtofox/foxbuntu/sysdrv/ /home/${sudoer}/luckfox-pico/sysdrv/
  rsync -aHAXv --progress --keep-dirlinks --itemize-changes /home/${sudoer}/femtofox/foxbuntu/project/ /home/${sudoer}/luckfox-pico/project/
  build_rootfs
  rsync -aHAXv --progress --keep-dirlinks --itemize-changes /home/${sudoer}/femtofox/foxbuntu/sysdrv/out/rootfs_uclibc_rv1106/ /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/
  build_firmware
  install_rootfs
  build_rootfs
  build_firmware
  create_image
}

inject_chroot() {
  chroot_script=${CHROOT_SCRIPT:-/home/${sudoer}/femtofox/environment-setup/femtofox.chroot}
  if [[ ! -f $chroot_script ]]; then
    echo "Error: Chroot script $chroot_script not found."
    exit 1
  fi

  cp "$chroot_script" /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/tmp/chroot_script.sh
  chmod +x /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/tmp/chroot_script.sh

  echo "Press any key to continue entering chroot..."
  read -n 1 -s -r

  echo "Entering chroot and running commands..."

  mount --bind /proc /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/proc
  mount --bind /sys /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/sys
  mount --bind /dev /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/dev
  mount --bind /dev/pts /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/dev/pts
  chroot /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106 /tmp/chroot_script.sh
  umount /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/dev/pts
  umount /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/proc
  umount /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/sys
  umount /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/dev
  rm /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/tmp/chroot_script.sh
  build_rootfs
  build_firmware
  create_image

}

update_image() {
  build_env
  echo "Updating repo..."
  cd /home/${sudoer}/femtofox
  git pull
  cd /home/${sudoer}/
  sync_foxbuntu_changes
  build_kernelconfig
  build_rootfs
  build_firmware
  create_image
}

full_rebuild() {
  build_env
  build_uboot
  sync_foxbuntu_changes
  build_kernelconfig
  build_rootfs
  rsync -aHAXv --progress --keep-dirlinks --itemize-changes /home/${sudoer}/femtofox/foxbuntu/sysdrv/out/rootfs_uclibc_rv1106/ /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/
  build_firmware
  install_rootfs
  build_rootfs
  build_firmware
  create_image
}

install_rootfs() {
  echo "Modifying rootfs..."
  cd /home/${sudoer}/luckfox-pico/output/image
  echo "Copying kernel modules..."
  mkdir -p /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/lib/modules/5.10.160
  cp /home/${sudoer}/luckfox-pico/sysdrv/out/kernel_drv_ko/* /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/lib/modules/5.10.160/
  which qemu-arm-static

  chroot_script=${CHROOT_SCRIPT:-/home/${sudoer}/femtofox/environment-setup/femtofox.chroot}
  if [[ ! -f $chroot_script ]]; then
    echo "Error: Chroot script $chroot_script not found."
    exit 1
  fi

  cp "$chroot_script" /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/tmp/chroot_script.sh
  chmod +x /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/tmp/chroot_script.sh

  echo "Entering chroot and running commands..."
  cp /usr/bin/qemu-arm-static /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/usr/bin/
  mount --bind /proc /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/proc
  mount --bind /sys /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/sys
  mount --bind /dev /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/dev
  mount --bind /dev/pts /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/dev/pts
  chroot /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106 /tmp/chroot_script.sh
  umount /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/dev/pts
  umount /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/proc
  umount /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/sys
  umount /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/dev

  rm /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/tmp/chroot_script.sh
}

create_image() {
  echo "Creating final sdcard img..."
  cd /home/${sudoer}/luckfox-pico/output/image

  # File to modify
  ENVFILE=".env.txt"

  # Check if the file contains '6G(rootfs)'
  if grep -q '6G(rootfs)' "$ENVFILE"; then
      # Replace '6G(rootfs)' with '100G(rootfs)'
      sed -i 's/6G(rootfs)/100G(rootfs)/' "$ENVFILE"
      echo "Updated rootfs size from stock (6G) to 100G."
  else
      echo "No changes made to rootfs size because it has already been modified."
  fi

  /home/${sudoer}/luckfox-pico/sysdrv/tools/pc/uboot_tools/mkenvimage -s 0x8000 -p 0x0 -o env.img .env.txt

  /home/${sudoer}/luckfox-pico/output/image/blkenvflash /home/${sudoer}/luckfox-pico/foxbuntu.img
  if [[ $? -eq 2 ]]; then echo "Error, sdcard img failed to build..."; exit 2; else echo "foxbuntu.img build completed."; fi
  ls -la /home/${sudoer}/luckfox-pico/foxbuntu.img
  du -h /home/${sudoer}/luckfox-pico/foxbuntu.img
}

sdk_install() {
  echo "Installing Foxbuntu SDK Disk Image Builder..."
  if [ -d /home/${sudoer}/femtofox ]; then
      echo "WARNING: ~/femtofox exists, this script will DESTROY and recreate it."
      echo "Press Ctrl+C to cancel, or Enter to continue."
      read
      rm -rf /home/${sudoer}//femtofox
  fi
  if [ -d /home/${sudoer}/luckfox-pico ]; then
      echo "WARNING: ~/luckfox-pico exists, this script will DESTROY and recreate it."
      echo "Press Ctrl+C to cancel, or Enter to continue."
      read
      rm -rf /home/${sudoer}/luckfox-pico
  fi

  start_time=$(date +%s)
  install_prerequisites

  clone_repos || {
    echo "Failed to clone repositories. Exiting SDK installation."
    return 1
  }

  build_env
  build_uboot
  sync_foxbuntu_changes
  build_kernelconfig
  build_rootfs
  rsync -aHAXv --progress --keep-dirlinks --itemize-changes /home/${sudoer}/femtofox/foxbuntu/sysdrv/out/rootfs_uclibc_rv1106/ /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/
  build_firmware
  install_rootfs
  build_rootfs
  build_firmware
  create_image
  end_time=$(date +%s)
  elapsed=$(( end_time - start_time ))
  hours=$(( elapsed / 3600 ))
  minutes=$(( (elapsed % 3600) / 60 ))
  seconds=$(( elapsed % 60 ))
  printf "Environment installation time: %02d:%02d:%02d\\n" $hours $minutes $seconds
}

usage() {
  echo "The following functions are available in this script:"
  echo "To install the development environment use the arg 'sdk_install' and is intended to be run ONCE only."
  echo "To modify the chroot and build an updated image use the arg 'modify_chroot'."
  echo "To modify the kernel and build an updated image use the arg 'modify_kernel'."
  echo "To specify a custom chroot script use the arg '--chroot-script /full/path/to/custom.chroot'"
  echo "other args: full_rebuild rebuild_chroot inject_chroot build_env sync_foxbuntu_changes build_kernelconfig install_rootfs build_rootfs build_uboot build_firmware create_image"
  echo "Example:  sudo ~/foxbunto_env_setup.sh sdk_install"
  echo "Example:  sudo ~/foxbunto_env_setup.sh modify_chroot"
  echo "Example:  sudo ~/foxbunto_env_setup.sh --chroot-script /home/user/custom.chroot"
  exit 0
}

################### MENU SYSTEM ###################

if [[ "${1}" == "--chroot-script" ]]; then
  CHROOT_SCRIPT=${2}
  echo "CHROOT_SCRIPT is set to '${CHROOT_SCRIPT}'"
  echo "Press any key to continue..."
  read -n 1 -s -r
  shift 2  # Remove --chroot-script and its argument from the arguments list
fi

if [[ "${1}" =~ ^(-h|--help|h|help)$ ]]; then
  usage
elif [[ -z ${1} ]]; then
  if ! command -v dialog &> /dev/null; then
    echo "The 'dialog' package is required to load the menu."
    echo "Please install it using: sudo apt install dialog"
    exit 1
  fi
  while true; do
    CHOICE=$(dialog --clear --no-cancel --backtitle "Foxbuntu SDK Builder" \
      --title "Main Menu" \
      --menu "Choose an action:" 20 60 12 \
      1 "Full Image Rebuild" \
      2 "Get Image Updates" \
      3 "Modify Kernel Menu" \
      4 "Enter and Modify Chroot" \
      5 "Rebuild Chroot" \
      6 "Inject Chroot Script (CAUTION)" \
      7 "Manual Build Environment" \
      8 "Manual Build U-Boot" \
      9 "Manual Build RootFS" \
      10 "Manual Build Firmware" \
      11 "Manual Create Final Image" \
      12 "SDK Install (Run this first.)" \
      13 "Exit" \
      2>&1 >/dev/tty)

    clear

    case $CHOICE in
      1) full_rebuild ;;
      2) update_image ;;
      3) modify_kernel ;;
      4) modify_chroot ;;
      5) rebuild_chroot ;;
      6) inject_chroot ;;
      7) build_env ;;
      8) build_uboot ;;
      9) build_rootfs ;;
      10) build_firmware ;;
      11) create_image ;;
      12) sdk_install ;;
      13) echo "Exiting..."; break ;;
      *) echo "Invalid option, please try again." ;;
    esac

    echo "Menu selection completed. Press any key to return to the menu."
    read -n 1 -s -r
  done
else
  if declare -f "${1}" > /dev/null; then
    "${1}"
  else
    echo "Error: Function '${1}' not found."
    usage
    exit 1
  fi
fi

exit 0
