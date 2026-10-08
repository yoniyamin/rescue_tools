#!/bin/bash
# rescue_menu.sh — Admin & Rescue Toolkit launcher (Debian / Refugio)

set -u

if [ -z "${DISPLAY:-}" ]; then
    echo "This menu must be run from the graphical desktop." >&2
    exit 1
fi

TERMINAL="${RESCUE_TERMINAL:-xfce4-terminal}"
# pkexec uses a restricted PATH; pip installs WoeUSB here.
PKEXEC_PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

show_error() {
    zenity --error --width=420 --text="$1" 2>/dev/null || echo "Error: $1" >&2
}

require_command() {
    local cmd="$1"
    local hint="$2"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        show_error "Cannot find '$cmd'.\n\nRun install_rescue_tools.sh or install package: $hint"
        exit 1
    fi
}

resolve_command() {
    local cmd="$1"
    local hint="$2"
    local exe
    exe=$(command -v "$cmd" 2>/dev/null) || {
        show_error "Cannot find '$cmd'.\n\nRun install_rescue_tools.sh or install package: $hint"
        exit 1
    }
    printf '%s' "$exe"
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
    local use_local_path="${3:-0}"
    local exe
    require_command pkexec "pkexec"
    exe=$(resolve_command "$cmd" "$hint")
    if [ "$use_local_path" = "1" ]; then
        pkexec env PATH="$PKEXEC_PATH" "$exe" \
            || show_error "Could not start $cmd.\n(Polkit prompt cancelled, access denied, or command not in pkexec PATH.)"
    else
        pkexec "$exe" \
            || show_error "Could not start $cmd.\n(Polkit prompt cancelled or access denied.)"
    fi
}

run_wireshark() {
    require_command wireshark "wireshark"
    if ! id -nG "${USER:-}" 2>/dev/null | grep -qw wireshark; then
        if zenity --question --width=440 \
            --title="Wireshark permissions" \
            --text="Capture may fail unless your user is in the 'wireshark' group.\n\nAdd $USER to that group now? (log out and back in afterward)" \
            2>/dev/null; then
            pkexec usermod -aG wireshark "${USER:?}" \
                && zenity --info --width=400 \
                    --text="Added to group 'wireshark'. Log out and back in, then start Wireshark again." \
                    2>/dev/null
            return 0
        fi
    fi
    wireshark &
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

pick_interface() {
    local dialog_title="$1"
    local ifaces=()
    local name

    require_command ip iproute2

    while IFS= read -r name; do
        [ -z "$name" ] && continue
        [ "$name" = "lo" ] && continue
        ifaces+=("$name")
    done < <(ip -o link show 2>/dev/null | awk -F': ' '{print $2}')

    if [ ${#ifaces[@]} -eq 0 ]; then
        show_error "No usable network interfaces found."
        exit 1
    fi

    zenity --list --title="$dialog_title" --text="Choose a network interface:" \
        --column="Interface" --width=360 --height=320 "${ifaces[@]}" 2>/dev/null
}

require_command zenity zenity

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
    "Storage" "7-Zip" "List or extract archives from the terminal" \
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
    "WoeUSB") run_pkexec woeusbgui "WoeUSB-ng (pip)" 1 ;;
    "Pi Imager")
        if ! command -v rpi-imager >/dev/null 2>&1; then
            if zenity --question --width=460 \
                --title="Pi Imager not installed" \
                --text="rpi-imager is not on this system (often missing from Refugio apt).\n\nOpen GNOME Disks to flash ISO/IMG instead?" \
                2>/dev/null; then
                run_gui gnome-disks gnome-disk-utility
            fi
        else
            run_gui rpi-imager rpi-imager
        fi
        ;;
    "GSmartControl") run_pkexec gsmartcontrol gsmartcontrol ;;
    "HardInfo") run_gui hardinfo hardinfo ;;
    "Zenmap") run_pkexec zenmap zenmap ;;
    "Grsync") run_gui grsync grsync ;;
    "Wireshark") run_wireshark ;;

    "Clonezilla") hold_sudo "Clonezilla" clonezilla ;;
    "TestDisk") hold_sudo "TestDisk" testdisk ;;
    "PhotoRec") hold_sudo "PhotoRec" photorec ;;
    "Gddrescue")
        hold_shell "Gddrescue" \
            "echo 'Example: sudo ddrescue -n /dev/sdX image.img mapfile'; echo 'List devices: lsblk'; echo; exec bash -l"
        ;;

    "7-Zip")
        require_command 7z p7zip-full
        ARCHIVE=$(zenity --file-selection --title="7-Zip — select an archive" 2>/dev/null) || exit 0
        if [ -z "$ARCHIVE" ]; then exit 0; fi
        hold_shell "7-Zip" "7z l $(printf '%q' "$ARCHIVE"); echo; echo 'Extract: 7z x archive -o/outdir'; exec bash -l"
        ;;

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
        IFACE=$(pick_interface "Tcpdump") || exit 0
        if [ -z "$IFACE" ]; then exit 0; fi
        hold_shell "Tcpdump — $IFACE" "sudo tcpdump -i $(printf '%q' "$IFACE") -n"
        ;;

    "ARP Scan")
        IFACE=$(pick_interface "ARP Scan") || exit 0
        if [ -z "$IFACE" ]; then exit 0; fi
        hold_sudo "ARP Scan — $IFACE" "arp-scan --interface=$(printf '%q' "$IFACE") --localnet"
        ;;

    "Root Terminal") hold_shell "Root shell" "sudo bash -l" ;;

    *)
        show_error "Unknown selection: $CHOICE"
        exit 1
        ;;
esac
