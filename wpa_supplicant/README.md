# Scripts

> [!NOTE]
> - I tried to put as much into functions as possible for portability and the potential for others to reuse.
> - I'm sure they're over engineered and/or poorly coded, but I enjoyed the exercise.
## wtf-wpa.sh
Combines some functionality of wtf-check-wpasupp.sh & wtf-install-wpasupp.sh to create an "all in one" solution.
This will probably be the most useful scripts for regular users.

### Create your "config" folder
I created a folder called "config" that contains the following:
```
CA.pem
Client.pem
PrivateKey.pem
libpcsclite1_1.9.1-1_arm64.deb
wpasupplicant_2.9.0-21_arm64.deb
wtf-wpa.sh
```
You will need to privde your own certificates, but the deb files and script are available here.

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
 
   WTF wpa [ install/repair | check ]

   Syntax: wtf-wpa.sh [-i|c]

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
<img width="922" alt="Terminal Output" src="https://github.com/WhiskeyTang0F0xtr0t/unifi/assets/9803191/078e677b-928d-4251-bfcc-d97e1889cdb2">
</details>

<details>
<summary>Log Output Example</summary>
  
```
[2024-06-10 17:16:00] - *** Logging to: wtf-wpa.log ***
[2024-06-10 17:16:00] - *** Verification Mode ***
[2024-06-10 17:16:00] - *** Checking Hardware Version ***
[2024-06-10 17:16:00] - INFO: Hardware - UniFi Dream Machine Pro
[2024-06-10 17:16:00] - INFO: WAN Interface: eth8
[2024-06-10 17:16:00] - *** Checking for required directories ***
[2024-06-10 17:16:00] - INFO: Found - Backup Path: /root/config
[2024-06-10 17:16:00] - INFO: Found - debPath: /etc/wpa_supplicant/packages
[2024-06-10 17:16:00] - INFO: Found - certPath: /etc/wpa_supplicant/conf
[2024-06-10 17:16:00] - INFO: Found - confPath: /etc/wpa_supplicant/conf
[2024-06-10 17:16:00] - *** Checking for required deb packages ***
[2024-06-10 17:16:00] - INFO: Found - deb_pkg: /etc/wpa_supplicant/packages/libpcsclite1_1.9.1-1_arm64.deb
[2024-06-10 17:16:00] - INFO: Found - deb_pkg: /etc/wpa_supplicant/packages/wpasupplicant_2.9.0-21_arm64.deb
[2024-06-10 17:16:00] - *** Checking for required certificates ***
[2024-06-10 17:16:00] - INFO: Found - CA: /etc/wpa_supplicant/conf/CA.pem
[2024-06-10 17:16:00] - INFO: Found - Client: /etc/wpa_supplicant/conf/Client.pem
[2024-06-10 17:16:00] - INFO: Found - PrivateKey: /etc/wpa_supplicant/conf/PrivateKey.pem
[2024-06-10 17:16:00] - *** Checking for wpa_supplicant.conf ***
[2024-06-10 17:16:00] - INFO: Found - wpa_conf: /etc/wpa_supplicant/conf/wpa_supplicant.conf
[2024-06-10 17:16:00] - *** Checking wpa_supplicant service ***
[2024-06-10 17:16:00] - INFO: wpa_supplicant installed: 2:2.9.0-21
[2024-06-10 17:16:00] - INFO: wpa_supplicant is active
[2024-06-10 17:16:00] - INFO: wpa_supplicant is enabled
[2024-06-10 17:16:00] - *** Checking recovery service ***
[2024-06-10 17:16:00] - INFO: wtf-wpa.service is enabled
[2024-06-10 17:16:00] - *** Testing connection to google.com:80 ***
[2024-06-10 17:16:00] - INFO: Attemp 1/3: netcat google.com:80 SUCCESSFUL
[2024-06-10 17:16:00] - *** Process complete ***
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


