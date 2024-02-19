# Scripts

> [!NOTE]
> - I tried to put as much into functions as possible for portability and the potential for others to reuse.
> - I'm sure they're over engineered and/or poorly coded, but I enjoyed the exercise.

## wtf-check-wpasupp.sh
A non-destructive script to verify the disposition of the wpa_supplicant system service.
The script will output formatted status messages and all errors to the logfile

<details>
<summary>Terminal Output Example</summary>
<img width="1006" alt="wtf-check" src="https://github.com/WhiskeyTang0F0xtr0t/unifi/assets/9803191/989a5076-31bb-41b5-9f66-8b8c59239801">
</details>

<details>
<summary>Log Output Example</summary>

```
[2024-02-14 19:13:12] - *** Logging to: check-wpasupp.log ***
[2024-02-14 19:13:12] - *** Checking Hardware ***
[2024-02-14 19:13:12] - INFO: Hardware - UniFi Dream Machine Pro
[2024-02-14 19:13:12] - INFO: WAN Interface: eth8
[2024-02-14 19:13:12] - *** Checking wpa_supplicant service ***
[2024-02-14 19:13:12] - INFO: wpa_supplicant installed: 2:2.9.0-21
[2024-02-14 19:13:12] - INFO: wpa_supplicant is active
[2024-02-14 19:13:12] - INFO: wpa_supplicant is enabled
[2024-02-14 19:13:12] - *** Checking for override.conf file ***
[2024-02-14 19:13:12] - INFO: Found - /etc/systemd/system/wpa_supplicant.service.d/override.conf
[2024-02-14 19:13:12] - INFO: Parsed - /etc/wpa_supplicant/conf/wpa_supplicant.conf
[2024-02-14 19:13:12] - *** Parsing active config from wpa_supplicant service ***
[2024-02-14 19:13:12] - INFO: Found - /etc/wpa_supplicant/conf/wpa_supplicant.conf
[2024-02-14 19:13:12] - INFO: Parsed - Dwired
[2024-02-14 19:13:12] - INFO: Parsed - Interface: eth8
[2024-02-14 19:13:12] - *** Parsing wpa_supplicant.conf ***
[2024-02-14 19:13:12] - INFO: wpa_supplicant conf - /etc/wpa_supplicant/conf/wpa_supplicant.conf
[2024-02-14 19:13:12] - INFO: Parsed - identity
[2024-02-14 19:13:12] - INFO: Parsed - ONT MAC - 0:00:00:00:00:00
[2024-02-14 19:13:12] - INFO: Parsed - ca_cert
[2024-02-14 19:13:12] - INFO: Parsed - CA Path: /etc/wpa_supplicant/conf
[2024-02-14 19:13:12] - INFO: Parsed - CA Filename: CA.pem
[2024-02-14 19:13:12] - INFO: Parsed - client_cert
[2024-02-14 19:13:12] - INFO: Parsed - Client Path: /etc/wpa_supplicant/conf
[2024-02-14 19:13:12] - INFO: Parsed - Client Filename: Client.pem
[2024-02-14 19:13:12] - INFO: Parsed - private_key
[2024-02-14 19:13:12] - INFO: Parsed - PrivateKey Path: /etc/wpa_supplicant/conf
[2024-02-14 19:13:12] - INFO: Parsed - PrivateKey Filename: PrivateKey_PKCS1.pem
[2024-02-14 19:13:12] - *** Verifying certificates exist ***
[2024-02-14 19:13:12] - INFO: Found - CA /etc/wpa_supplicant/conf/CA.pem
[2024-02-14 19:13:12] - INFO: Found - Client /etc/wpa_supplicant/conf/Client.pem
[2024-02-14 19:13:12] - INFO: Found - PrivateKey /etc/wpa_supplicant/conf/PrivateKey.pem
[2024-02-14 19:13:12] - *** Verifying WAN interfaces match ***
[2024-02-14 19:13:12] - INFO: Detected WAN interface matches wpa_supplicant service conf
[2024-02-14 19:13:12] - *** Checks complete ***
```
</details>


