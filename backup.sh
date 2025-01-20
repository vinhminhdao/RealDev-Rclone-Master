#!/bin/bash
# Backup lên Cloud với 2 tài khoản dựa trên ngày chẵn/lẻ
# Tài khoản ODD: Ngày lẻ
# Tài khoản EVEN: Ngày chẵn

# Đặt tên Backup theo ý bạn
SERVER_NAME=Backup-System
TIMESTAMP=$(date +"%F")
BACKUP_DIR="/home/admin/admin_backups/"
SECONDS=0

# Tên Config của rclone cho 2 tài khoản.
CONFIG_NAME_ODD="realdev-backup"   # Tài khoản cho ngày lẻ
CONFIG_NAME_EVEN="realdev-backup" # Tài khoản cho ngày chẵn

# Thông tin Telegram Bot
echo -ne "
==============================================================================================
HƯỚNG DẪN TÍCH HỢP TELEGRAM VÀO SCRIPT BACKUP
1. TẠO BOT TRÊN TELEGRAM:
   - Mở Telegram và tìm kiếm BotFather.
   - Gửi lệnh /newbot để tạo bot mới.
   - Đặt tên cho Bot, ví dụ: RealDev Backup
   - Thiếtlaajp username cho bot, kết thúc bằng _bot, ví dụ: realdev_backup_bot
   - Làm theo hướng dẫn và nhận API Token từ BotFather.

2. LẤY CHAT ID:
   - Mở trình duyệt và truy cập, (thay <API_TOKEN> bằng token của bạn):
     https://api.telegram.org/bot<API_TOKEN>/getUpdates
     Thay <API_TOKEN> bằng API Token từ bước trên. Ví dụ: https://api.telegram.org/bot7583267403:AAGksSVXeOwuxPdwEZcX4D6IpNow7/getUpdates
   - Gửi tin nhắn bất kỳ cho bot từ tài khoản Telegram của bạn.
   - Refresh đường dẫn trên, bạn sẽ thấy JSON chứa thông tin chat_id.

Chúc bạn tích hợp thành công!
==============================================================================================
"
TELEGRAM_BOT_TOKEN="API"  # Thay API bằng API Token của bot, ví dụ: 7583267403:AAGksSVXeOwuxPdwEZcX4D6IpNow7
TELEGRAM_CHAT_ID="ID"     # Thay ID bằng Chat ID của bạn, ví dụ: 375566796

# Thông tin Email, thay admin@example.com thành Email thực tế của Bạn
EMAIL_TO="admin@example.com" # Email nhận thông báo
HOSTNAME=$(hostname)
EMAIL_SUBJECT="Báo cáo Backup - $HOSTNAME - $TIMESTAMP"


# Gửi thông báo qua Telegram
send_telegram() {
    local MESSAGE="$1"
    local TELEGRAM_API_URL="https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage"

    curl -s -X POST "$TELEGRAM_API_URL" \
        -d chat_id="$TELEGRAM_CHAT_ID" \
        -d text="$MESSAGE" \
        -d parse_mode="HTML" > /dev/null
}

# Gửi email báo cáo
send_email() {
    local MESSAGE="$1"
    echo -e "$MESSAGE" | mail -s "$EMAIL_SUBJECT" "$EMAIL_TO"
}

# Xác định ngày của tháng
DAY_OF_MONTH=$(date +%d)

# Kiểm tra dung lượng thư mục backup
size=$(du -sh $BACKUP_DIR | awk '{ print $1 }')

echo -ne "
==============================================================================================

Bắt đầu Backup Hệ thống $BACKUP_DIR

"
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

# Kiểm tra và thiết lập múi giờ nếu cần, thay Asia/Ho_Chi_Minh thành timezone thực tế bạn cần.
CURRENT_TIMEZONE=$(timedatectl | grep "Time zone" | awk '{print $3}')
CURRENT_UTC_OFFSET=$(timedatectl | grep "Time zone" | awk -F'[()]' '{print $2}')
DESIRED_TIMEZONE="Asia/Ho_Chi_Minh"

# Thực hiện backup
if rclone move "$BACKUP_DIR" "$CONFIG_NAME:$SERVER_NAME/$TIMESTAMP" -P | tee -a /root/backup.log; then
    MESSAGE="🎉 <b>Backup thành công!</b>\n\n\
      🔹 <b>Dung lượng:</b> $size\n\
      🔹 <b>Thời gian:</b> $(($SECONDS / 60)) phút $(($SECONDS % 60)) giây\n\
      🔹 <b>Thư mục:</b> $SERVER_NAME/$TIMESTAMP\n\
      🔹 <b>Múi giờ:</b> $CURRENT_TIMEZONE ($CURRENT_UTC_OFFSET)"

    send_telegram "$MESSAGE"
    send_email "$MESSAGE"
else
    MESSAGE="⚠️ Backup thất bại!\nVui lòng kiểm tra log tại /root/backup.log"
    send_telegram "$MESSAGE"
    send_email "$MESSAGE"
    exit 1
fi

# Clean up
echo -ne "
==============================================================================================

        Đang tối ưu hóa dung lượng VPS / Dedicated của Bạn. Vui lòng chờ.

"
rm -rf $BACKUP_DIR/*

# Xóa các bản backup cũ hơn 2 tuần
rclone -q --min-age 2w --exclude "$TIMESTAMP/**" delete "$CONFIG_NAME:$SERVER_NAME"
rclone -q --min-age 2w --exclude "$TIMESTAMP/**" rmdirs "$CONFIG_NAME:$SERVER_NAME"
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

MESSAGE="✅ Backup hoàn tất!\nDung lượng: $size\nThời gian: $(($duration / 60)) phút $(($duration % 60)) giây.\nMúi giờ hiện tại: $(timedatectl | grep 'Time zone')"
send_telegram "$MESSAGE"
send_email "$MESSAGE"

echo "Tổng Kích thước là: $size, Backup lên Cloud trong $(($duration / 60)) phút và $(($duration % 60)) giây."


if [ "$CURRENT_TIMEZONE" != "$DESIRED_TIMEZONE" ]; then
    echo "Múi giờ hiện tại là $CURRENT_TIMEZONE. Đang thiết lập múi giờ thành $DESIRED_TIMEZONE..."
    timedatectl set-timezone $DESIRED_TIMEZONE
    echo "Múi giờ đã được thay đổi thành $DESIRED_TIMEZONE."
else
    echo "Múi giờ hiện tại : $CURRENT_TIMEZONE."
fi

echo -ne "
==============================================================================================

Chú ý:
         Múi giờ Backup mặc định hàng ngày là lúc 5:00 Sáng. Theo giờ trên VPS.

                                Nhấn Enter để thoát.

=============================================================================================="
