# https://www.realdev.vn/
# Link hướng dẫn sử dụng: https://www.realdev.vn/downloads/rclone-tu-dong-backup-vps-voi-realdev-rclone-master-script-2756.html#step-1
# Backup lên Cloud tối ưu + Code bởi RealDev.
# Version: 1.6
#!/bin/bash
# Đặt tên Backup theo ý Bạn. Mặc định là Backup-System
#Chú ý tên Folder Cách nhau bằng dấu Gạch ngang hoặc Gạch dưới để hoạt động tốt nhất.
echo -ne  "



";
SERVER_NAME=Backup-System;
CONFIG_NAME=realdev-backup;
TIMESTAMP=$(date +"%F");
BACKUP_DIR="/home/admin/admin_backups/";
SECONDS=0;
size=$(du -sh $BACKUP_DIR | awk '{ print $1}');
echo -ne  "



";
echo "Bắt đầu Backup Hệ thống $BACKUP_DIR";
echo -ne "
==============================================================================================

                        Chỉnh lại tên Rclone Config mà Bạn thiết lập. 
                        Vì nếu sai tên Rclone Config sẽ không hoạt động.

";
rclone move $BACKUP_DIR "$CONFIG_NAME:$SERVER_NAME/$TIMESTAMP" >> /root/backup.log 2>&1;
# Clean up
echo -ne "
==============================================================================================

        Đang tối ưu hóa dung lượng VPS / Dedicated của Bạn. Vui lòng chờ.

";
echo "";
rm -rf $BACKUP_DIR/*;

rclone -q --min-age 4w delete "$CONFIG_NAME:$SERVER_NAME" #Remove all backups older than 4 week
rclone -q --min-age 4w rmdirs "$CONFIG_NAME:$SERVER_NAME" #Remove all empty folders older than 4 week
rclone cleanup "$CONFIG_NAME:" #Cleanup Trash
echo "Hoàn tất";
echo -ne "
==============================================================================================

Chú ý:
        Hệ thống Tự động Xóa các bản Backup trên Cloud cũ hơn 04 Tuần.
        Có nghĩa là sẽ còn các bản Backup của 04 Tuần gần nhất.
        Bạn có thể thay 4w thành số tuần theo nhu cầu.

";
duration=$SECONDS;
timedatectl set-timezone Asia/Ho_Chi_Minh;
echo "Tổng Kích thước là: $size, Backup lên Cloud trong $(($duration / 60)) Phút và $(($duration % 60)) giây."
echo "Múi giờ và Ngày Giờ trên VPS của Bạn là:";
timedatectl;
echo -ne "
==============================================================================================

Chú ý:
         Múi giờ Backup mặc định hàng ngày là lúc 5:00 Sáng. Theo giờ trên VPS.

                                Nhấn Enter để thoát.

==============================================================================================";
echo "";