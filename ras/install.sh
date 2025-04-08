ssh-keygen -R ras.local
ssh -i ~/.ssh/id_rsa hung@ras.local

sudo hostnamectl set-hostname ras

sudo apt update
sudo apt install avahi-daemon
sudo systemctl enable avahi-daemon
sudo systemctl start avahi-daemon

sudo adduser hung
sudo usermod -aG sudo hung

sudo nano /etc/fstab
# /dev/sda1 /mnt/sda1/ ext4 defaults,noatime 0 1
# /dev/sda1 /mnt/sda1/ vfat defaults,noatime,gid=1000,uid=1000 0 1

sudo mkdir /mnt/sda1

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
