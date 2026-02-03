#!/bin/bash
###
# TODO: OpenWeathermap
# TODO: install and uninstall
# TODO: More modules and sensors
###

# Root/sudo check
if [ "$(id -u)" -ne 0 ]; then
    echo ' -->  ERROR ---------------- Please run as root or with sudo privileges ----------------' >&2
    exit 1
fi
# ------ End root/sudo check

if ! command -v nmcli >/dev/null 2>&1; then
    echo "ERROR: nmcli (NetworkManager) not found – is this Bookworm or Trixie?"
    exit 1
fi

function input_UI() {
    IP="0"
    PORT=""
    killall python3 # Kill all processes with python3 that is running.
    mkdir -p /usr/local/share/hydrosys4 # make sure installation directory is present
    
    echo "-->  Welcome to Hydrosys4 install script. The following initial settings are required:"
    while ! valid_ip $IP; do # IP part input
        read -p  "-->  Enter desired IPv4 address (range 192.168.1.100-192.168.1.200) or accept suggested IPv4 address by pressing [ENTER]: " -e -i 192.168.1.172 IP
        if valid_ip $IP; then stat='good'; 
            else stat='bad'; echo "-->  Please enter a valid IPv4 address, ex. 192.168.1.172"
        fi
    done
    echo "-->  Setting $IP as IPv4 address"

    while [[ ! $PORT =~ ^[0-9]+$ ]]; do # PORT part input
        read -p "-->  Enter desired PORT number or accept suggested by pressing [ENTER]: " -e -i 5172 PORT
        if [[ ! $PORT =~ ^[0-9]+$ ]]; then
            echo "-->  Please enter a valid PORT number, ex. 5172";
        fi
    done
    echo "-->  Setting $PORT as port number"
    
    read -p "-->  Enter desired WiFi AP name or accept suggested by pressing [ENTER]: " -e -i Hydrosys4 WiFiAPname # Local WiFi AP name and password setting
    echo "-->  Setting $WiFiAPname as WiFi AP name"
    read -p "-->  Enter desired WiFi AP password or accept suggested by pressing [ENTER]: " -e -i hydrosystem WiFiAPpsw
    echo "-->  Setting $WiFiAPpsw as WiFi password"
    read -p "-->  Do you wish to change hostname? (y,n): " -e -i y ChangeHostName
    #echo "  Confirmed Answer: "$ChangeHostName
    if [ "$ChangeHostName" == "y" ]; then
        read -p "-->  Enter desired hostname or accept suggested by pressing [ENTER]: " -e -i hydrosys4-172 NewHostName
        echo "-->  Setting $NewHostName as hostname"
        hostnamectl set-hostname $NewHostName # change the name in /etc/hostname
        aconf="/etc/hosts"
        cp /etc/hosts /usr/local/share/hydrosys4/hosts_hydrosys.backup
        sed -i "s/127.0.1.1.*/127.0.1.1 "$NewHostName"/" $aconf # Update hosts main config file
    fi
}

function valid_ip() {
    local  ip=$1
    local  stat=1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then # -- WIFI setup --- STANDARD
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

function system_update_UI() {
    while true; do
        read -p "-->  Do you wish to update and upgrade the Raspbian system (y/n)?" yn
        case $yn in
            [Yy]* ) system_update; echo "-->  Running a full system update and upgrade"; break;;
            [Nn]* ) system_update_light; echo "-->  Only running system update to fetch the latest packages"; break;;
            * ) echo "-->  Please answer y or n.";;
        esac
    done
}

function system_update() {
    apt update && apt -y upgrade
}

function system_update_light() {
    apt -y update # ---- system_update only
}

function install_dependencies() {
    echo "-->  Installing dependencies, APT packages" #--- start installing dependencies
    INSTALL_APT="python3-dev python3-pip python3-smbus git build-essential python3-setuptools i2c-tools fswebcam libjpeg-dev libopenjp2-7 cmake nginx iptables python3-rpi-lgpio liblgpio-dev"
    for pkg in $INSTALL_APT; do
        if dpkg --get-selections | grep -q "^$pkg[[:space:]]*install$" >/dev/null; then
            echo "-->  ---------------- $pkg already installed ----------------"
        else
            apt -y install $pkg || { echo "-->  APT ERROR: $pkg ---------------- Installation failed ----------------" && exit ;}
        fi
    done

    echo "-->  Installing dependencies, PIP3 packages"  
    INSTALL_PIP="flask apscheduler pyserial pillow pbkdf2 tornado spidev"
    for pkg in $INSTALL_PIP; do
        if python3 -c "import sys, pkgutil; sys.exit(not pkgutil.find_loader('$pkg'))"; then
            echo "-->  *---------------- $pkg already installed ----------------*"
        else
            pip3 install $pkg --break-system-packages || { echo "-->  PIP3 ERROR: $pkg ---------------- Installation failed ----------------" && exit ;}
        fi
    done
}

