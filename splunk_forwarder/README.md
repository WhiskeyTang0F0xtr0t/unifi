# Scripts

## splunk-forwader.sh
A script to download and setup the splunk-forwader service.

> [!IMPORTANT]
>
> THIS SCRIPT IS NOT FULLY TESTED!
> USE AT YOUR OWN RISK!


```
## USER VARIABLES ##
# Local Splunk user config
localUsername=""
localUserPassword=""

# Splunk server config
splunkServerIP="192.168.0.20"
splunkServerPort="8089"
splunkServerUser=""
splunkServerPassword=""

# dpkg info
dpkgFile="splunkforwarder-9.3.0-51ccf43db5bd-Linux-armv8.deb"
dpkgURL="https://download.splunk.com/products/universalforwarder/releases/9.3.0/linux/splunkforwarder-9.3.0-51ccf43db5bd-Linux-armv8.deb"

```

- [wtf-sf.sh](wtf-sf.sh)

### Make sure SSH is configured on your device.
I like to use SSH private keys instead of passwords and install them using the ```ssh-copy-id``` command.

### Copy the "config" folder to your device
I've created a hostname entry on my internal dns called "udmpro", but you can use your IP address.

```
scp -r splunk root@udmpro:~/```
```
DEMO:~ shaun$ ssh root@udmpro
root@UDMPRO:~# cd splunk/
```
### Script Usage
```
root@UDMPRO:~# ./wtf-sf.sh 
 
   Splunk Forwader [ install ]

   Syntax: wtf-sf.sh [-i]

   options: 

         -i   Install/repair & configure the splunk-forwader.sh service
              Example: splunk-forwader.sh -i

     <none>   Print this Help

root@UDMPRO:~# 
```

<details>
<summary>Terminal Output Example</summary>
</details>

<details>
<summary>Log Output Example</summary>
  
```
```
</details>
------

------

