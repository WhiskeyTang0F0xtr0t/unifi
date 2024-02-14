# WTF Unifi Scripts

Starting point for my Unifi scripts

### [Scripts](scripts)
These scripts do not use the podman method that was depricated by Unifi some time ago and works directly on the hardware's debian OS. 
Additional details on each script will be in the scripts folder.

- [wtf-check-wpasupp.sh](scripts/wtf-check-wpasupp.sh) - Checks the wpa_supplicant service and confirms needed files are present by parsing the existing config.
- [wtf-install-wpasupp.sh](scripts/wtf-install-wpasupp.sh) - Check/repair/install the wpa_supplicant setup on UDM hardware

### [Debian packages](deb%20packages)
- wpasupplicant_2.9.0-21_arm64.deb - wpasupplicant install file
- libpcsclite1_1.9.1-1_arm64.deb - Dependancy for wpasupplicant_2.9.0-21_arm64.deb; All others should be in place on UniFi OS 3.x+

### Future Plans
------
- `wtf-install-wpasupp.sh` - Add functions from wtf-check-wpasupp.sh for parsing active config & add option flags
- `wtf-install-wpasupp.sh` - Add "auto recover" systemctl service to re-enable wpa_supplicant service after minor Unifi OS update(Major will most like wipe the volume)
