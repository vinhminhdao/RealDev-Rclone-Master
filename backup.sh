# https://www.realdev.vn/
# Backup lên Cloud tối ưu + Code bởi RealDev.
# Version: 1.1
#!/bin/bash
function pause() {
    read -p "$*"
}
# Đặt tên Backup theo ý Bạn. Mặc định là Backup System
SERVER_NAME=Backup System;
TIMESTAMP=$(date +"%F");
BACKUP_DIR="/home/admin/admin_backups/";
SECONDS=0;
size=$(du -sh $BACKUP_DIR | awk '{ print $1}');
echo "Bắt đầu Backup Hệ thống $BACKUP_DIR";
echo -ne "
===================================================================================

   Chỉnh lại tên Rclone Config mà Bạn vừa thiết lập. Mặc định là realdev-backup

===================================================================================";
echo "":
pause ' Nhấn [Enter] để tiếp tục...';
rclone move $BACKUP_DIR "realdev-backup:$SERVER_NAME/$TIMESTAMP" >> /dev/null 2>&1;
# Clean up
echo -ne "
===================================================================================

   Đang tối ưu hóa dung lượng VPS / Dedicated của Bạn. Vui lòng chờ.

===================================================================================";
rm -rf $BACKUP_DIR/*;

rclone -q --min-age 4w delete "realdev-backup:$SERVER_NAME" #Remove all backups older than 4 week
rclone -q --min-age 4w rmdirs "realdev-backup:$SERVER_NAME" #Remove all empty folders older than 4 week
rclone cleanup "realdev-backup:" #Cleanup Trash
echo "Hoàn tất";
echo -ne "
===================================================================================

Chú ý:
        Hệ thống Tự động Xóa các bản Backup trên Cloud cũ hơn 04 Tuần.
        Có nghĩa là sẽ còn các bản Backup của 04 Tuần gần nhất.
        Bạn có thể thay 4w thành số tuần theo nhu cầu trong file /root/backup.sh

===================================================================================";
echo "":
pause ' Nhấn [Enter] để tiếp tục...';
echo '';
duration=$SECONDS
echo "Tổng Kích thước là: $size, Backup lên Cloud trong $(($duration / 60)) Phút và $(($duration % 60)) giây."