function uninstall() {
    REMOVE_APT="python3-dev python3-pip python3-smbus git build-essential python3-setuptools i2c-tools fswebcam libjpeg-dev libopenjp2-7 dnsutils dnsmasq hostapd cmake nginx python3-rpi-lgpio liblgpio-dev"
    REMOVE_PIP="flask apscheduler pyserial pillow pbkdf2 tornado RPi.GPIO rpi-lgpio spidev"
    echo "-->  Uninstalling APT and PIP3 packages"
    echo "-->  This will uninstall Hydrosys4 and all packages installed during installation including Nginx, Python 3 and Tornado, Flask aso."
    while true; do
        read -p "-->  Would you like to KEEP all packages (y/n)?" yn
        case $yn in
            [Yy]* )
                echo "-->  Keeping ALL packages, both APT and PIP3. Uninstall instruction: 'apt remove [package]' and 'pip3 uninstall [package]'."
                echo "-->  Installed APT packages: $REMOVE_APT"
                echo "-->  Installed PIP3 packages: $REMOVE_PIP"
                echo ""
                echo "-->  Uninstalling and reverting Hydrosys4. Changes made to files will be reverted to version backed up when installing Hydrosys4."
                echo "-->  Reverting changes made to /etc/hosts. Moving backed up config file to /etc/hosts. Saving running file to ~/hosts_hydrosys.backup"
                mv /etc/hosts ~/hosts_hydrosys.backup
                mv /usr/local/share/hydrosys4/hosts_hydrosys.backup /etc/hosts
                echo "-->  Reverting changes made to default zone file. Moving backed up file to /etc/nginx/sites-enabled/default. Saving running file to ~/nginx_hydrosys.backup"
                mv /etc/nginx/sites-enabled/default ~/nginx_hydrosys.backup
                mv /usr/local/share/hydrosys4/nginx_hydrosys.backup /etc/nginx/sites-enabled/default
                echo "-->  Cleanup hydrosys4 autostart service"
                systemctl stop hydrosys4-autostart.service
                systemctl disable hydrosys4-autostart.service
                rm -f /etc/systemd/system/hydrosys4-autostart.service
                echo "-->  Reverting changes made to /boot/firmware/config.txt. Moving backed up config file to /boot/firmware/config.txt. Saving running file to ~/boot_config_hydrosys.backup"
                mv /boot/firmware/config.txt ~/boot_config_hydrosys.backup
                mv /usr/local/share/hydrosys4/boot_config_hydrosys.backup /boot/firmware/config.txt
                echo "-->  Removing Hydrosys4 installation folder and configuration files."
                rm -rf /usr/local/share/hydrosys4
                ask_reboot
                break
                ;;
            [Nn]* )
                echo "-->  Removing ALL packages, both APT and PIP3 including all configurations"
                pip3 uninstall $REMOVE_PIP --break-system-packages || { echo "-->  PIP3 ERROR: ---------------- Uninstallation failed ----------------" && exit ;}
                apt -y remove --purge $REMOVE_APT || { echo "-->  APT ERROR: ---------------- Uninstallation failed ----------------" && exit ;}
                apt autoremove
                echo "-->  Uninstalling and reverting Hydrosys4. Changes made to files will be reverted to version backed up when installing Hydrosys4."
                echo "-->  Reverting changes made to /etc/hosts. Moving backed up config file to /etc/hosts. Saving running file to ~/hosts_hydrosys.backup"
                mv /etc/hosts ~/hosts_hydrosys.backup
                mv /usr/local/share/hydrosys4/hosts_hydrosys.backup /etc/hosts
                echo "-->  Reverting changes made to default zone file. Moving backed up file to /etc/nginx/sites-enabled/default. Saving running file to ~/nginx_hydrosys.backup"
                mv /etc/nginx/sites-enabled/default ~/nginx_hydrosys.backup
                mv /usr/local/share/hydrosys4/nginx.default /etc/nginx/sites-enabled/default
                echo "-->  Cleanup hydrosys4 autostart service"
                systemctl stop hydrosys4-autostart.service
                systemctl disable hydrosys4-autostart.service
                rm -f /etc/systemd/system/hydrosys4-autostart.service
                echo "-->  Reverting changes made to /boot/firmware/config.txt. Moving backed up config file to /boot/firmware/config.txt. Saving running file to ~/boot_config_hydrosys.backup"
                mv /boot/firmware/config.txt ~/boot_config_hydrosys.backup
                mv /usr/local/share/hydrosys4/boot_config_hydrosys.backup /boot/firmware/config.txt
                echo "-->  Removing Hydrosys4 installation folder and configuration files."
                rm -rf /usr/local/share/hydrosys4
                break
                ;;
            * )
                echo "-->  Please answer y or n."
                ;;
        esac
    done    

}

