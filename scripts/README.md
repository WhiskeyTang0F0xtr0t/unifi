# Scripts

> [!NOTE]
> - I tried to put as much into functions as possible for portability and the potential for others to reuse.
> - I'm sure they're over engineered and/or poorly coded, but I enjoyed the exercise.

## wtf-check-wpasupp.sh

A non-destructive script to verify the disposition of the wpa_supplicant system service.
The script will output formatted status messages and all errors to the logfile

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

A non-destructive script to verify the disposition of the wpa_supplicant system service.
The script will output formatted status messages and all errors to the log file.

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
