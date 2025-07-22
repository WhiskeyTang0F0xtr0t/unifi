> [!CAUTION]
> If the installed version of the Network app is newer than the version in a Unifi OS update, it may need to download the newer version of the Network app before it can restore your configuration.
> 
> You may need to SSH into your device and run ``` wtf-wpa.sh -i ``` to repair the wpa_supplicant service and allow it to download the update.
> 
> Example: The UniFi OS 4.1.13 update is bundled with UniFi Network 8.6.9, but I had 9.0.108 installed already and had to do the process above.
> 



# Table of Contents
- [Overview](#overview)
- [Supported Devices](#supported-devices)
- [Getting Started](#getting-started)
- [Initial Deployment](#initial-deployment)
- [Updating Script](#updating-script)
- [Usage](#usage)
- [Example Files](#example-files)
- [Future Plans](#future-plans)

# Overview
A tool to setup the wpa_supplicant service for AT&T Residential Gateway Bypass on Ubiquiti hardware.

### Features:
- Made for Ubiquiti hardware, but could be tweaked to work on other platforms that support wpa_supplicant
- Verifies all needed files are available(certs, pkgs) and variables are set
- Installs and configures wpa_supplicant service with "restart on failure" enabled
- Creates "auto recovery" service that leverages $backupPath to re-install and configure wpa_supplicant after Unifi OS update/upgrade
- Optional external variable file support

# Supported Devices
This script should work on any UniFi hardware running their modern OS and been confirmed working on the following hardware:
- Dream Machine (UDM) (u/-BruceWayne-)
- Dream Machine Pro (UDM-Pro)
- Dream Machine Special Edition
- Dream Machine Pro Max (UDM-Pro-Max)
- Cloud Gateway Ultra (UCG-Ultra)
- Cloud Gateway Fiber (UCG-Fiber) (u/-BruceWayne-)
- UniFi Express (UX)
- Enterprise Fortress Gateway (EFG) (u/Navish360)

If your device is not on this list, message me and we can modfiy the script for compatibility.

# Getting Started
> [!WARNING]
>
> **DO NOT RUN THIS SCRIPT IF YOUR DEVICE IS IN BRIDGE MODE!**
> **IT DOES NOT CURRENTLY CHECK FOR BRIDGE MODE AND WILL BREAK YOUR SETUP!**

## Requirements
- SSH is enabled on your Ubiquiti hardware
- Folder with all certifcates(CA, Client, Private Key), script, deb packages
- Configure User Variables (in```wtf-wpa.sh``` or ```var-wtf-wpa.txt```)

### "config" folder example
I created a folder called "config" that contains the following:
```shell
CA.pem
Client.pem
PrivateKey.pem
libpcsclite1_1.9.1-1_arm64.deb
wpasupplicant_2.9.0-21_arm64.deb
wtf-wpa.sh
var-wtf-wpa.txt
```

You will need to provide your own certificates, but the script, deb files and variable file are available below:
- [wtf-wpa.sh](wtf-wpa.sh)
- [wpasupplicant_2.9.0-21_arm64.deb](deb%20packages/wpasupplicant_2.9.0-21_arm64.deb) - wpa_supplicant installer
- [libpcsclite1_1.9.1-1_arm64.deb](deb%20packages/libpcsclite1_1.9.1-1_arm64.deb) - Dependancy for wpasupplicant_2.9.0-21_arm64.deb
- [var-wtf-wpa.txt](var-wtf-wpa.txt) (_optional, but recommended_)

### USER VARIABLES
Variables must be configured in ```wtf-wpa.sh``` or the ```var-wtf-wpa.txt``` file.
> [!TIP]
>
>I highly recommend using the ```var-wtf-wpa.txt``` file to make script updates easier.
>

The ```var-wtf-wpa.txt``` file will take precedence over values entered in the script
 ```bash
## USER VARIABLES ##

# FULL PATH to "backup" folder
backupPath="/root/config"

# Names of install deb files
libpcspkg="libpcsclite1_1.9.1-1_arm64.deb"
wpapkg="wpasupplicant_2.9.0-21_arm64.deb"

# Internet (ONT) interface MAC address (Pulled from cert extraction process)
# Exmaple: inetONTmac="00:00:00:00:00:00"
inetONTmac=""

# Certficate variables
CA_filename="CA.pem"
Client_filename="Client.pem"
PrivateKey_filename="PrivateKey.pem"

# FULL PATH for wpa_supplicant.conf
confPath="/etc/wpa_supplicant/conf"

# FULL PATH for cert storage
certPath="/etc/wpa_supplicant/conf"

# FULL PATH for deb package storage
debPath="/etc/wpa_supplicant/packages"
```

# Initial Deployment

### Copy the "config" folder to your device.

I recommend putting this in ```/root/``` and setting your ```backupPath``` variable to ```"/root/config"```.

I've created a hostname entry on my internal dns called "udmpro", but you can use your IP address.
```scp -r config root@udmpro:~/```

Once that is done, ssh into your device and navigate to the directory you just copied over.
```
DEMO:~ shaun$ ssh root@udmpro
root@UDMPRO:~# cd config/
```

Do an ```ls -l``` to confirm the script is executable.
```shell
root@UDMPRO:~/config# ls -l
total 1276
-rw-r----- 1 root root    6399 Jun 10 16:24 CA.pem
-rw-r----- 1 root root    1123 Jun 10 16:24 Client.pem
-rw-r----- 1 root root     891 Jun 10 16:37 PrivateKey.pem
-rw-r--r-- 1 root root   59464 Jan 27  2024 libpcsclite1_1.9.1-1_arm64.deb
-rw-r--r-- 1 root root     629 Oct  5 12:13 var-wtf-wpa.txt
-rw-r--r-- 1 root root 1188492 Jan 25  2024 wpasupplicant_2.9.0-21_arm64.deb
-rwxr-xr-x 1 root root   29593 Oct  7 12:45 wtf-wpa.sh*
root@UDMPRO:~/config#
```
> [!TIP]
>
>If you do not see the "x" when listing the directory, you can add it by executing the following command:
> ```chmod +x wtf-wpa.sh```
<br/>

# Updating Script

1. SSH into your device and navigate to your "config" directory.
2. Run the curl command below to download the new script, overwriting the existing file.
```shell
curl -O https://raw.githubusercontent.com/WhiskeyTang0F0xtr0t/unifi/refs/heads/main/wpa_supplicant/wtf-wpa.sh
```
3. Make the script executable.
```shell
chmod +x wtf-wpa.sh
```

# Usage
```shell
root@UDMPRO:~/config# ./wtf-wpa.sh
 
   WTF wpa_supplicant script $wtf_ver

   Syntax: wtf-wpa.sh [-i|c|f]

   options: 

         -i   Install/repair & configure the wpa_supplicant service
              Example: wtf-wpa.sh -i

         -c   Does a quick status check of the wpa_supplicant service
              Example: wtf-wpa.sh -c

         -f   forces configuration file rebuild and re-copies your certificates
              Example: wtf-wpa.sh -f
              Useful for rebuilding after configuration/certificate changes

     <none>   Print this Help

root@UDMPRO:~/config# 
```

<details>
<summary>Terminal Output Example</summary>
<img width="1097" alt="Screenshot 2025-04-16 at 8 07 45 AM" src="https://github.com/user-attachments/assets/f1a41e98-88c0-43be-a6c0-61a86d48eb10" />
</details>

<details>
<summary>Log Output Example</summary>
  
```shell
[2025-04-10 18:08:35] - *** Logging to: log-wtf-wpa.log ***
[2025-04-10 18:08:35] - *** Script Version: 2.3 ***
[2025-04-10 18:08:35] - *** VERIFICATION MODE ***
[2025-04-10 18:08:35] - *** Checking for variables ***
[2025-04-10 18:08:35] - INFO: Found - var-file: /root/config/var-wtf-wpa.txt
[2025-04-10 18:08:35] - INFO: Found - backupPath: /root/config
[2025-04-10 18:08:35] - INFO: Found - libpcspkg: libpcsclite1_1.9.1-1_arm64.deb
[2025-04-10 18:08:35] - INFO: Found - wpapkg: wpasupplicant_2.9.0-21_arm64.deb
[2025-04-10 18:08:35] - INFO: Found - inetONTmac: 12:34:56:78:AB:CD
[2025-04-10 18:08:35] - INFO: Found - backupPath: /root/config
[2025-04-10 18:08:35] - INFO: Found - CA_filename: CA.pem
[2025-04-10 18:08:35] - INFO: Found - Client_filename: Client.pem
[2025-04-10 18:08:35] - INFO: Found - PrivateKey_filename: PrivateKey.pem
[2025-04-10 18:08:35] - INFO: Found - confPath: /etc/wpa_supplicant/conf
[2025-04-10 18:08:35] - INFO: Found - certPath: /etc/wpa_supplicant/conf
[2025-04-10 18:08:35] - INFO: Found - debPath: /etc/wpa_supplicant/packages
[2025-04-10 18:08:35] - *** Checking Hardware ***
[2025-04-10 18:08:35] - INFO: Hardware - UniFi Dream Machine Pro
[2025-04-10 18:08:35] - INFO: WAN Interface: eth8
[2025-04-10 18:08:35] - INFO: Override WAN Interface: eth8
[2025-04-10 18:08:35] - INFO: Compare WAN Interface: MATCHED
[2025-04-10 18:08:35] - *** Checking for required directories ***
[2025-04-10 18:08:35] - INFO: Found - Backup Path: /root/config
[2025-04-10 18:08:35] - INFO: Found - debPath: /etc/wpa_supplicant/packages
[2025-04-10 18:08:35] - INFO: Found - certPath: /etc/wpa_supplicant/conf
[2025-04-10 18:08:35] - INFO: Found - confPath: /etc/wpa_supplicant/conf
[2025-04-10 18:08:35] - INFO: Found - override: /etc/systemd/system/wpa_supplicant.service.d
[2025-04-10 18:08:35] - *** Checking for required deb packages ***
[2025-04-10 18:08:35] - INFO: Found - deb_pkg: /etc/wpa_supplicant/packages/libpcsclite1_1.9.1-1_arm64.deb
[2025-04-10 18:08:35] - INFO: Found - deb_pkg: /etc/wpa_supplicant/packages/wpasupplicant_2.9.0-21_arm64.deb
[2025-04-10 18:08:35] - *** Checking for required certificates ***
[2025-04-10 18:08:35] - INFO: Found - CA: /etc/wpa_supplicant/conf/CA.pem
[2025-04-10 18:08:35] - INFO: Found - Client: /etc/wpa_supplicant/conf/Client.pem
[2025-04-10 18:08:35] - INFO: Found - PrivateKey: /etc/wpa_supplicant/conf/PrivateKey.pem
[2025-04-10 18:08:35] - *** Checking for wpa_supplicant conf files ***
[2025-04-10 18:08:35] - INFO: Found - wpa_conf: /etc/wpa_supplicant/conf/wpa_supplicant.conf
[2025-04-10 18:08:35] - INFO: Found - override: /etc/systemd/system/wpa_supplicant.service.d/override.conf
[2025-04-10 18:08:35] - *** Checking wpa_supplicant service ***
[2025-04-10 18:08:35] - INFO: wpa_supplicant installed: 2:2.9.0-21
[2025-04-10 18:08:35] - INFO: wpa_supplicant is active
[2025-04-10 18:08:35] - INFO: wpa_supplicant is enabled
[2025-04-10 18:08:35] - *** Checking recovery service ***
[2025-04-10 18:08:35] - INFO: wtf-wpa.service is enabled
[2025-04-10 18:08:35] - *** Testing connection to google.com:80 ***
[2025-04-10 18:08:35] - INFO: Attempt 1/3: netcat google.com:80 SUCCESSFUL
[2025-04-10 18:08:35] - *** Process complete ***
```
</details>
------
<br/>

# Example Files

<details>

<summary>wpa_supplicant configuration</summary>
/etc/wpa_supplicant/conf/wpa_supplicant.conf

```shell
eapol_version=1
ap_scan=0
fast_reauth=1
network={
        ca_cert="'"${certPath}"/"${CA_filename}"'"
        client_cert="'"${certPath}"/"${Client_filename}"'"
        eap=TLS
        eapol_flags=0
        identity="'"${inetONTmac}"'" # Internet (ONT) interface MAC address must match this value
        key_mgmt=IEEE8021X
        phase1="allow_canned_success=1"
        private_key="'"${certPath}"/"${PrivateKey_filename}"'"
}
```
</details>

<details>

<summary>wpa_supplicant service</summary>
/lib/systemd/system/wpa_supplicant.service

```shell
[Unit]
Description=WPA supplicant
Before=network.target
After=dbus.service
Wants=network.target
IgnoreOnIsolate=true

[Service]
Type=dbus
BusName=fi.w1.wpa_supplicant1
ExecStart=/sbin/wpa_supplicant -u -s -O /run/wpa_supplicant

[Install]
WantedBy=multi-user.target
Alias=dbus-fi.w1.wpa_supplicant1.service
```
</details>

<details>

<summary>wpa_supplicant service override.conf</summary>
/etc/systemd/system/wpa_supplicant.service.d/override.conf

```shell
[Unit]
Description=wpa_supplicant service for AT&T router bypass
StartLimitIntervalSec=30s
StartLimitBurst=5

[Service]
Restart=on-failure
RestartSec=5s

ExecStart=
ExecStart=/sbin/wpa_supplicant -u -s -Dwired -i${udapi_wan_int} -c${confPath}/wpa_supplicant.conf
```
</details>

<details>

<summary>Recovery Service</summary>
/etc/systemd/system/wtf-wpa.service

```shell
[Unit]
Description=Reinstall and start/enable wpa_supplicant
AssertPathExistsGlob='${backupPath}'/wpasupplicant*arm64.deb
AssertPathExistsGlob='${backupPath}'/libpcsclite1*arm64.deb
ConditionPathExists=!/sbin/wpa_supplicant
ConditionPathExists='${backupPath}'/wtf-wpa.sh

[Service]
Type=oneshot\nExecStart='${backupPath}'/wtf-wpa.sh -r

[Install]
WantedBy=multi-user.target
```
</details>

# Future Plans
- TBD
