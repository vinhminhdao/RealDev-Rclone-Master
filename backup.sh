#!/bin/bash
# Backup lên Cloud với 2 tài khoản dựa trên ngày chẵn/lẻ
# Tài khoản ODD: Ngày lẻ
# Tài khoản EVEN: Ngày chẵn

# Đặt tên Backup theo ý bạn
SERVER_NAME=Backup-System
TIMESTAMP=$(date +"%F")
BACKUP_DIR="/home/admin/admin_backups/"
SECONDS=0

# Tên Config của rclone cho 2 tài khoản
CONFIG_NAME_ODD="realdev-backup-odd"   # Tài khoản cho ngày lẻ
CONFIG_NAME_EVEN="realdev-backup-even" # Tài khoản cho ngày chẵn

# Xác định ngày của tháng
DAY_OF_MONTH=$(date +%d)

# Kiểm tra dung lượng thư mục backup
size=$(du -sh $BACKUP_DIR | awk '{ print $1 }')

echo -ne "



"
echo "Bắt đầu Backup Hệ thống $BACKUP_DIR"
echo -ne "
==============================================================================================

                        Chỉnh lại tên Rclone Config mà Bạn thiết lập.
                        Vì nếu sai tên Rclone Config sẽ không hoạt động.

"

# Kiểm tra ngày chẵn/lẻ
if (( DAY_OF_MONTH % 2 == 0 )); then
    CONFIG_NAME=$CONFIG_NAME_EVEN
    echo "Ngày hiện tại là ngày chẵn ($DAY_OF_MONTH). Sử dụng cấu hình Rclone cho Tài khoản EVEN: $CONFIG_NAME_EVEN"
else
    CONFIG_NAME=$CONFIG_NAME_ODD
    echo "Ngày hiện tại là ngày lẻ ($DAY_OF_MONTH). Sử dụng cấu hình Rclone cho Tài khoản ODD: $CONFIG_NAME_ODD"
fi

# Thực hiện backup
rclone move $BACKUP_DIR "$CONFIG_NAME:$SERVER_NAME/$TIMESTAMP" >> /root/backup.log 2>&1

# Clean up
echo -ne "
==============================================================================================

        Đang tối ưu hóa dung lượng VPS / Dedicated của Bạn. Vui lòng chờ.

"
echo ""
rm -rf $BACKUP_DIR/*

# Xóa các bản backup cũ hơn 2 tuần
rclone -q --min-age 2w rmdirs "$CONFIG_NAME:$SERVER_NAME" # Remove all empty folders older than 2 weeks
rclone -q --min-age 2w delete "$CONFIG_NAME:$SERVER_NAME" # Remove all backups older than 2 weeks
rclone cleanup "$CONFIG_NAME:" # Cleanup Trash

# Hoàn tất
echo "Hoàn tất"
echo -ne "
==============================================================================================

Chú ý:
        Hệ thống Tự động Xóa các bản Backup trên Cloud cũ hơn 02 Tuần.
        Có nghĩa là sẽ còn các bản Backup của 02 Tuần gần nhất.
        Bạn có thể thay 2w thành số tuần theo nhu cầu.

"
duration=$SECONDS
timedatectl set-timezone Asia/Ho_Chi_Minh
echo "Tổng Kích thước là: $size, Backup lên Cloud trong $(($duration / 60)) phút và $(($duration % 60)) giây."
echo "Múi giờ và Ngày Giờ trên VPS của Bạn là:"
timedatectl
echo -ne "
==============================================================================================

Chú ý:
         Múi giờ Backup mặc định hàng ngày là lúc 5:00 Sáng. Theo giờ trên VPS.

                                Nhấn Enter để thoát.

=============================================================================================="
echo ""