function install_mjpegstr() {
    aconf="/usr/local/share/hydrosys4/mjpg-streamer"
    if [ -f $aconf ]; then
       rm -rf /usr/local/share/hydrosys4/mjpg-streamer
    fi
    mkdir -p /usr/local/share/hydrosys4
    cd /usr/local/share/hydrosys4
    git clone https://github.com/jacksonliam/mjpg-streamer.git
    cd mjpg-streamer/mjpg-streamer-experimental
    make
    make install
}

function install_hydrosys4() {
    aconf="/usr/local/share/hydrosys4/env/autonom" # check if file exist in local folder
    if [ -d $aconf ]; then  # if the directory exist
        rm -rf /usr/local/share/hydrosys4/env
    else
        mkdir -p /usr/local/share/hydrosys4/env # --- INSTALL Hydrosys4 software
        cd /usr/local/share/hydrosys4/env
        git clone https://github.com/ChuckNorrison/Hydrosys.git
        mv Hydrosys autonom
    fi
}

function install_DHT22lib() {
    aconf="/usr/local/share/hydrosys4/env/autonom/libraries/DHT22/master.zip" # This is just going to install the library present in local folder
    if [ -f $aconf ]; then # --- installing the DHT22 Sensor libraries
        cd /usr/local/share/hydrosys4/env/autonom/libraries/DHT22
        unzip master.zip
        cd Adafruit_Python_DHT-master
        python3 setup.py install
    fi
}

function config_I2C() {
    echo "--> Enabling I2C, SPI (and optional I2S) via config.txt"

    local config_file="/boot/firmware/config.txt"
    local backup_file="/usr/local/share/hydrosys4/boot_config_hydrosys.backup"

    if [ ! -f "$config_file" ]; then
        echo "ERROR: $config_file not found. Is this a Raspberry Pi OS install?"
        return 1
    fi

    # Backup if not already done
    if [ ! -f "$backup_file" ]; then
        cp "$config_file" "$backup_file"
        echo "Backed up original config.txt"
    fi

    local changes_made=0

    # Helper to add line if missing
    add_if_missing() {
        local pattern="$1"
        local line="$2"
        if ! grep -qE "^${pattern}(=.*)?$" "$config_file"; then
            echo "$line" | sudo tee -a "$config_file" >/dev/null
            echo "Added: $line"
            changes_made=1
        else
            echo "Already present: $line"
        fi
    }

    # Enable I2C (standard for main bus on GPIO 2/3)
    add_if_missing "dtparam=i2c_arm=on" "dtparam=i2c_arm=on"

    # Enable SPI (main bus)
    add_if_missing "dtparam=spi=on" "dtparam=spi=on"

    # Optional: If you need user-space SPI devices (/dev/spidev*), add overlay
    # (common requirement for many sensors/scripts; safe to include)
    add_if_missing "dtoverlay=spi-spidev" "dtoverlay=spi-spidev"

    # Optional I2S – only if your project uses it
    # add_if_missing "dtparam=i2s=on" "dtparam=i2s=on"

    if [ $changes_made -eq 1 ]; then
        echo "Changes made to config.txt → reboot required for I2C/SPI to activate."
        echo "After reboot, verify with:"
        echo "  ls /dev/i2c*   # should show /dev/i2c-1 etc."
        echo "  ls /dev/spi*   # should show /dev/spidev* if overlay added"
        echo "  i2cdetect -y 1"
    else
        echo "No changes needed – I2C/SPI already configured."
    fi

    # Skip /etc/modules entirely – deprecated and unnecessary
    echo "Skipping /etc/modules edits (handled automatically via Device Tree in modern Pi OS)."
}

