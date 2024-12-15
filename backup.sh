#!/bin/bash
# Backup lên OneDrive với 2 tài khoản theo ngày cụ thể
# Tài khoản A: Ngày 3, 5, 7
# Tài khoản B: Ngày 2, 4, 6, CN

# Đặt tên Backup theo ý Bạn. Mặc định là Backup-System
# Chú ý tên Folder Cách nhau bằng dấu Gạch ngang hoặc Gạch dưới để hoạt động tốt nhất.
echo -ne "



";
SERVER_NAME=Backup-System;
TIMESTAMP=$(date +"%F");
BACKUP_DIR="/home/admin/admin_backups/";
SECONDS=0;

# Tên Config của rclone cho 2 tài khoản
CONFIG_NAME_A=realdev-backup-odd; # Tài khoản A, sửa lại theo tên thực tế mà bạn đặt
CONFIG_NAME_B=realdev-backup-even; # Tài khoản B, sửa lại theo tên thực tế mà bạn đặt

# Xác định ngày trong tuần (1=Thứ Hai, 7=Chủ Nhật)
DAY_OF_WEEK=$(date +%u);

# Kiểm tra dung lượng thư mục backup
size=$(du -sh $BACKUP_DIR | awk '{ print $1}');
echo -ne "



";
echo "Bắt đầu Backup Hệ thống $BACKUP_DIR";
echo -ne "
==============================================================================================

                        Chỉnh lại tên Rclone Config mà Bạn thiết lập. 
                        Vì nếu sai tên Rclone Config sẽ không hoạt động.

";

# Chọn tài khoản dựa trên ngày
if [[ "$DAY_OF_WEEK" == "3" || "$DAY_OF_WEEK" == "5" || "$DAY_OF_WEEK" == "7" ]]; then
    CONFIG_NAME=$CONFIG_NAME_A;
    echo "Ngày hiện tại là $DAY_OF_WEEK. Sử dụng cấu hình Rclone cho Tài khoản A: $CONFIG_NAME_A";
elif [[ "$DAY_OF_WEEK" == "2" || "$DAY_OF_WEEK" == "4" || "$DAY_OF_WEEK" == "6" || "$DAY_OF_WEEK" == "7" ]]; then
    CONFIG_NAME=$CONFIG_NAME_B;
    echo "Ngày hiện tại là $DAY_OF_WEEK. Sử dụng cấu hình Rclone cho Tài khoản B: $CONFIG_NAME_B";
else
    echo "Không có lịch backup trong ngày này.";
    exit 0;
fi

# Thực hiện backup
rclone move $BACKUP_DIR "$CONFIG_NAME:$SERVER_NAME/$TIMESTAMP" >> /root/backup.log 2>&1;

# Clean up
echo -ne "
==============================================================================================

        Đang tối ưu hóa dung lượng VPS / Dedicated của Bạn. Vui lòng chờ.

";
echo "";
rm -rf $BACKUP_DIR/*;

# Xóa các bản backup cũ hơn 2 tuần
rclone -q --min-age 2w rmdirs "$CONFIG_NAME:$SERVER_NAME" # Xóa các folder backup cũ hơn 2 tuần
rclone -q --min-age 2w delete "$CONFIG_NAME:$SERVER_NAME" # Xóa các bản backup cũ hơn 2 tuần
rclone cleanup "$CONFIG_NAME:" # Cleanup Trash

# Hoàn tất
echo "Hoàn tất";
echo -ne "
==============================================================================================

Chú ý:
        Hệ thống Tự động Xóa các bản Backup trên Cloud cũ hơn 02 Tuần.
        Có nghĩa là sẽ còn các bản Backup của 02 Tuần gần nhất.
        Bạn có thể thay 2w thành số tuần theo nhu cầu.

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
