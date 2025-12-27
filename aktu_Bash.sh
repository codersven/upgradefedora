#!/bin/bash

clear
#set -e # Keep to stop the script in case of errors (good practice)

echo "-------------------------------------"
echo "Updates and maintenance for Fedora"
echo "-------------------------------------"

# --- 1. Systemstatus und Begrüßung ---

# Checking whether there is an internet connection
A=$(nmcli device status | grep eno1 | awk '{print $3}')

if [[ "$A" == "verbunden" ]]; then
    echo "✅ Internet connection available on eno1."
else
    echo "❌ NO Internet connection available, check your router."
fi


# Printing the current date
DATUM=$(date +%x)
EINSCHALTZEIT=$(uptime -s | awk '{print $2}')

echo "Hallo $USER, heute ist der $DATUM. Der Rechner wurde um $EINSCHALTZEIT eingeschaltet."
echo

# Checking whether I'm root or not. I need to be root in order to run this script
BENUTZER="$USER"
if [[ "$BENUTZER" == "root" ]]; then
    echo "Ich bin Root. Starte Wartungsprozesse."
    
    # ----------------------------------------------------
    # 🛑 NEU: Status of databases and Node.js (Fits perfectly here!)
    echo "----------------------------------------------------"
    echo "Review of ongoing database and development processes"
    echo "----------------------------------------------------"

    # MariaDB Check
    if systemctl is-active mariadb &> /dev/null; then
        echo "✅ MariaDB: Database server is running."
    else
        echo "❌ MariaDB: Database server is inactive."
    fi

    # MongoDB Check
    if systemctl is-active mongod &> /dev/null; then
        echo "✅ MongoDB: Database server is running."
    else
        echo "❌ MongoDB: Database server is inactive."
    fi

    # Node.js Check
    NODE_COUNT=$(pgrep node | wc -l)
    if [ "$NODE_COUNT" -gt 0 ]; then
        echo "⚠️ Node.js: $NODE_COUNT Node.js processes are currently running!"
        # Auflistung der PIDs, falls nötig
        pgrep node
    else
        echo "✅ Node.js: No active Node.js processes found."
    fi
    echo "----------------------------------------------------"


    # --- 2. Maintenance and updates ---


    echo "----------------------------------------------------"
echo "Preliminary check: kernel updates & boot memory"
echo "----------------------------------------------------"

# 1. check whether there is a new kernel
KERNEL_UPDATE=$(dnf check-update kernel -q)

if [ -n "$KERNEL_UPDATE" ]; then
    echo "🆕 A new kernel update has been found!"
    
    # 2. check the size in /boot
    BOOT_AVAIL=$(df -m /boot --output=avail | tail -1 | tr -d ' ')
    
    # Safety margin: A new kernel requires approximately 150 MB.
    # (including reserve for generating initramfs)
    SCHWELLE=200 

    echo "Verfügbarer Platz in /boot: ${BOOT_AVAIL} MB"

    if [ "$BOOT_AVAIL" -lt "$SCHWELLE" ]; then
        echo "❌ CANCEL: The space in /boot is too less (${BOOT_AVAIL} MB)!"
        echo "A kernel update requires approximately 150-200 MB of free buffer space."
        echo
        echo "Please execute this command first to make space:"
        echo "sudo dnf remove \$(dnf repoquery --installonly --latest-limit=-2 -q)"
        echo
        exit 1
    else
        echo "✅ Sufficient space available for the kernel update."
    fi
else
    echo "✅ No kernel update in queue. Normal update will continue.""
fi

