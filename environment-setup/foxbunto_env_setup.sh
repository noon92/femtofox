#!/bin/bash
# one line installer
# cd ~ && wget https://raw.githubusercontent.com/noon92/femtofox/refs/heads/main/environment-setup/foxbunto_env_setup.sh -O foxbunto_env_setup.sh && bash foxbunto_env_setup.sh
cd ~
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [ "$VERSION_ID" != "22.04" ] || [ "$NAME" != "Ubuntu" ]; then
        echo "This script is intended for Ubuntu 22.04, exiting..."
        exit 1
    fi
else
    echo "This script is intended for Ubuntu 22.04, exiting..."
    exit 1
fi
if [ "$EUID" -eq 0 ]; then
    echo "Please run this script without sudo."
    exit 1
fi
echo
echo "=========================================="
echo "           Foxbuntu Build Environment"
echo "=========================================="
echo
echo "Setting up new Foxbuntu build environment..."
echo
echo "This script will install the necessary packages to build the Foxbuntu image."
echo "It will also set up a chroot environment to install additional packages. This will all take some time."
echo
echo "You will need to answer some questions during the start of the script."
echo "Please make sure you have a stable internet connection and enough disk space. (20GB)"
echo "Choose the default of [0] if unknown, and [1] for Ubuntu when prompted."
echo "When the Kernel build GUI appears, just exit without making any changes."
echo
echo "Press Enter to continue, or Ctrl+C to cancel."
read
# get the luckfox build environment
if [ -d ~/femtofox ]; then
    echo "WARNING: ~/femtofox exists, this script will overwrite it."
    echo "Press Ctrl+C to cancel, or Enter to continue."
    read
    sudo rm -rf ~/femtofox
fi
if [ -d ~/luckfox-pico ]; then
    echo "WARNING: ~/luckfox-pico exists, this script will overwrite it."
    echo "Press Ctrl+C to cancel, or Enter to continue."
    read
    sudo rm -rf ~/luckfox-pico
fi

# get updates and packages
sudo apt update
sudo apt-get install -y git ssh make gcc gcc-multilib g++-multilib module-assistant expect g++ gawk texinfo libssl-dev bison flex fakeroot cmake unzip gperf autoconf device-tree-compiler libncurses5-dev pkg-config bc python-is-python3 passwd openssl openssh-server openssh-client vim file cpio rsync

git clone https://github.com/LuckfoxTECH/luckfox-pico.git
cd ~/luckfox-pico
echo "### Choose [1] Ubuntu ### Choose [1] Ubuntu ###"
sudo ./build.sh lunch
sudo ./build.sh

# get the femtofox environment
cd ~
git clone https://github.com/noon92/femtofox.git
~/femtofox/foxbuntu/updatefs.sh
cd ~/luckfox-pico/

# get the blkenvflash imagemaker v2.2
sudo wget https://gist.githubusercontent.com/Spiritdude/da36d2cf064e49094c870e0a8b9f972f/raw/8f05ce57f5dede06a45f25298982fab543d95084/blkenvflash -O ~/luckfox-pico/output/image/blkenvflash
sudo chmod +x ~/luckfox-pico/output/image/blkenvflash

# build the kernel
echo "### exit no changes ### exit no changes ###"
sudo ./build.sh

