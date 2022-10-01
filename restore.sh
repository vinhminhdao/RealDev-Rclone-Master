#!/bin/bash
# https://www.realdev.vn/
# Link hướng dẫn sử dụng: https://www.realdev.vn/downloads/rclone-tu-dong-backup-vps-voi-realdev-rclone-master-script-2756.html#step-1
# Backup lên Cloud tối ưu + Code bởi RealDev.
# Version: 1.5
function pause() {
    read -p "$*"
}
echo -ne "
===================================================================================

    Để có thể Restore - Get dữ liệu từ Internet bạn cần thiết lập Rclone Config trước.
    Hãy chỉnh CONFIG_NAME là tên Rclone mà bạn đặt trong Rclone Config
    Hãy chỉnh SERVER_NAME đúng với tên trong Rclone Config của bạn.

";
echo "":
pause ' Nhấn [Enter] để tiếp tục...';
SERVER_NAME=Backup-System;
CONFIG_NAME=realdev-backup;
RESTORE_DIR="/home/admin/admin_backups/";
SECONDS=0;
size=$(du -sh $RESTORE_DIR | awk '{ print $1}');
echo "Bắt đầu RESTORE Hệ thống $RESTORE_DIR";
rclone copy "$CONFIG_NAME:$SERVER_NAME" $RESTORE_DIR >> /root/restore.log 2>&1;
echo "Tổng Kích thước là: $size, Restore về VPS trong $(($duration / 60)) Phút và $(($duration % 60)) giây."
echo "Múi giờ và Ngày Giờ trên VPS của Bạn là:";
timedatectl;
echo -ne "
==============================================================================================

Chú ý:
         Múi giờ Backup mặc định hàng ngày là lúc 5:00 Sáng. Theo giờ trên VPS.

        Quá trình đã hoàn tất, bạn vui lòng tiến hành Restore trong Directadmin.

==============================================================================================";
echo "";