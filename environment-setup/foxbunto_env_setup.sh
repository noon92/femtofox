echo “Setting up Foxbuntu build environment…”

#echo 'Defaults timestamp_timeout=180' | sudo EDITOR='tee -a' visudo
{ echo 'Defaults timestamp_timeout=180' | sudo EDITOR='tee -a' visudo; } > /dev/null 2>&1

start_time=$(date +%s)

sudo apt update

sudo apt-get install -y git ssh make gcc gcc-multilib g++-multilib module-assistant expect g++ gawk texinfo libssl-dev bison flex fakeroot cmake unzip gperf autoconf device-tree-compiler libncurses5-dev pkg-config bc python-is-python3 passwd openssl openssh-server openssh-client vim file cpio rsync

git clone https://github.com/LuckfoxTECH/luckfox-pico.git

cd ~/luckfox-pico
sudo ./build.sh lunch
sudo ./build.sh
cd ~
git clone https://github.com/noon92/femtofox.git
~/femtofox/foxbuntu/updatefs.sh
cd ~/luckfox-pico/

sudo ./build.sh kernelconfig
sudo ./build.sh

cd ~/luckfox-pico/output/image

sudo wget https://gist.github.com/Spiritdude/da36d2cf064e49094c870e0a8b9f972f/archive/8f05ce57f5dede06a45f25298982fab543d95084.zip

sudo unzip -j ./8f05ce57f5dede06a45f25298982fab543d95084.zip
sudo rm ./8f05ce57f5dede06a45f25298982fab543d95084.zip
sudo chmod +x ./blkenvflash



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

sudo chroot ~/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106 /bin/bash <<EOF
echo "Inside chroot environment..."
echo "tmpfs /run tmpfs rw,nodev,nosuid,size=32M 0 0" | sudo tee -a /etc/fstab

# Commented out until segfault in newer packages is fixed.
##wget -qO- https://meshtastic.github.io/meshtastic-deb.asc | sudo tee /etc/apt/keyrings/meshtastic-deb.asc >/dev/null
#echo "deb [arch=all signed-by=/etc/apt/keyrings/meshtastic-deb.asc] https://meshtastic.github.io/deb stable main" | sudo tee /etc/apt/sources.list.d/meshtastic-deb.list >/dev/null

ln -s /dev/null /etc/udev/rules.d/80-net-setup-link.rules

touch /lib/modules/5.10.160/modules.order
touch /lib/modules/5.10.160/modules.builtin
depmod -a 5.10.160

rm /etc/localtime
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

apt update

DEBIAN_FRONTEND=noninteractive apt install -y --option Dpkg::Options::="--force-confold" linux-firmware wireless-tools git python3.10-venv libgpiod-dev libyaml-cpp-dev libbluetooth-dev openssl libssl-dev libulfius-dev liborcania-dev evtest screen avahi-daemon protobuf-compiler telnet fonts-noto-color-emoji ninja-build


DEBIAN_FRONTEND=noninteractive apt upgrade -y --option Dpkg::Options::="--force-confold"

wget https://github.com/meshtastic/firmware/releases/download/v2.5.11.8e2a3e5/meshtasticd_2.5.11.8e2a3e5_armhf.deb

DEBIAN_FRONTEND=noninteractive apt install -y --option Dpkg::Options::="--force-confold" ./meshtasticd_2.5.11.8e2a3e5_armhf.deb

pip3 install requests pyephem pytap2 meshtastic pypubsub geopy maidenhead beautifulsoup4 dadjokes schedule wikipedia googlesearch-python

mv /etc/update-motd.d/10-help-text /etc/update-motd.d/10-help-text.bak
mv /etc/update-motd.d/60-unminimize /etc/update-motd.d/60-unminimize.bak

systemctl enable button
systemctl enable wifi-mesh-control

systemctl disable NetworkManager
systemctl disable NetworkManager-dispatcher
sudo systemctl disable NetworkManager-wait-online

echo "femtofox" | sudo tee /etc/hostname > /dev/null

systemctl disable vsftpd.service
systemctl disable ModemManager.service
systemctl disable getty@tty1.service
systemctl disable acpid
systemctl disable acpid.socket
systemctl disable acpid.service
systemctl mask alsa-restore.service
systemctl disable alsa-restore.service
systemctl disable alsa-state.service
systemctl mask sound.target
systemctl disable sound.target
systemctl disable veritysetup.target
systemctl disable systemd-pstore.service

groupmod -n femto pico
usermod -l femto pico
usermod -aG sudo,input femto
echo "femto ALL=(ALL:ALL) ALL" | sudo tee /etc/sudoers.d/femto > /dev/null
chmod 440 /etc/sudoers.d/femto
find / -group pico -exec chgrp femto {} \; 2>/dev/null
sudo find / -user pico -exec chown femto {} \; 2>/dev/null
usermod -d /home/femto -m femto
ls -ld /home/femto
echo 'femto:fox' | chpasswd
usermod -a -G tty femto
usermod -a -G dialout femto

apt clean && rm -rf /var/lib/apt/lists/* && rm -rf /tmp/* && rm -rf /var/tmp/* && find /var/log -type f -exec truncate -s 0 {} + && : > /root/.bash_history && history -c
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
ls ~/luckfox-pico/foxbuntu.img

#sudo sed -i '/Defaults timestamp_timeout=180/d' /etc/sudoers
{ sudo sed -i '/Defaults timestamp_timeout=180/d' /etc/sudoers; } > /dev/null 2>&1

end_time=$(date +%s)
elapsed=$(( end_time - start_time ))

# Format elapsed time as HH:MM:SS
hours=$(( elapsed / 3600 ))
minutes=$(( (elapsed % 3600) / 60 ))
seconds=$(( elapsed % 60 ))

printf "Build execution time: %02d:%02d:%02d\n" $hours $minutes $seconds



