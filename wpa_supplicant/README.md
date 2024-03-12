# Scripts

> [!NOTE]
> - I tried to put as much into functions as possible for portability and the potential for others to reuse.
> - I'm sure they're over engineered and/or poorly coded, but I enjoyed the exercise.
## wtf-wpa.sh
Combines some functionality of wtf-check-wpasupp.sh & wtf-install-wpasupp.sh to create an "all in one" solution.
This will probably be the most useful scripts for regular users.

### Usage
```
root@UDMPRO:~# ./wtf-wpa.sh 
 
   WTF wpa [ install/repair | check ]

   Syntax: wtf-wpa.sh [-i|r|c]

   options: 

         -i   Install/repair & configure the wpa_supplicant service
              Example: wtf-wpa.sh -i

         -c   Does a quick status check of the wpa_supplicant service
              Example: wtf-wpa.sh -c

     <none>   Print this Help

root@UDMPRO:~# 
```

<details>
<summary>Terminal Output Example</summary>
<img width="863" alt="wtf-ui" src="https://github.com/WhiskeyTang0F0xtr0t/unifi/assets/9803191/cc028256-0c30-4141-a612-19a42cb108f7">
</details>

<details>
<summary>Log Output Example</summary>
  
```
[2024-03-12 08:10:15] - *** Logging to: wtf-wpa.log ***
[2024-03-12 08:10:15] - *** Verification Mode ***
[2024-03-12 08:10:15] - *** Checking Hardware Version ***
[2024-03-12 08:10:15] - INFO: Hardware - UniFi Dream Machine Pro
[2024-03-12 08:10:15] - INFO: WAN Interface: eth8
[2024-03-12 08:10:15] - *** Checking for required directories ***
[2024-03-12 08:10:15] - INFO: Found - Backup Path: /root/config
[2024-03-12 08:10:15] - INFO: Found - debPath: /etc/wpa_supplicant/packages
[2024-03-12 08:10:15] - INFO: Found - certPath: /etc/wpa_supplicant/conf
[2024-03-12 08:10:15] - INFO: Found - confPath: /etc/wpa_supplicant/conf
[2024-03-12 08:10:15] - *** Checking for required deb packages ***
[2024-03-12 08:10:15] - INFO: Found - deb_pkg: /etc/wpa_supplicant/packages/libpcsclite1_1.9.1-1_arm64.deb
[2024-03-12 08:10:15] - INFO: Found - deb_pkg: /etc/wpa_supplicant/packages/wpasupplicant_2.9.0-21_arm64.deb
[2024-03-12 08:10:15] - *** Checking for required certificates ***
[2024-03-12 08:10:15] - INFO: Found - CA: /etc/wpa_supplicant/conf/CA.pem
[2024-03-12 08:10:15] - INFO: Found - Client: /etc/wpa_supplicant/conf/Client.pem
[2024-03-12 08:10:15] - INFO: Found - PrivateKey: /etc/wpa_supplicant/conf/PrivateKey.pem
[2024-03-12 08:10:15] - *** Checking for wpa_supplicant.conf ***
[2024-03-12 08:10:15] - INFO: Found - wpa_conf: /etc/wpa_supplicant/conf/wpa_supplicant.conf
[2024-03-12 08:10:15] - *** Checking wpa_supplicant service ***
[2024-03-12 08:10:15] - INFO: wpa_supplicant installed: 2:2.9.0-21
[2024-03-12 08:10:15] - INFO: wpa_supplicant is active
[2024-03-12 08:10:15] - INFO: wpa_supplicant is enabled
[2024-03-12 08:10:15] - *** Testing connection to google.com:80 ***
[2024-03-12 08:10:15] - INFO: Attemp 1/3: netcat google.com:80 SUCCESSFUL
[2024-03-12 08:10:15] - *** Process complete ***
```
</details>
------

[Debian packages](wpa_supplicant/deb%20packages)
- `wpasupplicant_2.9.0-21_arm64.deb` - wpasupplicant install file
- `libpcsclite1_1.9.1-1_arm64.deb` - Dependancy for wpasupplicant_2.9.0-21_arm64.deb; All others should be in place on UniFi OS 3.x+
------

Future Plans
- [X] `wtf-wpa.sh` - Merge both scripts into a new script with combined functionality using switches
- [ ] Add "auto recover" systemctl service to re-enable wpa_supplicant service after minor Unifi OS update(Major will most like wipe the volume)

Deprecated
- [wtf-check-wpasupp.sh](archive/wtf-check-wpasupp.sh) - Checks the wpa_supplicant service and confirms needed files are present by parsing the existing config.
- [wtf-install-wpasupp.sh](archive/wtf-install-wpasupp.sh) - Check/repair/install the wpa_supplicant setup on UDM hardware


