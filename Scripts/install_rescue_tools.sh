#!/bin/bash
# install_rescue_tools.sh

echo "Updating package lists..."
sudo apt update

echo "Installing graphical and system utilities..."
# Installs core GUI tools, health monitors, and USB flashing apps
sudo apt install -y gparted zenmap grsync wireshark zenity gsmartcontrol \
    hardinfo gnome-disk-utility rpi-imager git p7zip-full python3-pip \
    python3-wxgtk4.0 grub2-common grub-pc-bin

echo "Installing terminal & rescue utilities..."
# Installs data recovery, networking, ZFS, and password reset tools
sudo apt install -y clonezilla testdisk gddrescue zfsutils-linux tcpdump \
    nmap rsync smartmontools lvm2 cryptsetup mtr iperf3 arp-scan chntpw

echo "Installing WoeUSB-ng for Windows USBs..."
# On newer Debian versions, pip requires the break-system-packages flag for global installs
sudo pip3 install WoeUSB-ng || sudo pip3 install WoeUSB-ng --break-system-packages

echo "Installation complete!"