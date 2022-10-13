# https://www.realdev.vn/
# Link hướng dẫn sử dụng: https://www.realdev.vn/downloads/rclone-tu-dong-backup-vps-voi-realdev-rclone-master-script-2756.html#step-1
# Backup lên Cloud tối ưu + Code bởi RealDev.
# Version: 1.6
#!/bin/bash
function pause() {
    read -p "$*"
}
cd;
echo -ne "
===================================================================================

    Để bắt đầu, Bạn nhấn Enter để cài đặt bản mới nhất của Rclone từ Trang chủ.
    Bạn cần Cập nhật hệ thống để các Dịch vụ hoạt động tốt nhất. Chỉ cần Enter.

";
echo "":
pause ' Nhấn [Enter] để tiếp tục...';
yum update -y;
dnf update -y;
curl https://rclone.org/install.sh | sudo bash;
echo -ne "
===================================================================================

    Tiếp theo Bạn copy link này để cài đặt trên máy tính của Bạn:

    Với Windows: https://rclone.org/downloads/

    Với Linux bạn Copy link này và dán vào Terminal để cài đặt:
    
    curl https://rclone.org/install.sh | sudo bash

";
pause ' Nhấn [Enter] để tiếp tục...';
echo -ne "
===================================================================================

    Sau khi đã cài đặt xong Bạn nhấn Enter để tiến hành Config cho Rclone:

";
echo -ne "
===================================================================================

    Tìm đến số có chứa Cloud là Bạn cần rồi nhấn Enter để thiết lập
    Ví dụ: Google là 18 và One Drive là 32.
    Hãy chú ý kiểm tra cho chính xác vì số thứ tự có thể thay đổi theo thời gian

";
pause ' Nhấn [Enter] để tiếp tục...';
rclone config;
echo -ne "
===================================================================================

    Vậy là Bạn đã thiết lập xong Rclone Config.
    Bước tiếp theo, Bạn cần thiết lập cho Rclone có thể Tự động Backup.

";
echo "":
pause ' Nhấn [Enter] để tiếp tục...';
cd;
rm -f backup.sh;
wget https://raw.githubusercontent.com/vinhminhdao/RealDev-Rclone-Master/main/backup.sh -O backup.sh;
chmod +x /root/backup.sh;
yum install nano -y;
dnf install nano -y;
echo -ne "
===================================================================================

    Vậy là đến bước này bạn đã hoàn thành 70% khối lượng công việc.
    Chỉ còn một chút nữa thôi. Let's go.

";
pause ' Nhấn [Enter] để tiếp tục...';
nano /root/backup.sh;
clear;
echo -ne "
===================================================================================

    Trước khi tiếp tục. Bạn hãy Copy dòng dưới để dán vào bước tiếp theo:

    0 5 * * * /root/backup.sh > /root/backup.sh.log 2>&1

    Sau khi dán, bạn nhấn CTRL + X, sau đó nhấn Y và nhấn ENTER để thoát soạn thảo

";
pause ' Nhấn [Enter] để thiết lập Crontab...';
nano /ect/crond.d/crontab -e;
service crond restart;
find . -name "realdev-rclone-master.sh" -delete;
history -c;
echo -ne "
===================================================================================

    Mọi thứ đã hoàn tất. Xin vui lòng check trên Cloud của bạn đã có hay chưa.?
    Nếu chưa có xin vui lòng làm đúng hướng dẫn. Chúc Bạn thành công. ^^
    
    Bất cứ khi nào Bạn muốn Backup chỉ cần chạy lệnh: /root/backup.sh

    Nhấn Enter để Backup ngay. Nhấn CTRL + C để thoát.

===================================================================================";
pause ' Nhấn [Enter] để Backup...';
clear;
/root/backup.sh;