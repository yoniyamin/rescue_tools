#!/bin/bash
# rescue_menu.sh — Admin & Rescue Toolkit launcher (Debian / Refugio)

set -u

if [ -z "${DISPLAY:-}" ]; then
    echo "This menu must be run from the graphical desktop." >&2
    exit 1
fi

TERMINAL="${RESCUE_TERMINAL:-xfce4-terminal}"

show_error() {
    zenity --error --width=420 --text="$1" 2>/dev/null || echo "Error: $1" >&2
}

require_command() {
    local cmd="$1"
    local hint="$2"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        show_error "Cannot find <b>$cmd</b>.\n\nRun <i>install_rescue_tools.sh</i> or install: <b>$hint</b>."
        exit 1
    fi
}

run_gui() {
    local cmd="$1"
    local hint="$2"
    require_command "$cmd" "$hint"
    "$cmd" &
}

run_pkexec() {
    local cmd="$1"
    local hint="$2"
    require_command pkexec "policykit-1"
    require_command "$cmd" "$hint"
    pkexec "$cmd" || show_error "Could not start <b>$cmd</b>.\n(Polkit prompt cancelled or access denied.)"
}

hold_shell() {
    local title="$1"
    local command_line="$2"
    require_command "$TERMINAL" xfce4-terminal
    "$TERMINAL" --hold -T "$title" -e "bash -lc $(printf '%q' "$command_line")" &
}

hold_sudo() {
    hold_shell "$1" "sudo $2"
}

ask_target() {
    local title="$1"
    local prompt="$2"
    local default="${3:-}"
    zenity --entry --title="$title" --text="$prompt" --entry-text="$default" 2>/dev/null
}

valid_host() {
    local target="$1"
    [[ "$target" =~ ^[A-Za-z0-9._:/-]+$ ]]
}

CHOICE=$(zenity --list \
    --title="Admin & Rescue Toolkit" \
    --text="Pick a tool to launch. Use the list search box to filter." \
    --width=820 --height=580 \
    --column="Category" --column="Tool" --column="Description" \
    --hide-column=1 --print-column=2 \
    "Storage" "GParted" "Visual partition and drive manager" \
    "Storage" "Disks" "Format drives and flash ISO/IMG images" \
    "Storage" "WoeUSB" "Create bootable Windows USB installers" \
    "Storage" "Pi Imager" "Download or flash Raspberry Pi and other OS images" \
    "Storage" "GSmartControl" "Drive health and S.M.A.R.T. reports" \
    "Storage" "Clonezilla" "Disk cloning and bare-metal imaging" \
    "Storage" "TestDisk" "Partition table and boot sector recovery" \
    "Storage" "PhotoRec" "Recover deleted files and lost data" \
    "Storage" "Gddrescue" "Rescue data from failing drives (ddrescue)" \
    "Network" "Zenmap" "Graphical Nmap network scanner" \
    "Network" "Wireshark" "Capture and analyze network traffic" \
    "Network" "Grsync" "Graphical rsync backup and sync" \
    "Network" "MTR" "Live traceroute and packet loss diagnostics" \
    "Network" "Nmap" "Command-line port and host scanner" \
    "Network" "iperf3" "Throughput test to another iperf3 server" \
    "Network" "Tcpdump" "Capture packets from the command line" \
    "Network" "ARP Scan" "Discover hosts on the local network" \
    "System" "HardInfo" "Hardware inventory and benchmarks" \
    "System" "Root Terminal" "Root shell for LVM, cryptsetup, chntpw, ZFS, etc." \
    2>/dev/null) || exit 0

if [ -z "$CHOICE" ]; then
    exit 0
fi

case "$CHOICE" in
    "GParted") run_pkexec gparted gparted ;;
    "Disks") run_gui gnome-disks gnome-disk-utility ;;
    "WoeUSB") run_pkexec woeusbgui "WoeUSB-ng (pip)" ;;
    "Pi Imager") run_gui rpi-imager rpi-imager ;;
    "GSmartControl") run_pkexec gsmartcontrol gsmartcontrol ;;
    "HardInfo") run_gui hardinfo hardinfo ;;
    "Zenmap") run_pkexec zenmap zenmap ;;
    "Grsync") run_gui grsync grsync ;;
    "Wireshark") run_gui wireshark wireshark ;;

    "Clonezilla") hold_sudo "Clonezilla" clonezilla ;;
    "TestDisk") hold_sudo "TestDisk" testdisk ;;
    "PhotoRec") hold_sudo "PhotoRec" photorec ;;
    "Gddrescue") hold_sudo "Gddrescue" ddrescue ;;

    "MTR")
        TARGET=$(ask_target "MTR" "Host or IP to trace:")
        if [ -z "$TARGET" ]; then exit 0; fi
        if ! valid_host "$TARGET"; then
            show_error "Invalid host or IP."
            exit 1
        fi
        hold_shell "MTR — $TARGET" "sudo mtr -- $(printf '%q' "$TARGET")"
        ;;

    "Nmap")
        TARGET=$(ask_target "Nmap" "Host, IP, or CIDR to scan:" "192.168.1.0/24")
        if [ -z "$TARGET" ]; then exit 0; fi
        if ! valid_host "$TARGET"; then
            show_error "Invalid scan target."
            exit 1
        fi
        hold_shell "Nmap — $TARGET" "sudo nmap -Pn $(printf '%q' "$TARGET")"
        ;;

    "iperf3")
        SERVER=$(ask_target "iperf3" "Server IP or hostname:" "192.168.1.1")
        if [ -z "$SERVER" ]; then exit 0; fi
        if ! valid_host "$SERVER"; then
            show_error "Invalid server address."
            exit 1
        fi
        hold_shell "iperf3 — $SERVER" "iperf3 -c $(printf '%q' "$SERVER")"
        ;;

    "Tcpdump")
        IFACE=$(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | zenity --list \
            --title="Tcpdump" --text="Choose a network interface:" \
            --column="Interface" --width=360 --height=320 2>/dev/null) || exit 0
        if [ -z "$IFACE" ]; then exit 0; fi
        hold_shell "Tcpdump — $IFACE" "sudo tcpdump -i $(printf '%q' "$IFACE") -n"
        ;;

    "ARP Scan")
        IFACE=$(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | zenity --list \
            --title="ARP Scan" --text="Choose a network interface:" \
            --column="Interface" --width=360 --height=320 2>/dev/null) || exit 0
        if [ -z "$IFACE" ]; then exit 0; fi
        hold_sudo "ARP Scan — $IFACE" "arp-scan --interface=$(printf '%q' "$IFACE") --localnet"
        ;;

    "Root Terminal") hold_shell "Root shell" "sudo bash -l" ;;

    *)
        show_error "Unknown selection: $CHOICE"
        exit 1
        ;;
esac