# SETUP CHROOT
sudo mkdir -p ~/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/lib/modules/5.10.160
sudo cp ~/luckfox-pico/sysdrv/out/kernel_drv_ko/* ~/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/lib/modules/5.10.160

sudo apt update
sudo apt install qemu-user-static binfmt-support
which qemu-arm-static   # get qemu location and use it in next command
sudo cp /usr/bin/qemu-arm-static ~/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/usr/bin/

# CHROOT IN
echo "Entering chroot and running commands..."
sudo mount --bind /proc ~/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/proc && sudo mount --bind /sys ~/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/sys && sudo mount --bind /dev ~/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/dev && sudo mount --bind /dev/pts ~/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/dev/pts

sudo -k chroot ~/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106 /bin/bash <<EOF
echo "Inside chroot environment..."
echo "tmpfs /run tmpfs rw,nodev,nosuid,size=32M 0 0" | sudo tee -a /etc/fstab

wget -qO- https://meshtastic.github.io/meshtastic-deb.asc | sudo tee /etc/apt/keyrings/meshtastic-deb.asc >/dev/null

echo "deb [arch=all signed-by=/etc/apt/keyrings/meshtastic-deb.asc] https://meshtastic.github.io/deb stable main" | sudo tee /etc/apt/sources.list.d/meshtastic-deb.list >/dev/null

sudo ln -s /dev/null /etc/udev/rules.d/80-net-setup-link.rules

sudo touch /lib/modules/5.10.160/modules.order
sudo touch /lib/modules/5.10.160/modules.builtin
sudo depmod -a 5.10.160

sudo rm /etc/localtime
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

sudo apt update

sudo DEBIAN_FRONTEND=noninteractive apt install -y --option Dpkg::Options::="--force-confold" linux-firmware wireless-tools git python3.10-venv libgpiod-dev libyaml-cpp-dev libbluetooth-dev openssl libssl-dev libulfius-dev liborcania-dev evtest meshtasticd screen avahi-daemon protobuf-compiler telnet fonts-noto-color-emoji ninja-build

sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y --option Dpkg::Options::="--force-confold"

# emoji font
sudo DEBIAN_FRONTEND=noninteractive apt install -y --option Dpkg::Options::="--force-confold" fonts-noto-color-emoji ninja-build

# meshtastic CLI / API
pip3 install pypubsub meshtastic 

################ meshtastic community projects

echo "Installing meshtastic community projects..."

echo "Installing meshing around BBS..."
git clone https://github.com/spudgunman/meshing-around.git /opt/meshing-around
# Dependencies for meshing around 
pip3 install requests pyephem geopy maidenhead beautifulsoup4 dadjokes schedule wikipedia googlesearch-python

# Set up the meshing around service
# sudo cp /opt/meshing-around/meshing-around.service /etc/systemd/system/meshing-around.service
# sudo systemctl enable meshing-around

echo "Installing TC2 BBS..."
git clone https://github.com/TheCommsChannel/TC2-BBS-mesh.git /opt/TC2-BBS-mesh

echo "Installing the shell clients for meshtastic..."

# Curses client for meshtastic
git clone https://github.com/pdxlocations/curses-client-for-meshtastic.git /opt/curses-client-for-meshtastic

# Emesh client for meshtastic
git clone https://github.com/thecookingsenpai/emesh.git /opt/emesh

# Install additional tools
sudo DEBIAN_FRONTEND=noninteractive apt install -y --option Dpkg::Options::="--force-confold" mosquitto mosquitto-clients
sudo DEBIAN_FRONTEND=noninteractive apt install -y --option Dpkg::Options::="--force-confold" gpsd gpsd-clients python-gps
sudo DEBIAN_FRONTEND=noninteractive apt install -y --option Dpkg::Options::="--force-confold" screen minicom
#sudo DEBIAN_FRONTEND=noninteractive apt install -y --option Dpkg::Options::="--force-confold" telnet
#sudo DEBIAN_FRONTEND=noninteractive apt install -y --option Dpkg::Options::="--force-confold" i2c-tools
#sudo DEBIAN_FRONTEND=noninteractive apt install -y --option Dpkg::Options::="--force-confold" RPi.GPIO gpio

################

mv /etc/update-motd.d/10-help-text /etc/update-motd.d/10-help-text.bak
mv /etc/update-motd.d/60-unminimize /etc/update-motd.d/60-unminimize.bak

sudo systemctl enable button
sudo systemctl enable wifi-mesh-control

sudo systemctl disable NetworkManager
sudo systemctl disable NetworkManager-dispatcher
sudo systemctl disable NetworkManager-wait-online

echo "femtofox" | sudo tee /etc/hostname > /dev/null

sudo systemctl disable vsftpd.service
sudo systemctl disable ModemManager.service
sudo systemctl disable getty@tty1.service
sudo systemctl disable acpid
sudo systemctl disable acpid.socket
sudo systemctl disable acpid.service
sudo systemctl mask alsa-restore.service
sudo systemctl disable alsa-restore.service
sudo systemctl disable alsa-state.service
sudo systemctl mask sound.target
sudo systemctl disable sound.target
sudo systemctl disable veritysetup.target
sudo systemctl disable systemd-pstore.service

sudo groupmod -n femto pico
sudo usermod -l femto pico
sudo usermod -aG sudo,input femto
echo "femto ALL=(ALL:ALL) ALL" | sudo tee /etc/sudoers.d/femto > /dev/null
sudo chmod 440 /etc/sudoers.d/femto
sudo find / -group pico -exec chgrp femto {} \; 2>/dev/null
sudo find / -user pico -exec chown femto {} \; 2>/dev/null
sudo usermod -d /home/femto -m femto
ls -ld /home/femto
echo 'femto:fox' | chpasswd
sudo usermod -a -G tty femto
sudo usermod -a -G dialout femto

sudo apt clean && rm -rf /var/lib/apt/lists/* && rm -rf /tmp/* && rm -rf /var/tmp/* && find /var/log -type f -exec truncate -s 0 {} + && : > /root/.bash_history && history -c
exit
EOF

echo "Exited chroot, performing cleanup..."
sudo umount ~/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/dev/pts
sudo umount ~/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/proc
sudo umount ~/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/sys
sudo umount ~/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/dev

# BURN IMG (combine images into one we can burn to disk)
echo "Building image..."
sudo ~/luckfox-pico/build.sh
cd ~/luckfox-pico/output/image && sudo ~/luckfox-pico/output/image/blkenvflash ~/luckfox-pico/foxbuntu.img
echo "foxbuntu.img build completed."
cd ~/luckfox-pico
ls -ls foxbuntu.img
echo "use dd, raspi-imager (apply no custom settings), balenaEtcher(ignore error), to burn the image to a microSD card"
# End of script
exit 0
