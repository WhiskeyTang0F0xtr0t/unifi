# Scripts

> [!NOTE]
> - I tried to put as much into functions as possible for portability and the potential for others to reuse.
> - I'm sure they're over engineered and/or poorly coded, but I enjoyed the exercise.
## wtf-wpa.sh
Combines some functionality of wtf-check-wpasupp.sh & wtf-install-wpasupp.sh to create an "all in one" solution.
This will probably be the most useful scripts for regular users.

### Usage
```
./wtf-wpa.sh
```

<details>
<summary>Terminal Output Example</summary>
  TODO
</details>

<details>
<summary>Log Output Example</summary>
  TODO
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


