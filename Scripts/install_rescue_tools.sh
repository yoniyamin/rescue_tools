#!/bin/bash
# install_rescue_tools.sh — idempotent installer for Debian (e.g. Refugio)

set -e
set -u

pkg_installed() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'install ok installed'
}

count_missing() {
    local count=0
    local pkg
    for pkg in "$@"; do
        if ! pkg_installed "$pkg"; then
            ((count++)) || true
        fi
    done
    echo "$count"
}

install_apt_group() {
    local label="$1"
    shift
    local missing=()
    local pkg
    for pkg in "$@"; do
        if ! pkg_installed "$pkg"; then
            missing+=("$pkg")
        fi
    done
    if [ ${#missing[@]} -eq 0 ]; then
        echo "$label: already installed, skipping."
        return 0
    fi
    echo "$label: installing ${#missing[@]} missing package(s)..."
    sudo apt install -y "${missing[@]}"
}

BUILD_PKGS=(
    build-essential pkg-config libgtk-3-dev python3-dev
    python3-pip python3-setuptools python3-wheel python3-wxgtk4.0
    git p7zip-full grub2-common grub-pc-bin
)
GUI_PKGS=(
    gparted zenmap grsync wireshark zenity
    gsmartcontrol hardinfo gnome-disk-utility rpi-imager
    xfce4-terminal policykit-1
)
WOEUSB_APT_PKGS=(
    parted dosfstools ntfs-3g wimtools
)
RESCUE_PKGS=(
    clonezilla testdisk gddrescue zfsutils-linux
    tcpdump nmap rsync smartmontools lvm2 cryptsetup mtr iperf3 arp-scan chntpw
)
ALL_PKGS=("${BUILD_PKGS[@]}" "${GUI_PKGS[@]}" "${WOEUSB_APT_PKGS[@]}" "${RESCUE_PKGS[@]}")

missing_count=$(count_missing "${ALL_PKGS[@]}")
if [ "$missing_count" -gt 0 ]; then
    echo "$missing_count package(s) not installed; updating lists and fixing broken dependencies..."
    sudo apt update
    sudo apt --fix-broken install -y
else
    echo "All APT packages already installed; skipping apt update."
fi

install_apt_group "Build tools and Python dependencies" "${BUILD_PKGS[@]}"
install_apt_group "Graphical and system utilities" "${GUI_PKGS[@]}"
install_apt_group "WoeUSB / filesystem helpers" "${WOEUSB_APT_PKGS[@]}"
install_apt_group "Terminal and rescue utilities" "${RESCUE_PKGS[@]}"

echo "Installing WoeUSB-ng for Windows USBs..."
if python3 -m pip show WoeUSB-ng &>/dev/null; then
    echo "WoeUSB-ng already installed, skipping pip."
else
    # The || prevents 'set -e' from halting if PEP-668 blocks the first attempt.
    sudo pip3 install WoeUSB-ng || sudo pip3 install WoeUSB-ng --break-system-packages
fi

MENU_SCRIPT="$HOME/rescue_tools/Scripts/rescue_menu.sh"
if [ -f "$MENU_SCRIPT" ]; then
    chmod +x "$MENU_SCRIPT"
else
    echo "Note: $MENU_SCRIPT not found — clone the repo to ~/rescue_tools before using the menu."
fi

DESKTOP_FILE="$HOME/Desktop/RescueMenu.desktop"
EXPECTED_EXEC="$MENU_SCRIPT"

echo "Creating desktop shortcut..."
if [ -f "$DESKTOP_FILE" ] && grep -qF "Exec=$EXPECTED_EXEC" "$DESKTOP_FILE"; then
    echo "Desktop shortcut already present, skipping."
else
    mkdir -p "$(dirname "$DESKTOP_FILE")"
    cat <<EOF > "$DESKTOP_FILE"
[Desktop Entry]
Version=1.0
Type=Application
Name=Rescue Menu
Comment=Admin & Rescue Toolkit
Exec=$EXPECTED_EXEC
Icon=utilities-system-monitor
Terminal=false
StartupNotify=true
EOF
    echo "Desktop shortcut created or updated."
fi

chmod +x "$DESKTOP_FILE"

echo "Installation complete! The Rescue Menu icon is now on your desktop."
