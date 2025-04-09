#!/bin/bash

# sudo nano /etc/fstab

sudo mkdir /mnt/sda1

sudo cat <<EOT >> /etc/fstab
/dev/sda1 /mnt/sda1/ vfat defaults,noatime,gid=1000,uid=1000 0 1
EOT

sudo systemctl daemon-reload

sudo apt install samba samba-common-bin

# sudo nano /etc/samba/smb.conf


sudo cat <<EOT >> /etc/samba/smb.conf
[sda1]
path=/mnt/sda1
writeable=Yes
create mask=0777
directory mask=0777
public=no
EOT

sudo systemctl restart smbd

sudo mount /mnt/sda1

sudo smbpasswd -a username
