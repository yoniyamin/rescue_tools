#!/bin/bash
# rescue_menu.sh

if [ -z "$DISPLAY" ]; then
    echo "This menu must be run from the graphical desktop."
    exit 1
fi

CHOICE=$(zenity --list --title="Admin & Rescue Toolkit" \
    --text="Select a tool to launch:" \
    --column="Type" --column="Tool Name" --column="Description" \
    "GUI" "GParted" "Visual partition & drive manager" \
    "GUI" "Disks" "Format drives and flash standard ISO/IMG files" \
    "GUI" "WoeUSB" "Create bootable Windows USB installers" \
    "GUI" "Pi Imager" "Modern UI to download or flash OS images" \
    "GUI" "GSmartControl" "Check hard drive health and S.M.A.R.T. data" \
    "GUI" "HardInfo" "System profiler and hardware benchmark" \
    "GUI" "Zenmap" "Network scanner (Nmap frontend)" \
    "GUI" "Grsync" "File sync and backup" \
    "GUI" "Wireshark" "Network packet analyzer" \
    "Terminal" "Clonezilla" "Disk cloning and bare-metal imaging" \
    "Terminal" "TestDisk" "Partition and boot sector recovery" \
    "Terminal" "PhotoRec" "Deleted file and data recovery" \
    "Terminal" "MTR" "Live network routing diagnostics" \
    "System" "Root Terminal" "Open a root shell for chntpw, lvm2, and iperf3" \
    --width=750 --height=550)

if [ -z "$CHOICE" ]; then
    exit 0
fi

case "$CHOICE" in
    "GParted") pkexec gparted ;;
    "Disks") gnome-disks ;;
    "WoeUSB") pkexec woeusbgui ;;
    "Pi Imager") rpi-imager ;;
    "GSmartControl") pkexec gsmartcontrol ;;
    "HardInfo") hardinfo ;;
    "Zenmap") pkexec zenmap ;;
    "Grsync") grsync ;;
    "Wireshark") wireshark ;;
    "Clonezilla") xfce4-terminal --hold -e "sudo clonezilla" ;;
    "TestDisk") xfce4-terminal --hold -e "sudo testdisk" ;;
    "PhotoRec") xfce4-terminal --hold -e "sudo photorec" ;;
    "MTR") 
        TARGET=$(zenity --entry --title="MTR Diagnostic" --text="Enter IP or URL to trace:")
        if [ -n "$TARGET" ]; then
            xfce4-terminal --hold -e "sudo mtr $TARGET"
        fi
        ;;
    "Root Terminal") xfce4-terminal -e "sudo bash" ;;
    *) zenity --error --text="Invalid selection." ;;
esac