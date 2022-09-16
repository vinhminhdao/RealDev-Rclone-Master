# https://www.realdev.vn/
# Backup lên Cloud tối ưu + Code bởi RealDev.
# Version: 1.1
#!/bin/bash
function pause() {
    read -p "$*"
}
echo -ne "
===================================================================================

    Để bắt đầu, Bạn nhấn Enter để cài đặt bản mới nhất của Rclone từ Trang chủ

===================================================================================";
pause ' Nhấn [Enter] để tiếp tục...';
curl https://rclone.org/install.sh | sudo bash;
clear;
echo -ne "
===================================================================================

    Tiếp theo Bạn copy link này để cài đặt trên máy tính của Bạn:

    Với Windows: https://rclone.org/downloads/

    Với Linux bạn Copy link này và dán vào Terminal để cài đặt:
    curl https://rclone.org/install.sh | sudo bash

===================================================================================";
pause ' Nhấn [Enter] để tiếp tục...';
clear;
echo -ne "
===================================================================================

    Sau khi đã cài đặt xong Bạn nhấn Enter để tiến hành Config cho Rclone:

===================================================================================";
echo "";
echo "";
echo "";
clear;
echo -ne "
===================================================================================

    Tìm đến số có chứa Cloud là Bạn cần rồi nhấn Enter để thiết lập
    Ví dụ: Google là 18 và One Drive là 32.
    Hãy chú ý kiểm tra cho chính xác vì số thứ tự có thể thay đổi theo thời gian

===================================================================================";
pause ' Nhấn [Enter] để tiếp tục...';
clear;
rclone config;