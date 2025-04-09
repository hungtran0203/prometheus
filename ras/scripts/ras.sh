ssh -i ~/.ssh/id_rsa hung@ras.local


sudo nano /etc/fstab
# /dev/sda1 /mnt/sda1/ ext4 defaults,noatime 0 1
# /dev/sda1 /mnt/sda1/ vfat defaults,noatime,gid=1000,uid=1000 0 1

sudo mkdir /mnt/sda1
sudo systemctl daemon-reload

sudo apt install samba samba-common-bin

sudo nano /etc/samba/smb.conf


[sda1]
path=/mnt/sda1
writeable=Yes
create mask=0777
directory mask=0777
public=no

sudo systemctl restart smbd

sudo smbpasswd -a username

sudo mount /dev/sda1 /mnt/sda1 -o uid=hung,gid=hung
sudo mount /dev/sda1 /mnt/sda1 -o uid=hung,gid=hung
sudo umount /mnt/sda1