function config_iptables_ports() {
    # Switch to legacy iptables to ensure compatibility with old-style rules
    # (nftables is default in Debian 13 / Raspberry Pi OS Trixie)
    if command -v update-alternatives >/dev/null 2>&1; then
        sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
        sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
        sudo update-alternatives --set arptables /usr/sbin/arptables-legacy
        sudo update-alternatives --set ebtables /usr/sbin/ebtables-legacy
        echo "--> Switched to legacy iptables for compatibility"
    else
        echo "WARNING: update-alternatives not found – assuming legacy iptables is already in use"
    fi

    echo "--> Configuring firewall rules for ports 5020 and 5022 (localhost only)"

    # Flush existing INPUT chain to avoid duplicate rules on re-run
    iptables -F INPUT

    # Allow TCP 5020 only from localhost
    iptables -A INPUT -p tcp -s 127.0.0.1 --dport 5020 -j ACCEPT

    # Block TCP 5020 from everywhere else
    iptables -A INPUT -p tcp --dport 5020 -j DROP

    # Block TCP 5022 completely (including localhost)
    iptables -A INPUT -p tcp --dport 5022 -j DROP

    # Good practice: Allow established/related connections (prevents blocking return traffic)
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

    # Save rules for boot (used by ExecStartPre in service)
    iptables-save > /usr/local/share/hydrosys4/iptables.rules

    echo "--> Firewall rules for ports 5020/5022 applied and saved"
}

function config_systemd_hydrosys() {
    echo "--> Configuring systemd service for Hydrosys4 autostart"

    local service_file="/etc/systemd/system/hydrosys4-autostart.service"

    if [ -f "$service_file" ]; then
        echo "Service file already exists → backing up"
        cp "$service_file" /usr/local/share/hydrosys4/hydrosys4-autostart.service.backup
    fi

    cat > "$service_file" << 'EOF'
[Unit]
Description=Hydrosys4 Autostart (RTC + main application)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/usr/local/share/hydrosys4/env/autonom
ExecStartPre=/usr/sbin/iptables-restore /usr/local/share/hydrosys4/iptables.rules
ExecStartPre=/bin/sh -c 'echo "ds3231 0x68" > /sys/class/i2c-adapter/i2c-1/new_device || true'
ExecStartPre=/usr/sbin/hwclock -s || true
ExecStart=/usr/bin/python3 /usr/local/share/hydrosys4/env/autonom/bentornado.py
Restart=always
RestartSec=5
User=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    chmod 644 "$service_file"
    systemctl daemon-reload
    systemctl enable hydrosys4-autostart.service

    echo "Service installed and enabled. You can check status with:"
    echo "  systemctl status hydrosys4-autostart.service"
    echo "  journalctl -u hydrosys4-autostart -f"
}

