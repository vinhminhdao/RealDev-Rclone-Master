#!/bin/bash
# RealDev Master Backup
# Version: 2.0.0
# Backup lên Cloud với 2 tài khoản dựa trên ngày chẵn/lẻ
# Tài khoản ODD: Ngày lẻ
# Tài khoản EVEN: Ngày chẵn

# Đặt tên Backup theo ý bạn
SERVER_NAME=Backup-System
TIMESTAMP=$(date +"%F")

#Thư mục chứa các File Backup của bạn, trong mã này mình sử dụng DirectAdmin.
#Quảng cáo nhẹ, mình nhận cài DirectAdmin + Tối ưu giá 6 chăm ka. Giá trị ở tối ưu chứ file cài inbox mình share Free.
BACKUP_DIR="/home/admin/admin_backups/"
SECONDS=0

# Tên Config của rclone cho 2 tài khoản, để chung nếu bạn muốn backup hàng ngày như nhau hoặc để trống nếu muốn.
ODD="realdev-backup"  # Tài khoản cho ngày lẻ
EVEN="realdev-backup" # Tài khoản cho ngày chẵn

# Thông tin Telegram Bot
echo -ne "
==============================================================================================
HƯỚNG DẪN TÍCH HỢP TELEGRAM VÀO SCRIPT BACKUP
1. TẠO BOT TRÊN TELEGRAM:
   - Mở Telegram và tìm kiếm BotFather.
   - Gửi lệnh /newbot để tạo bot mới.
   - Đặt tên cho Bot, ví dụ: RealDev Backup
   - Thiết lập username cho bot, kết thúc bằng _bot, ví dụ: realdev_backup_bot
   - Làm theo hướng dẫn và nhận API Token từ BotFather.

2. LẤY CHAT ID:
   - Sau khi có API, click vào Bot của bạn, gõ ký tự tùy ý để gửi tin nhắn, mục đích get ID của BOT.
   - Mở trình duyệt và truy cập, (thay <API_TOKEN> bằng token của bạn):
     https://api.telegram.org/bot<API_TOKEN>/getUpdates
     Thay <API_TOKEN> bằng API Token từ bước trên. Ví dụ: https://api.telegram.org/bot7583267403:AAGksSVXeOwuxPdwEZcX4D6IpNow7/getUpdates
   - Gửi tin nhắn bất kỳ cho bot từ tài khoản Telegram của bạn.
   - Refresh đường dẫn trên, bạn sẽ thấy JSON chứa thông tin chat_id.

Chúc bạn tích hợp thành công!
==============================================================================================
"
TELEGRAM_BOT_TOKEN="API" # Thay API bằng API Token của bot, ví dụ: 7583267403:AAGksSVXeOwuxPdwEZcX4D6IpNow7
TELEGRAM_CHAT_ID="ID"    # Thay ID bằng Chat ID của bạn, ví dụ: 375566796

