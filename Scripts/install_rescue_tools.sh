#!/bin/bash
# install_rescue_tools.sh — idempotent installer for Debian (e.g. Refugio)

set -e
set -u

pkg_installed() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'install ok installed'
}

pkg_available() {
    apt-cache show "$1" &>/dev/null
}

count_missing_installable() {
    local count=0
    local pkg
    for pkg in "$@"; do
        if pkg_installed "$pkg"; then
            continue
        fi
        if pkg_available "$pkg"; then
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
        if pkg_installed "$pkg"; then
            continue
        fi
        if ! pkg_available "$pkg"; then
            echo "$label: package '$pkg' is not in your apt sources; skipping."
            continue
        fi
        missing+=("$pkg")
    done
    if [ ${#missing[@]} -eq 0 ]; then
        echo "$label: already installed or nothing to install from apt, skipping."
        return 0
    fi
    echo "$label: installing ${#missing[@]} missing package(s)..."
    sudo apt install -y "${missing[@]}"
}

install_pkexec() {
    if command -v pkexec >/dev/null 2>&1 || pkg_installed pkexec; then
        echo "Polkit (pkexec): already available, skipping."
        return 0
    fi
    if pkg_available pkexec; then
        echo "Polkit (pkexec): installing pkexec..."
        sudo apt install -y pkexec
        return 0
    fi
    if pkg_available policykit-1; then
        echo "Polkit (pkexec): installing policykit-1 (legacy metapackage)..."
        sudo apt install -y policykit-1
        return 0
    fi
    echo "Warning: pkexec not found in apt (pkexec / policykit-1). GUI tools that need root may fail."
}

BASE_PKGS=(
    sudo iproute2
)
BUILD_PKGS=(
    build-essential pkg-config libgtk-3-dev python3-dev
    python3-pip python3-setuptools python3-wheel python3-wxgtk4.0
    git p7zip-full grub2-common grub-pc-bin
)
GUI_PKGS=(
    gparted zenmap grsync wireshark zenity
    gsmartcontrol hardinfo gnome-disk-utility
    xfce4-terminal
)
# Not in all Debian/Refugio apt sources (e.g. minimal live images).
OPTIONAL_GUI_PKGS=(
    rpi-imager
)
WOEUSB_APT_PKGS=(
    parted dosfstools ntfs-3g wimtools
)
RESCUE_PKGS=(
    clonezilla testdisk gddrescue zfsutils-linux
    tcpdump nmap rsync smartmontools lvm2 cryptsetup mtr iperf3 arp-scan chntpw
)
ALL_PKGS=("${BASE_PKGS[@]}" "${BUILD_PKGS[@]}" "${GUI_PKGS[@]}" "${OPTIONAL_GUI_PKGS[@]}" "${WOEUSB_APT_PKGS[@]}" "${RESCUE_PKGS[@]}")

missing_count=$(count_missing_installable "${ALL_PKGS[@]}")
if [ "$missing_count" -gt 0 ]; then
    echo "$missing_count installable package(s) missing; updating lists and fixing broken dependencies..."
    sudo apt update
    sudo apt --fix-broken install -y
else
    echo "All installable APT packages already present; skipping apt update."
fi

install_apt_group "Core system tools" "${BASE_PKGS[@]}"
install_apt_group "Build tools and Python dependencies" "${BUILD_PKGS[@]}"
install_apt_group "Graphical and system utilities" "${GUI_PKGS[@]}"
install_apt_group "Optional graphical tools" "${OPTIONAL_GUI_PKGS[@]}"
install_pkexec
install_apt_group "WoeUSB / filesystem helpers" "${WOEUSB_APT_PKGS[@]}"
install_apt_group "Terminal and rescue utilities" "${RESCUE_PKGS[@]}"

if ! command -v rpi-imager >/dev/null 2>&1; then
    echo ""
    echo "Pi Imager: not installed (package unavailable or skipped). Use 'Disks' in the Rescue Menu to flash ISO/IMG images."
fi

echo "Installing WoeUSB-ng for Windows USBs..."
if python3 -m pip show WoeUSB-ng &>/dev/null; then
    echo "WoeUSB-ng already installed, skipping pip."
else
    # The || prevents 'set -e' from halting if PEP-668 blocks the first attempt.
    sudo pip3 install WoeUSB-ng || sudo pip3 install WoeUSB-ng --break-system-packages
fi
if WOEUSB_BIN=$(command -v woeusbgui 2>/dev/null); then
    sudo ln -sf "$WOEUSB_BIN" /usr/local/bin/woeusbgui
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

if pkg_installed wireshark && ! id -nG "${USER:-}" 2>/dev/null | grep -qw wireshark; then
    echo ""
    echo "Wireshark: to capture without root, add your user to the wireshark group:"
    echo "  sudo usermod -aG wireshark $USER"
    echo "  (log out and back in afterward — or use the prompt in Rescue Menu when launching Wireshark)"
fi

echo "Installation complete! The Rescue Menu icon is now on your desktop."
