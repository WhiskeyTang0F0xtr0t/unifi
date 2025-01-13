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
- [Deployment](#deployment)
- [Usage](#usage)
- [Future Plans](#future-plans)

# Overview
A tool to setup the wpa_supplicant service for AT&T Residential Gateway Bypass on Ubiquiti hardware.

Features:
- Made for Ubiquiti hardware, but could be tweaked to work on other platforms that support wpa_supplicant
- Verifies all needed files are available(certs, pkgs) and variables are set
- Installs and configures wpa_supplicant service with "restart on failure" enabled
- Creates "auto recovery" service that leverages $backupPath to re-install and configure wpa_supplicant after Unifi OS update/upgrade
- Optional external variable file support

# Supported Devices
This script has been confirmed working on the following hardware:
- Dream Machine (u/-BruceWayne-)
- Dream Machine Pro
- Dream Machine Special Edition
- Dream Machine Pro Max
- Cloud Gateway Ultra
- Cloud Gateway Express
- Enterprise Fortress Gateway (u/Navish360)

If your device is not on this list, message me and we can modfiy the script for compatibility.

# Getting Started
> [!WARNING]
>
> **DO NOT RUN THIS SCRIPT IF YOUR DEVICE IS IN BRIDGE MODE!**
> **IT DOES NOT CURRENTLY CHECK FOR BRIDGE MODE AND WILL BREAK YOUR SETUP!**

## Requirements
- SSH is enabled on your Ubiquiti hardware
- Folder with all certifcates(CA, Client, Private Key), script, deb packages
- Configure User Variable (in```wtf-wpa.sh``` or ```var-wtf-wpa.txt```)

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
- [var-wtf-wpa.txt](var-wtf-wpa.txt) (_optional_)

### USER VARIABLES
Variables must be configured in ```wtf-wpa.sh``` or the ```var-wtf-wpa.txt``` file.

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
# Deployment

### Copy the "config" folder to your device
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

# Usage
```shell
root@UDMPRO:~/config# ./wtf-wpa.sh
 
   WTF wpa_supplicant script

   Syntax: wtf-wpa.sh [-i|c|f]

   options: 

         -i   Install/repair & configure the wpa_supplicant service
              Example: wtf-wpa.sh -i

         -c   Does a quick status check of the wpa_supplicant service
              Example: wtf-wpa.sh -c

         -f   update your certificates and conf files only
              Example: wtf-wpa.sh -f
              Useful for rebuilding after configuration/certificate changes

     <none>   Print this Help

root@UDMPRO:~/config# 
```

<details>
<summary>Terminal Output Example</summary>
<img width="1034" alt="Screenshot 2024-10-06 at 11 33 58 AM" src="https://github.com/user-attachments/assets/72af3272-063b-4094-8857-94288203f7b5">
</details>

<details>
<summary>Log Output Example</summary>
  
```shell
[2024-10-06 11:33:32] - *** Logging to: log-wtf-wpa.log ***
[2024-10-06 11:33:32] - *** VERIFICATION MODE ***
[2024-10-06 11:33:32] - *** Checking for variables ***
[2024-10-06 11:33:32] - INFO: Found - var-file: /root/config/var-wtf-wpa.txt
[2024-10-06 11:33:32] - INFO: Found - backupPath: /root/config
[2024-10-06 11:33:32] - INFO: Found - libpcspkg: libpcsclite1_1.9.1-1_arm64.deb
[2024-10-06 11:33:32] - INFO: Found - wpapkg: wpasupplicant_2.9.0-21_arm64.deb
[2024-10-06 11:33:32] - INFO: Found - inetONTmac: 12:34:56:78:AB:CD
[2024-10-06 11:33:32] - INFO: Found - backupPath: /root/config
[2024-10-06 11:33:32] - INFO: Found - CA_filename: CA.pem
[2024-10-06 11:33:32] - INFO: Found - Client_filename: Client.pem
[2024-10-06 11:33:32] - INFO: Found - PrivateKey_filename: PrivateKey.pem
[2024-10-06 11:33:32] - INFO: Found - confPath: /etc/wpa_supplicant/conf
[2024-10-06 11:33:32] - INFO: Found - certPath: /etc/wpa_supplicant/conf
[2024-10-06 11:33:32] - INFO: Found - debPath: /etc/wpa_supplicant/packages
[2024-10-06 11:33:32] - *** Checking Hardware Version ***
[2024-10-06 11:33:32] - INFO: Hardware - UniFi Dream Machine Pro
[2024-10-06 11:33:32] - INFO: WAN Interface: eth8
[2024-10-06 11:33:32] - *** Checking for required directories ***
[2024-10-06 11:33:32] - INFO: Found - Backup Path: /root/config
[2024-10-06 11:33:32] - INFO: Found - debPath: /etc/wpa_supplicant/packages
[2024-10-06 11:33:32] - INFO: Found - certPath: /etc/wpa_supplicant/conf
[2024-10-06 11:33:32] - INFO: Found - confPath: /etc/wpa_supplicant/conf
[2024-10-06 11:33:32] - INFO: Found - override: /etc/systemd/system/wpa_supplicant.service.d
[2024-10-06 11:33:32] - *** Checking for required deb packages ***
[2024-10-06 11:33:32] - INFO: Found - deb_pkg: /etc/wpa_supplicant/packages/libpcsclite1_1.9.1-1_arm64.deb
[2024-10-06 11:33:32] - INFO: Found - deb_pkg: /etc/wpa_supplicant/packages/wpasupplicant_2.9.0-21_arm64.deb
[2024-10-06 11:33:32] - *** Checking for required certificates ***
[2024-10-06 11:33:32] - INFO: Found - CA: /etc/wpa_supplicant/conf/CA.pem
[2024-10-06 11:33:32] - INFO: Found - Client: /etc/wpa_supplicant/conf/Client.pem
[2024-10-06 11:33:32] - INFO: Found - PrivateKey: /etc/wpa_supplicant/conf/PrivateKey.pem
[2024-10-06 11:33:32] - *** Checking for wpa_supplicant conf files ***
[2024-10-06 11:33:32] - INFO: Found - wpa_conf: /etc/wpa_supplicant/conf/wpa_supplicant.conf
[2024-10-06 11:33:32] - INFO: Found - override: /etc/systemd/system/wpa_supplicant.service.d/override.conf
[2024-10-06 11:33:32] - *** Checking wpa_supplicant service ***
[2024-10-06 11:33:32] - INFO: wpa_supplicant installed: 2:2.9.0-21
[2024-10-06 11:33:32] - INFO: wpa_supplicant is active
[2024-10-06 11:33:32] - INFO: wpa_supplicant is enabled
[2024-10-06 11:33:32] - *** Checking recovery service ***
[2024-10-06 11:33:32] - INFO: wtf-wpa.service is enabled
[2024-10-06 11:33:32] - *** Testing connection to google.com:80 ***
[2024-10-06 11:33:32] - INFO: Attemp 1/3: netcat google.com:80 SUCCESSFUL
[2024-10-06 11:33:32] - *** Process complete ***
```
</details>
------


# Future Plans
- [ ] Overhaul README.md
