# WTF Unifi Scripts

Starting point for my Unifi scripts

## [nut-client](nut-client)
Basic configuration for nut-client

## [wpa_supplicant](wpa_supplicant)
These scripts do not use the podman method that was depricated by Unifi some time ago and works directly on the hardware's debian OS. 
Additional details on each script will be in the scripts folder.

- [wtf-wpa.sh](wpa_supplicant/wtf-wpa.sh) - Combines some functionality of wtf-check-wpasupp.sh & wtf-install-wpasupp.sh to create an "all in one" solution.

[Debian packages](wpa_supplicant/deb%20packages)
- `wpasupplicant_2.9.0-21_arm64.deb` - wpasupplicant install file
- `libpcsclite1_1.9.1-1_arm64.deb` - Dependancy for wpasupplicant_2.9.0-21_arm64.deb; All others should be in place on UniFi OS 3.x+

Future Plans
- [X] `wtf-wpa.sh` - Merge both scripts into a new script with combined functionality using switches
- [ ] Add "auto recover" systemctl service to re-enable wpa_supplicant service after minor Unifi OS update(Major will most like wipe the volume)

Deprecated
- [wtf-check-wpasupp.sh](wpa_supplicant/archive/wtf-check-wpasupp.sh) - Checks the wpa_supplicant service and confirms needed files are present by parsing the existing config.
- [wtf-install-wpasupp.sh](wpa_supplicant/archive/wtf-install-wpasupp.sh) - Check/repair/install the wpa_supplicant setup on UDM hardware