echo "----------------------------------------------------"


    
    # query new updates
    echo "Starte Update-Anfrage..."
    # Da das Skript bereits als Root läuft, ist 'sudo' nicht nötig
    dnf upgrade -y --refresh --exclude=ffmpeg-free
    
    echo "----------------------------------------------"
    
    # checking to rootkits
    echo "Checking Rootkits (chkrootkit)"
    # '| true' ist gut, um sicherzustellen, dass das Skript nicht stoppt
    chkrootkit 2>/dev/null  || true
    
    
    echo "----------------------------------------------"
    echo "Kontrolle der installierten Kernel"
    # Counts the lines of the installed kernel packages
    KERNEL_ANZAHL=$(rpm -q kernel | wc -l)
    echo "Aktuell sind $KERNEL_ANZAHL Kernel installiert:"
    rpm -q kernel

    # Small warning message if the limit (3) is exceeded
    if [ "$KERNEL_ANZAHL" -gt 3 ]; then
        echo "⚠️ Hinweis: Mehr als 3 Kernel installiert. Prüfen Sie die dnf.conf!"
    fi
    echo "----------------------------------------------"



    echo "----------------------------------------------"
    # kernel errors
    echo "Prüfung auf Kernel-Fehler im letzten Boot-Vorgang:"
    journalctl -kb -1 | grep -i 'kernel panic\|BUG:\|oops\|segfault\|NMI watchdog'
    
    echo "----------------------------------------------"
    
    # journalctl size check and vacuum
    echo "Prüfung Journal-Loggröße:"
    journalctl --disk-usage
    
    echo "Journal Logfiles löschen (älter als 1 Tag)"
    journalctl --vacuum-time=1d
    
    echo "----------------------------------------------"
    
    # delete the dnf cache
    echo "DNF Cache löschen"
    dnf clean packages
    dnf clean metadata
    dnf clean dbcache

    echo "----------------------------------------------"
    
    
    # checking the /tmp folder size (Kann wegen systemd-tmpfiles-clean entfernt werden, aber der Check schadet nicht)
    TMP_SIZE_KB=$(du -sk /tmp/ | awk '{print $1}')
    THRESHOLD_KB=400 # 400 KB
    
    echo "Prüfung /tmp Ordnergröße"

    if (( TMP_SIZE_KB > THRESHOLD_KB )); then
            echo "⚠️ Warnung: /tmp ist größer als $THRESHOLD_KB KB. Aktuelle Größe: $TMP_SIZE_KB KB"
    else
            echo "✅ Die Größe von /tmp ist unter $THRESHOLD_KB KB. Aktuelle Größe: $TMP_SIZE_KB KB"
    fi
    
        
    echo "---------------------------------------------"
    
    # Check DNF cache size
    ORDNER_DNF="/var/cache/dnf"
    SIZE_MB_DNF=$(du -sm "$ORDNER_DNF" | cut -f1)
    LIMIT_MB_DNF=1024 # 1 GB

    echo "Prüfung DNF Cache Größe:"
    echo "Aktuelle DNF Cache Größe: $(du -sh "$ORDNER_DNF" | cut -f1)"

    if [ "$SIZE_MB_DNF" -gt "$LIMIT_MB_DNF" ]; then
            echo "Achtung: Der Ordner '$ORDNER_DNF' ist größer als 1 GB."
    else
            echo "✅️ Der Ordner '$ORDNER_DNF' ist unter 1 GB."
    fi
    
    echo 
    
    
    
    echo "---------------------------------------------"
    
    # Check the size of /var/log
    ORDNER_LOG="/var/log"
    SIZE_MB_LOG=$(du -sm "$ORDNER_LOG" | cut -f1)
    LIMIT_MB_LOG=1024 # 1 GB

    echo "Prüfung /var/log Ordnergröße:"
    echo "Aktuelle /var/log Größe: $(du -sh "$ORDNER_LOG" | cut -f1)"

    if [ "$SIZE_MB_LOG" -gt "$LIMIT_MB_LOG" ]; then
            echo "Achtung: Der Ordner '$ORDNER_LOG' ist größer als 1 GB."
    else
            echo "✅ Der Ordner '$ORDNER_LOG' ist unter 1 GB."
    fi
    echo 
    
    echo "----------------------------------------------"
    echo
    
        
    echo "Finish, Ende, an die Arbeit 💼️"
    
else
    echo "❌ Error: I currently do not have root privileges. The update script requires root privileges."
fi