### Usage
```
./wtf-check-wpasupp.sh
```
Workflow Breakdown - Main scripts actions
1. Reset the logfile
2. Check Hardware (functions: `check-hw` `parse-wan-int`)
3. Check wpa_supplicant service (functions: `check-wpa-supp-installed` `check-wpa-supp-active` `check-wpa-supp-enabled`)
4. Checking for override.conf file (functions: `check-for-override`)
5. Parsing active config from wpa_supplicant service (functions: `parse_service_conf`)
6. Parsing ${wpasuppconf_filename} (functions: `parse-wpasupp-conf`)
7. Verifying certificates exist (functions: `check-for-pems`)
8. Verifying WAN interfaces match (functions: `check-compare-interfaces`)
------


## wtf-install-wpasupp.sh
Check/repair/install the wpa_supplicant setup on UDM hardware.
The script will output formatted status messages and all errors to the log file.

> [!WARNING]
> This script can break things if you don't configure it properly.

<details>
<summary>Terminal Output Example</summary>
<img width="1006" alt="wtf-install" src="https://github.com/WhiskeyTang0F0xtr0t/unifi/assets/9803191/cef6b8f2-1e61-4e7a-b2ec-90e2422c5588">
</details>

<details>
<summary>Log Output Example</summary>

```
[2024-02-14 19:12:51] - *** Logging to: wtf-install-wpasupp.log ***
[2024-02-14 19:12:51] - *** Checking Hardware Version ***
[2024-02-14 19:12:51] - INFO: Hardware - UniFi Dream Machine Pro
[2024-02-14 19:12:51] - INFO: WAN Interface: eth8
[2024-02-14 19:12:51] - *** Checking for required deb packages ***
[2024-02-14 19:12:51] - INFO: Found - libpcsclite1_1.9.1-1_arm64.deb
[2024-02-14 19:12:51] - INFO: Found - wpasupplicant_2.9.0-21_arm64.deb
[2024-02-14 19:12:51] - *** Checking for required directories ***
[2024-02-14 19:12:51] - INFO: Found - backupPath /root/config
[2024-02-14 19:12:51] - INFO: Found - debPath /etc/wpa_supplicant/packages
[2024-02-14 19:12:51] - INFO: Found - certPath /etc/wpa_supplicant/conf
[2024-02-14 19:12:51] - INFO: Found - confPath /etc/wpa_supplicant/conf
[2024-02-14 19:12:51] - *** Checking for required certificates ***
[2024-02-14 19:12:51] - INFO: Found - CA /etc/wpa_supplicant/conf/CA.pem
[2024-02-14 19:12:51] - INFO: Found - Client /etc/wpa_supplicant/conf/Client.pem
[2024-02-14 19:12:51] - INFO: Found - PrivateKey /etc/wpa_supplicant/conf/PrivateKey.pem
[2024-02-14 19:12:51] - *** Checking for wpa_supplicant.conf ***
[2024-02-14 19:12:51] - INFO: Found - /etc/wpa_supplicant/conf/wpa_supplicant.conf
[2024-02-14 19:12:51] - *** Checking wpa_supplicant service ***
[2024-02-14 19:12:51] - INFO: wpa_supplicant installed: 2:2.9.0-21
[2024-02-14 19:12:51] - INFO: wpa_supplicant is active
[2024-02-14 19:12:51] - *** Testing internet connectivity ***
[2024-02-14 19:12:51] - INFO: netcat google.com:80 SUCCESSFUL
[2024-02-14 19:12:51] - *** Process complete ***
```
</details>


### Backup folder structure
The "backup" folder will need to copied over to your hardware and accessable by the user running the script. Mine is /root/config

$backupPath
```
./libpcsclite1_1.9.1-1_arm64.deb
./wpasupplicant_2.9.0-21_arm64.deb
./CA.pem
./Client.pem
./PrivateKey.pem
./wpa_supplicant.conf (Optional. Can be created if not found)
```

### Usage
```
./wtf-install-wpasupp.sh
```
Workflow Breakdown - Main scripts actions
1. Reset the logfile
2. Check Hardware (functions: `check-hw` `parse-wan-int`)
3. Check for deb packages (functions: `check-for-debpkg`)
4. Check for required directories (functions: `check-backupPath` `check-destPaths`)
5. Verify if certificates exist (functions: `check-for-pems`)
6. Check fir wpa_supplicant.conf and create if not found (functions: `check-wpasupp-conf`)
7. Check wpa_supplicant service & activate (functions: `check-wpa-supp-installed` `check-wpa-supp-active`)
   1. If wpa_supplicant service is not found, install & configure (functions: `install-wpa-supp`)
8. Test internet connectivity with to google.com:80 (functions: `netcat-test`)
