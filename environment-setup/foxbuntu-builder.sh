#!/bin/bash

if [[ $(id -u) != 0 ]]; then
  echo "This script must be run as root; use sudo"
  exit 1
fi

sudoer=$(echo $SUDO_USER)

# Check if 'dialog' is installed, install it if missing
if ! command -v dialog &> /dev/null; then
  echo "The 'dialog' package is required to run this script. Press any key to install it."
  read -n 1 -s -r
  apt update && apt install -y dialog
fi

################ TODO ################
# Add more error handling
# Address potential issues in comments
# Package selection with curses
# Switch chroot packages install
# Modify DTS etc to enable SPI1
######################################

install_prerequisites() {
  echo "Setting up Foxbuntu build environment..."
  apt update
  apt install -y git ssh make gcc gcc-multilib g++-multilib module-assistant expect g++ gawk texinfo libssl-dev bison flex fakeroot cmake unzip gperf autoconf device-tree-compiler libncurses5-dev pkg-config bc python-is-python3 passwd openssl openssh-server openssh-client vim file cpio rsync qemu-user-static binfmt-support dialog
}

clone_repos() {
  echo "Cloning repos..."
  cd /home/${sudoer}/
  git clone https://github.com/LuckfoxTECH/luckfox-pico.git
  git clone https://github.com/noon92/femtofox.git
}

build_env() {
  echo "Setting up SDK env..."
  echo "When the menu appears to choose your board choose Luckfox Pico Mini A (1), SDCard (0) and Ubuntu (1)."
  echo "Press any key to continue building the environment..."
  read -n 1 -s -r
  cd /home/${sudoer}/luckfox-pico
  ./build.sh env
}

build_sysdrv() {
  echo "Building sysdrv..."
  cd /home/${sudoer}/luckfox-pico
  ./build.sh sysdrv
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

copy_femtofox_kernelcfg() {
  echo "Merging in Foxbuntu modifications..."
  cd /home/${sudoer}/femtofox/foxbuntu/
  rsync -aHAXv --progress --keep-dirlinks --itemize-changes /home/${sudoer}/femtofox/foxbuntu/sysdrv/ /home/${sudoer}/luckfox-pico/sysdrv/
  rsync -aHAXv --progress --keep-dirlinks --itemize-changes /home/${sudoer}/femtofox/foxbuntu/project/ /home/${sudoer}/luckfox-pico/project/
  rsync -aHAXv --progress --keep-dirlinks --itemize-changes /home/${sudoer}/femtofox/foxbuntu/output/image/ /home/${sudoer}/luckfox-pico/output/image/
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

inject_chroot() {
  chroot_script=${CHROOT_SCRIPT:-/home/${sudoer}/femtofox.chroot}
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
  echo "Updating repo..."
  cd /home/${sudoer}/femtofox
  git pull
  cd /home/${sudoer}/
  copy_femtofox_kernelcfg
  build_kernelconfig
  build_rootfs
  build_firmware
  create_image
}

modify_rootfs() {
  echo "Modifying rootfs..."
  cd /home/${sudoer}/luckfox-pico/output/image
  echo "Copying kernel modules..."
  mkdir -p /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/lib/modules/5.10.160
  cp /home/${sudoer}/luckfox-pico/sysdrv/out/kernel_drv_ko/* /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/lib/modules/5.10.160/
  which qemu-arm-static

  chroot_script=${CHROOT_SCRIPT:-/home/${sudoer}/femtofox.chroot}
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

build_firmware() {
  echo "Building firmware..."
  cd /home/${sudoer}/luckfox-pico/
  ./build.sh firmware
}

create_image() {
  echo "Creating final sdcard img..."
  cd /home/${sudoer}/luckfox-pico/output/image
  /home/${sudoer}/luckfox-pico/output/image/blkenvflash /home/${sudoer}/luckfox-pico/foxbuntu.img
  if [[ $? -eq 2 ]]; then echo "Error, sdcard img failed to build..."; exit 2; else echo "foxbuntu.img build completed."; fi
  du -h /home/${sudoer}/luckfox-pico/foxbuntu.img
}

sdk_install() {
  start_time=$(date +%s)
  install_prerequisites
  clone_repos
  build_env
  build_uboot
  copy_femtofox_kernelcfg
  build_kernelconfig
  build_rootfs
  rsync -aHAXv --progress --keep-dirlinks --itemize-changes /home/${sudoer}/femtofox/foxbuntu/sysdrv/out/rootfs_uclibc_rv1106/ /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/
  build_firmware
  modify_rootfs
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
  echo "To install the development environment use the arg 'install' and is intended to be run ONCE only."
  echo "To modify the chroot and build an updated image use the arg 'modify_chroot'."
  echo "To modify the kernel and build an updated image use the arg 'modify_kernel'."
  echo "other args: install_prerequisites clone_repos build_env build_sysdrv copy_femtofox_kernelcfg build_kernelconfig modify_rootfs build_rootf build_uboot build_firmware get_envblkflash create_image"
  echo "Example:  sudo ~/foxbunto_env_setup.sh install"
  echo "Example:  sudo ~/foxbunto_env_setup.sh modify_chroot"
  exit 0
}
################### MENU SYSTEM ###################

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
      1 "Update Image" \
      2 "Modify Chroot" \
      3 "Inject Chroot" \
      4 "Modify Kernel" \
      5 "Install Prerequisites" \
      6 "Clone Repositories" \
      7 "Build Environment" \
      8 "Build SysDrv" \
      9 "Build U-Boot" \
      10 "Build RootFS" \
      11 "Create Final Image" \
      12 "SDK Install (Run All Steps)" \
      13 "Exit" \
      2>&1 >/dev/tty)

    clear

    case $CHOICE in
      1) update_image ;;
      2) modify_chroot ;;
      3) inject_chroot ;;
      4) modify_kernel ;;
      5) install_prerequisites ;;
      6) clone_repos ;;
      7) build_env ;;
      8) build_sysdrv ;;
      9) build_uboot ;;
      10) build_rootfs ;;
      11) create_image ;;
      12) sdk_install ;;
      13) echo "Exiting..."; break ;;
      *) echo "Invalid option, please try again." ;;
    esac

    # Pause after executing a command
    echo "Menu selection completed. Press any key to return to the menu."
    read -n 1 -s -r
  done
else
  if [[ "${1}" == "--chroot-script" ]]; then
    CHROOT_SCRIPT=${2}
  fi
  if declare -f "${1}" > /dev/null; then
    "${1}"
  else
    echo "Error: Function '${1}' not found."
    usage
    exit 1
  fi
fi

exit 0
