# nut-client

Basic configuration for [Network UPS Tool](https://networkupstools.org) (NUT) client

Very rough process outline

## Edit conf files to match your environment

`nut.conf`
*Sets the device as a client(netclient). No changes needed*

`upsmon.conf`
Line 6: UPS name, NUT server IP & monitor credentials for your 

`upssched-cmd`
*Commands run when specific events happen. No changes needed*

`upssched.conf`
Line 21: Change the timer to the number of seconds until the device is powered off

## Install nut-client on UDM Pro, etc
```apt-get install nut-client```

## Verify your device can communicate with the configured NUT server and UPS
IE: `upsc ups@192.168.0.25`

## Copy nut config files to /etc/nut
```scp -r ./* root@udmpro:/etc/nut/```

## service restart
```sudo systemctl restart nut-client```

## service status
```sudo systemctl status nut-client```