# Configures the Raspberry Pi as a WiFi Access Point (Hotspot) using NetworkManager
# Clients connect to the SSID with the given password and get IPs via built-in DHCP
# The Pi gets IP 192.168.4.1/24 on wlan0 by default (shared method)
# Internet sharing works automatically if eth0 or another interface is online
function config_wifi_hotspot() {
    echo "--> Configuring WiFi Access Point (Hotspot) using NetworkManager"

    # Use variables from user input (adjust names if different in your script)
    local ssid="$WiFiAPname"               # e.g. "Hydrosys4-AP"
    local password="$WiFiAPpsw"       # WPA2 passphrase (min 8 chars)
    local hotspot_ip="${IP:-192.168.4.1}"  # Pi's IP on the hotspot network

    if [ -z "$ssid" ] || [ -z "$password" ]; then
        echo "ERROR: SSID or Password not set! (WIFI_AP_NAME / WIFI_AP_PASSWORD)"
        return 1
    fi

    if [ ${#password} -lt 8 ]; then
        echo "ERROR: Password must be at least 8 characters for WPA2!"
        return 1
    fi

    # Optional: Make sure no conflicting connection is active on wlan0
    local old_con
    old_con=$(nmcli -t -f NAME,DEVICE connection show | grep :wlan0 | cut -d: -f1 | head -n1)
    if [ -n "$old_con" ]; then
        echo "  → Deactivating previous wlan0 connection: $old_con"
        sudo nmcli connection down "$old_con" 2>/dev/null || true
    fi

    # Remove any existing hotspot connection with the same SSID to avoid conflicts
    sudo nmcli connection delete "$ssid" 2>/dev/null || true

    # Create the hotspot connection
    sudo nmcli connection add \
        type wifi \
        ifname wlan0 \
        con-name "$ssid" \
        autoconnect yes \
        ssid "$ssid" \
        802-11-wireless.mode ap \
        802-11-wireless.band bg \
        ipv4.method shared \
        ipv4.addresses "${hotspot_ip}/24" \
        ipv6.method ignore

    # Set WPA2-PSK security (most compatible and secure option)
    sudo nmcli connection modify "$ssid" \
        wifi-sec.key-mgmt wpa-psk \
        wifi-sec.psk "$password"

    # Optional: Fix a channel to reduce interference (1,6,11 are good choices)
    # sudo nmcli connection modify "$ssid" 802-11-wireless.channel 6

    # Optional: Stronger security (WPA3/WPA2 mixed mode, if clients support it)
    # sudo nmcli connection modify "$ssid" wifi-sec.proto rsn wifi-sec.pairwise ccmp

    # Activate the hotspot
    sudo nmcli connection up "$ssid"

    if [ $? -eq 0 ]; then
        echo "  → SUCCESS: Hotspot '$ssid' is now active!"
        echo "  → Pi IP on hotspot network: $hotspot_ip"
        echo "  → Clients connect to SSID '$ssid' with password '$password'"
        echo "  → DHCP range: usually 192.168.4.100 – 192.168.4.200"
        echo "  → Check status: nmcli device show wlan0"
        echo "  → Or: nmcli connection show --active"
    else
        echo "ERROR: Failed to activate hotspot. Check logs: journalctl -u NetworkManager"
    fi
}

function config_ifnames() {
    aconf="/boot/cmdline.txt" # this is to preserve the network interfaces names, becasue staring from debian stretch (9) the ifnames have new rules
    APPEND=' net.ifnames=0'
    echo "$(cat $aconf)$APPEND" > $aconf
}

function config_nginx() {
    echo "-->  Configuring Nginx server settings and default zone file"
    aconf="/etc/nginx/sites-enabled/default" # create default file
    if [ -f $aconf ]; then
        mv $aconf /usr/local/share/hydrosys4/nginx_hydrosys.backup
        echo "-->  Backed up /etc/nginx/sites-enabled/default to /usr/local/share/hydrosys4/nginx_hydrosys.backup"
    fi
    bash -c "cat >> $aconf" <<-EOF
server {
    # for a public HTTP server:
    listen $PORT;
    server_name localhost;

    access_log off;
    error_log off;

    location / {
        proxy_pass http://127.0.0.1:5020;
    }

    location /stream {
        rewrite ^/stream/(.*) /$1 break;
        proxy_pass http://127.0.0.1:5022;
        proxy_buffering off;
    }

    location /static/download/configdownload/emailcred.txt {
        return 302 https://$host:$server_port;
    }        

    location /static/download/configdownload/logincred.txt {
        return 302 https://$host:$server_port;
    }    

    location /favicon.ico {
        alias /usr/local/share/hydrosys4/env/autonom/static/favicon.ico;
    }
}
EOF
    systemctl restart nginx
}

function config_defaultnetworkdb() {
    aconf="/usr/local/share/hydrosys4/env/autonom/database/default/defnetwork.txt "
    if [ -f $aconf ]; then # if file already exist then no action, otherwise create it
        echo "-->  Default network file already exist, no changes where made"
    else
        bash -c "cat >> $aconf" <<-EOF
{"name": "IPsetting", "LocalIPaddress": "192.168.0.172", "LocalPORT": "5012" , "LocalAPSSID" : "Hydrosys4"}
EOF
    fi
}

function ask_reboot() {
    read -p "-->  Do you want to reboot the system, required for all changes to be applied? (y,n): " -e -i y doreboot
    echo "  Confirmed Answer: "$doreboot
    if [ "$doreboot" == "y" ]; then
        reboot
    fi
}

function show_help() {
    cat <<-EOF
Usage: ${0##*/} [-i] [-u] [-h]...
Please use one of options given below to continue

        -h|-help       Display this help and exit
        -i|-install    Install Hydrosys4
        -u|-uninstall  Completely remove Hydrosys4 and revert all changes
        -d|-debug      Log install or uninstall actions to debug_messages.log
EOF
}

while :; do
    case $1 in
        -h|-\?|--help)
            show_help
            exit 1
            ;;
        -d|-debug|--debug)
            exec 5> debug_messages.log
            BASH_XTRACEFD="5"
            set -x
            ;;
        -i|-install|--install)
            input_UI
            system_update_UI
            install_dependencies
            install_hydrosys4 # this should be called before the DHT22 due to local library references
            install_mjpegstr
            install_DHT22lib
            config_I2C
            config_systemd_hydrosys
            config_wifi_hotspot
            config_ifnames
            config_nginx
            config_defaultnetworkdb
            config_iptables_ports
            ask_reboot
            exit 1
            ;;
        -u|-uninstall|--uninstall)
            uninstall
            exit 1
            ;;
        --) # End of all options.
            shift
            break
            ;;
        -?*)
            printf 'WARNING: Unknown option: %s\n\n' "$1" >&2
            show_help
            exit 1
            ;;
        *)
            printf "ERROR: No option given, exiting\n\n" >&2
            show_help
            exit 1
            ;;
    esac
    shift
done
