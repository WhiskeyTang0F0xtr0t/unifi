# WTF Unifi Scripts

Starting point for scripts.

### UniFi OS WPA Supplicant for AT&T Fiber:
------
These scripts do not use the podman method that was depricated by Unifi some time ago and works directly on the hardware's debian OS. 
Additional details on each script will be in the scripts folder.

-  [wtf-check-wpasupp.sh](https://github.com/WhiskeyTang0F0xtr0t/unifi/blob/main/scripts/wtf-check-wpasupp.sh) - Checks the wpa_supplicant service and confirms needed files are present by parsing the existing config.
-  [wtf-install-wpasupp.sh](https://github.com/WhiskeyTang0F0xtr0t/unifi/blob/main/scripts/wtf-install-wpasupp.sh) - Check/repair/install the wpa_supplicant setup on UDM hardware


### Future Plans
------
- `wtf-install-wpasupp.sh` - Add functions from wtf-check-wpasupp.sh for parsing active config & add option flags
- `wtf-install-wpasupp.sh` - Add "auto recover" systemctl service to re-enable wpa_supplicant service after minor UnifiOS update