# Gửi thông báo qua Telegram
send_telegram() {
    local MESSAGE="$1"
    local TELEGRAM_API_URL="https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage"

    # Thêm hiển thị chi tiết
    response=$(curl -s -v -X POST "$TELEGRAM_API_URL" \
        -d chat_id="$TELEGRAM_CHAT_ID" \
        -d text="$MESSAGE" \
        -d parse_mode="HTML" 2>&1)

    # Kiểm tra và hiển thị kết quả
    if echo "$response" | grep -q "\"ok\":true"; then
        echo -ne "
        ✅ Đã gửi tin nhắn Telegram thành công.   

        "
    else
        echo -ne "
        ❌ Lỗi khi gửi tin nhắn Telegram:   
            
        "
        echo "$response"
    fi
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
if ((DAY_OF_MONTH % 2 == 0)); then
    CONFIG_NAME=$EVEN
    echo "Ngày hiện tại là ngày chẵn ($DAY_OF_MONTH). Sử dụng cấu hình Rclone cho Tài khoản EVEN: $EVEN"
else
    CONFIG_NAME=$ODD
    echo "Ngày hiện tại là ngày lẻ ($DAY_OF_MONTH). Sử dụng cấu hình Rclone cho Tài khoản ODD: $ODD"
fi

# Kiểm tra và thiết lập múi giờ nếu cần, thay Asia/Ho_Chi_Minh thành múi giờ thực tế của bạn.
TIMEZONE_INFO=$(timedatectl show --property=Timezone --property=TimeUSec --value)
CURRENT_TIMEZONE=$(echo "$TIMEZONE_INFO" | head -n1)
DESIRED_TIMEZONE="Asia/Ho_Chi_Minh"
UTC_OFFSET=$(date +%z | sed 's/\([+-]\)\([0-9][0-9]\)\([0-9][0-9]\)/\1\2:\3/')

# Hàm tạo thông báo backup
create_backup_message() {
    local size="$1"
    local duration="$2"

    # Định dạng thời gian
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    local time_display="$minutes phút $seconds giây"

    echo "🎉 <b>Backup thành công!</b>

🔹 <b>Dung lượng:</b> $size
🔹 <b>Thời gian:</b> $time_display
🔹 <b>Thư mục:</b> $SERVER_NAME/$TIMESTAMP
🔹 <b>Múi giờ:</b> $CURRENT_TIMEZONE (UTC$UTC_OFFSET)"
}

# Thực hiện backup
if rclone move "$BACKUP_DIR" "$CONFIG_NAME:$SERVER_NAME/$TIMESTAMP" -P | tee -a /root/backup.log; then
    echo -ne "
    
        ✅ Backup thành công.    
    
    "
else
    MESSAGE="⚠️ Backup thất bại!\nVui lòng kiểm tra log tại /root/backup.log"
    send_telegram "$MESSAGE"
    exit 1
fi

# Clean up
echo -ne "
==============================================================================================

        Đang tối ưu hóa dung lượng VPS / Dedicated của Bạn. Vui lòng chờ.

"
rm -rf $BACKUP_DIR/*

# Xóa các bản backup cũ hơn số ngày chỉ định, mặc định là 14 ngày, bạn có thể thay đổi tùy nhu cầu.
DAY=14

if rclone lsd "$CONFIG_NAME:$SERVER_NAME" >/dev/null 2>&1; then
    echo -ne "
        Đang kiểm tra và xóa các thư mục backup cũ hơn $DAY ngày trong $SERVER_NAME...
    "
    for folder in $(rclone lsf "$CONFIG_NAME:$SERVER_NAME" --dirs-only); do
        folder_date=$(basename "$folder")
        if [[ "$folder_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
            folder_timestamp=$(date -d "$folder_date" +%s)
            timestamp_limit=$(date -d "$TIMESTAMP -$DAY days" +%s)
            if ((folder_timestamp < timestamp_limit)); then
                echo -ne "
        Xóa thư mục cũ: $folder
                "
                rclone purge "$CONFIG_NAME:$SERVER_NAME/$folder"
            else
                echo -ne "
        Giữ lại thư mục: $folder (không đủ $DAY ngày)
                "
            fi
        else
            echo -ne "
        Bỏ qua thư mục: $folder (không hợp lệ hoặc không phải dạng ngày)
            "
        fi
    done
    echo -ne "
        Quá trình xóa các thư mục cũ hoàn tất.
    "
else
    echo -ne "
        Không tìm thấy thư mục $SERVER_NAME trên remote $CONFIG_NAME.
    "
fi

rclone cleanup "$CONFIG_NAME:" # Cleanup Trash

# Hoàn tất
echo -ne "
==============================================================================================

TỔNG QUAN:

        Hệ thống Tự động Xóa các bản Backup trên Cloud cũ hơn $DAY ngày.
        Có nghĩa là sẽ còn các bản Backup của $DAY ngày gần nhất.
        Bạn có thể thay $DAY thành số ngày theo nhu cầu.
        Lưu ý: Một số nhà cung cấp không cho phép tùy chọn xóa sạch trong thùng rác,
        Bạn cần xử lý thủ công hoặc giải pháp khác thay cho rclone, nếu dung lượng vượt quá hạn mức.
"
duration=$SECONDS

MESSAGE=$(create_backup_message "$size" "$duration")
send_telegram "$MESSAGE"

echo "Tổng Kích thước là: $size, Backup lên Cloud trong $(($duration / 60)) phút và $(($duration % 60)) giây."

if [ -n "$DESIRED_TIMEZONE" ] && [ "$CURRENT_TIMEZONE" != "$DESIRED_TIMEZONE" ]; then
    if timedatectl list-timezones | grep -q "^$DESIRED_TIMEZONE$"; then
        echo "Múi giờ hiện tại là $CURRENT_TIMEZONE. Đang thiết lập múi giờ thành $DESIRED_TIMEZONE..."
        timedatectl set-timezone "$DESIRED_TIMEZONE"
        echo "Múi giờ đã được thay đổi thành $DESIRED_TIMEZONE."
    else
        echo "Múi giờ $DESIRED_TIMEZONE không hợp lệ. Vui lòng kiểm tra lại."
    fi
else
    echo -ne "
        Múi giờ hiện tại: $CURRENT_TIMEZONE.

        Múi giờ Backup mặc định hàng ngày là lúc 5:00 Sáng. Theo giờ trên VPS.
"
fi

echo -ne "

                                Nhấn Enter để thoát.

=============================================================================================

"
