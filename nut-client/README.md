# nut-client

Basic configuration for nut-client

Very rough process outline

### Edit conf files to match your config

### Install nut-client on UDM Pro, etc
```apt-get install nut-client```

### Copy nut config files to /etc/nut
```scp -r ./* root@udmpro:/etc/nut/```

### service restart
```sudo systemctl restart nut-client```

### service status
```sudo systemctl status nut-client```
