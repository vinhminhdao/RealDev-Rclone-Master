# https://www.realdev.vn/
# Link hướng dẫn sử dụng: https://www.realdev.vn/downloads/rclone-tu-dong-backup-vps-voi-realdev-rclone-master-script-2756.html#step-1
# Backup lên Cloud tối ưu + Code bởi RealDev.
# Version: 1.6
#!/bin/bash
yum update -y;
cd;
mv /root/restore.sh /root/restore.sh.old;
rm -f restore.sh;
wget https://raw.githubusercontent.com/vinhminhdao/RealDev-Rclone-Master/main/restore.sh -O restore.sh;
chmod +x /root/restore.sh;
nano /root/restore.sh;
echo -ne "
===================================================================================

    Mọi thứ đã hoàn tất. Xin vui lòng check trên Cloud của bạn đã có hay chưa.?
    Nếu chưa có xin vui lòng làm đúng hướng dẫn. Chúc Bạn thành công. ^^
    
    Bất cứ khi nào Bạn muốn Restore chỉ cần chạy lệnh: /root/restore.sh

    Nhấn Enter để Restore ngay. Nhấn CTRL + C để thoát.

===================================================================================";
pause ' Nhấn [Enter] để Restore...';
clear;
/root/restore.sh;
echo -ne "
==============================================================================================

Chú ý:
         Múi giờ Backup mặc định hàng ngày là lúc 5:00 Sáng. Theo giờ trên VPS.

        Quá trình đã hoàn tất, bạn vui lòng tiến hành Restore trong Directadmin.

==============================================================================================";
echo "";
exit;