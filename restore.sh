#!/bin/bash
# https://www.realdev.vn/
# Link hướng dẫn sử dụng: https://www.realdev.vn/downloads/rclone-tu-dong-backup-vps-voi-realdev-rclone-master-script-2756.html#step-1
# Backup lên Cloud tối ưu + Code bởi RealDev.
# Version: 1.7
function pause() {
    read -p "$*"
}
echo -ne "
===================================================================================

    Để có thể Restore - Get dữ liệu từ Internet bạn cần thiết lập Rclone Config trước.
    Hãy chỉnh CONFIG_NAME là tên Rclone mà bạn đặt trong Rclone Config
    Hãy chỉnh SERVER_NAME đúng với tên trong Rclone Config của bạn.
    Hãy nhớ thêm FOLDER NGÀY nếu bạn đã sử dụng Rclone Master Script để Backup.

";
echo "":
pause ' Nhấn [Enter] để tiếp tục...';
SERVER_NAME=Backup-System;
FOLDER_DAY=2022-10-10;
CONFIG_NAME=realdev-backup;
RESTORE_DIR="/home/admin/admin_backups/";
echo "Bắt đầu RESTORE Hệ thống $RESTORE_DIR";
rclone copy --progress --stats-one-line "$CONFIG_NAME:$SERVER_NAME/$FOLDER_DAY" $RESTORE_DIR >> /root/restore.log 2>&1;
echo "Múi giờ và Ngày Giờ trên VPS của Bạn là:";
timedatectl;
