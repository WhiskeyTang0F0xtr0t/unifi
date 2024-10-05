# Overview
A tool to setup the wpa_supplicant service for AT&T Residential Gateway Bypass on Ubiquiti hardware.

Features:
- Confirms Ubiquiti hardware
- Verifies all needed files are in available (certs, pkgs)
- Installs and configures wpa_supplicant service
- 

> [!NOTE]
> July 3rd, 2024
> 
> Updated UniFi OS from v3.2.12 to v4.0.6 and re-install service worked as intended.
> No additional downtime outside of the reboot.

> [!IMPORTANT]
>
> This script has been confirmed working on the following hardware:
> - Dream Machine (u/-BruceWayne-)
> - Dream Machine Pro
> - Dream Machine Special Edition
> - Dream Machine Pro Max
> - Cloud Gateway Ultra
> - Cloud Gateway Express
> - Enterprise Fortress Gateway (u/Navish360)
>
> If your device is not on this list, message me and we can modfiy the script for compatibility.

**DO NOT RUN THIS SCRIPT IF YOUR DEVICE IS IN BRIDGE MODE!**

**IT DOES NOT CURRENTLY CHECK FOR BRIDGE MODE AND WILL BREAK YOUR SETUP!**

> [!TIP]
>
>You need to update the USER VARIABLES to match your configuration!
>This can be done in the script itself or the **var-wtf-wpa.txt** file

<details>
<summary>USER VARIABLES</summary>
```
## USER VARIABLES ##

# FULL PATH to "backup" folder
backupPath="/root/config"

# Names of install deb files
libpcspkg="libpcsclite1_1.9.1-1_arm64.deb"
wpapkg="wpasupplicant_2.9.0-21_arm64.deb"

# Internet (ONT) interface MAC address (Pulled from cert extraction process)
inetONTmac="00:00:00:00:00:00"

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
</details>

### Create your "config" folder
I created a folder called "config" that contains the following:
```
CA.pem
Client.pem
PrivateKey.pem
libpcsclite1_1.9.1-1_arm64.deb
wpasupplicant_2.9.0-21_arm64.deb
wtf-wpa.sh
var-wtf-wpa.txt (optional)
```
You will need to provide your own certificates, but the deb files and script are available here.

- [Debian packages](wpa_supplicant/deb%20packages)
- [wtf-wpa.sh](wpa_supplicant/wtf-wpa.sh)

### Make sure SSH is configured on your device.
I like to use SSH private keys instead of passwords and install them using the ```ssh-copy-id``` command.

### Copy the "config" folder to your device
I've created a hostname entry on my internal dns called "udmpro", but you can use your IP address.

```scp -r config root@udmpro:~/```

Once that is done, ssh into your device and navigate to the directory you just copied over.
```
DEMO:~ shaun$ ssh root@udmpro
root@UDMPRO:~# cd config/
```
### Script Usage
```
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
<img width="816" alt="Terminal" src="https://github.com/user-attachments/assets/bec67e9e-05ca-4c5a-9699-a6843137ffa9">
</details>

<details>
<summary>Log Output Example</summary>
  
```
[2024-08-16 16:36:35] - *** Logging to: wtf-wpa.log ***
[2024-08-16 16:36:35] - *** Verification Mode ***
[2024-08-16 16:36:35] - *** Checking Hardware Version ***
[2024-08-16 16:36:35] - INFO: Hardware - UniFi Dream Machine Pro
[2024-08-16 16:36:35] - INFO: WAN Interface: eth8
[2024-08-16 16:36:35] - *** Checking for required directories ***
[2024-08-16 16:36:35] - INFO: Found - Backup Path: /root/config
[2024-08-16 16:36:35] - INFO: Found - debPath: /etc/wpa_supplicant/packages
[2024-08-16 16:36:35] - INFO: Found - certPath: /etc/wpa_supplicant/conf
[2024-08-16 16:36:35] - INFO: Found - confPath: /etc/wpa_supplicant/conf
[2024-08-16 16:36:35] - INFO: Found - override: /etc/systemd/system/wpa_supplicant.service.d
[2024-08-16 16:36:35] - *** Checking for required deb packages ***
[2024-08-16 16:36:35] - INFO: Found - deb_pkg: /etc/wpa_supplicant/packages/libpcsclite1_1.9.1-1_arm64.deb
[2024-08-16 16:36:35] - INFO: Found - deb_pkg: /etc/wpa_supplicant/packages/wpasupplicant_2.9.0-21_arm64.deb
[2024-08-16 16:36:35] - *** Checking for required certificates ***
[2024-08-16 16:36:35] - INFO: Found - CA: /etc/wpa_supplicant/conf/CA.pem
[2024-08-16 16:36:35] - INFO: Found - Client: /etc/wpa_supplicant/conf/Client.pem
[2024-08-16 16:36:35] - INFO: Found - PrivateKey: /etc/wpa_supplicant/conf/PrivateKey.pem
[2024-08-16 16:36:35] - *** Checking for wpa_supplicant conf files ***
[2024-08-16 16:36:35] - INFO: Found - wpa_conf: /etc/wpa_supplicant/conf/wpa_supplicant.conf
[2024-08-16 16:36:35] - INFO: Found - override: /etc/systemd/system/wpa_supplicant.service.d/override.conf
[2024-08-16 16:36:35] - *** Checking wpa_supplicant service ***
[2024-08-16 16:36:35] - INFO: wpa_supplicant installed: 2:2.9.0-21
[2024-08-16 16:36:35] - INFO: wpa_supplicant is active
[2024-08-16 16:36:35] - INFO: wpa_supplicant is enabled
[2024-08-16 16:36:35] - *** Checking recovery service ***
[2024-08-16 16:36:35] - INFO: wtf-wpa.service is enabled
[2024-08-16 16:36:35] - *** Testing connection to google.com:80 ***
[2024-08-16 16:36:36] - INFO: Attemp 1/3: netcat google.com:80 SUCCESSFUL
[2024-08-16 16:36:36] - *** Process complete ***
```
</details>
------

[Debian packages](wpa_supplicant/deb%20packages)
- `wpasupplicant_2.9.0-21_arm64.deb` - wpasupplicant install file
- `libpcsclite1_1.9.1-1_arm64.deb` - Dependancy for wpasupplicant_2.9.0-21_arm64.deb; All others should be in place on UniFi OS 3.x+
------

Future Plans
- [X] `wtf-wpa.sh` - Merge both scripts into a new script with combined functionality using switches
- [X] Add "auto recover" systemctl service to re-enable wpa_supplicant service after minor Unifi OS update(Major will most like wipe the volume)
