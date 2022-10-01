# https://www.realdev.vn/
# Link hướng dẫn sử dụng: https://www.realdev.vn/downloads/rclone-tu-dong-backup-vps-voi-realdev-rclone-master-script-2756.html#step-1
# Backup lên Cloud tối ưu + Code bởi RealDev.
# Version: 1.5
#!/bin/bash
yum update -y;
cd;
mv /root/restore.sh /root/restore.sh.old;
rm -f restore.sh;
wget https://raw.githubusercontent.com/vinhminhdao/RealDev-Rclone-Master/main/restore.sh -O restore.sh;
nano /root/restore.sh;