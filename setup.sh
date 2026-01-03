#!/bin/bash

# ===================================================
#     RCLONE MASTER - SETUP SCRIPT
# ===================================================
# Script tự động cài đặt và cấu hình Rclone Backup
# Bao gồm: Cài đặt Rclone, Cấu hình Backup/Restore,
#          Cron Jobs, Thông báo Telegram/Email,
#          Cron Jobs, Thông báo Telegram/Email
# ===================================================

set -e

# Set UTF-8 locale for proper character handling
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

# Ensure terminal supports UTF-8 input/output
if command -v stty &>/dev/null; then
    stty -echoctl 2>/dev/null || true
    stty utf8 2>/dev/null || stty iutf8 2>/dev/null || true
fi

# Function to read input with UTF-8 support
read_utf8() {
    local prompt="$1"
    local var_name="$2"
    local default_value="${3:-}"
    
    # Display prompt
    printf '%s' "$prompt"
    
    # Read input with proper encoding
    if [[ -n "$default_value" ]]; then
        printf ' [Mặc định: %s]: ' "$default_value"
    else
        printf ': '
    fi
    
    # Use IFS to preserve spaces and read with UTF-8
    local input
    IFS= read -r input || true
    
    # Set the variable
    if [[ -z "$input" ]] && [[ -n "$default_value" ]]; then
        eval "$var_name=\"$default_value\""
    else
        # Ensure UTF-8 encoding
        eval "$var_name=\$(printf '%s' \"$input\" | iconv -f UTF-8 -t UTF-8 2>/dev/null || printf '%s' \"$input\")"
    fi
}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configuration paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="/root/.rclone-master"
CONFIG_FILE="$CONFIG_DIR/config.conf"
BACKUP_SCRIPT="$CONFIG_DIR/backup.sh"
RESTORE_SCRIPT="$CONFIG_DIR/restore.sh"
CRON_FILE="/tmp/rclone-master-cron"
INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="rclone-master"
INSTALLED_SCRIPT="$INSTALL_DIR/$SCRIPT_NAME"
RMASTER_SCRIPT="$INSTALL_DIR/rmaster"

# Functions
print_header() {
    clear
    echo -e "${CYAN}=================================================="
    echo -e "     RCLONE MASTER - SETUP SCRIPT"
    echo -e "==================================================${NC}"
    echo ""
}

print_sub_header() {
    clear
}

# Install script to /usr/local/bin
install_to_bin() {
    # Create install directory if not exists
    if [[ ! -d "$INSTALL_DIR" ]]; then
        mkdir -p "$INSTALL_DIR"
    fi
    
    # Copy current script to /usr/local/bin
    local current_script="$0"
    if [[ "$current_script" != "$INSTALLED_SCRIPT" ]]; then
        # Install setup script
        cp "$current_script" "$INSTALLED_SCRIPT"
        chmod +x "$INSTALLED_SCRIPT"
    fi
    
    # Create rmaster symlink pointing to installed script
    if [[ -L "$RMASTER_SCRIPT" ]] || [[ ! -f "$RMASTER_SCRIPT" ]]; then
        ln -sf "$INSTALLED_SCRIPT" "$RMASTER_SCRIPT" 2>/dev/null || true
        print_success "Đã tạo symlink: $RMASTER_SCRIPT -> $INSTALLED_SCRIPT"
    fi
}

# Menu: Backup ngay
menu_backup_now() {
    while true; do
        print_sub_header
        echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
        echo -e "${CYAN}  MENU BACKUP NGAY${NC}"
        echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
        echo ""
        
        load_config
        
        # Auto-detect DirectAdmin backup directory if not configured
        if [[ -z "$BACKUP_DIR" ]] || [[ ! -d "$BACKUP_DIR" ]]; then
            if [[ -f "/usr/local/directadmin/directadmin" ]] && [[ -d "/home/admin/admin_backups" ]]; then
                BACKUP_DIR="/home/admin/admin_backups"
                print_info "Phát hiện DirectAdmin, sử dụng thư mục backup: $BACKUP_DIR"
            fi
        fi
        
        # Check backup directory
        local backup_dir_empty=false
        if [[ -z "$BACKUP_DIR" ]] || [[ ! -d "$BACKUP_DIR" ]] || [[ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]]; then
            backup_dir_empty=true
        fi
        
        if [[ "$backup_dir_empty" == true ]]; then
            echo "  1) Chạy backup trước (thư mục backup đang trống)"
            echo "  0) Quay lại menu chính"
            echo ""
            read -rp "Lựa chọn (0-1): " choice
            
            case "$choice" in
                1)
                    if [[ ! -f "$BACKUP_SCRIPT" ]]; then
                        print_error "Chưa có script backup. Vui lòng cấu hình backup trước."
                        echo ""
                        read -rp "Nhấn Enter để tiếp tục..." dummy
                        clear
                        continue
                    fi
                    
                    if [[ -z "$RCLONE_CONFIG_NAME" ]] && [[ -z "$RCLONE_CONFIG_NAME_ODD" ]]; then
                        print_error "Chưa cấu hình Rclone. Vui lòng cấu hình Rclone trước."
                        echo ""
                        read -rp "Nhấn Enter để tiếp tục..." dummy
                        clear
                        continue
                    fi
                    
                    print_info "Đang chạy backup..."
                    echo ""
                    "$BACKUP_SCRIPT"
                    echo ""
                    read -rp "Nhấn Enter để tiếp tục..." dummy
                    clear
                    ;;
                0)
                    break
                    ;;
                *)
                    print_error "Lựa chọn không hợp lệ"
                    sleep 1
                    clear
                    ;;
            esac
        else
            echo "  1) Sync backup lên Cloud"
            echo "  2) Chạy backup mới"
            echo "  0) Quay lại menu chính"
            echo ""
            read -rp "Lựa chọn (0-2): " choice
            
            case "$choice" in
                1)
                    if [[ -z "$RCLONE_CONFIG_NAME" ]] && [[ -z "$RCLONE_CONFIG_NAME_ODD" ]]; then
                        print_error "Chưa cấu hình Rclone. Vui lòng cấu hình Rclone trước."
                        echo ""
                        read -rp "Nhấn Enter để tiếp tục..." dummy
                        clear
                        continue
                    fi
                    
                    # Xác định BACKUP_DIR nếu chưa có
                    if [[ -z "$BACKUP_DIR" ]] || [[ ! -d "$BACKUP_DIR" ]]; then
                        if [[ -f "/usr/local/directadmin/directadmin" ]] && [[ -d "/home/admin/admin_backups" ]]; then
                            BACKUP_DIR="/home/admin/admin_backups"
                            print_info "Phát hiện DirectAdmin, sử dụng thư mục backup: $BACKUP_DIR"
                        else
                            print_error "Không tìm thấy thư mục backup. Vui lòng cấu hình BACKUP_DIR trong config."
                            echo ""
                            read -rp "Nhấn Enter để tiếp tục..." dummy
                            clear
                            continue
                        fi
                    fi
                    
                    # Kiểm tra thư mục backup có file không
                    if [[ ! -d "$BACKUP_DIR" ]] || [[ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]]; then
                        print_error "Thư mục backup trống: $BACKUP_DIR"
                        print_info "Vui lòng chạy backup trước hoặc kiểm tra lại thư mục backup."
                        echo ""
                        read -rp "Nhấn Enter để tiếp tục..." dummy
                        clear
                        continue
                    fi
                    
                    print_info "Thư mục backup: $BACKUP_DIR"
                    print_info "Đang sync backup lên Cloud..."
                    echo ""
                    
                    # Determine config using helper function
                    local CONFIG_NAME=$(get_rclone_config)
                    local TIMESTAMP=$(get_backup_timestamp)
                    
                    # Display backup information
                    display_backup_info "$BACKUP_DIR" "$CONFIG_NAME" "$SERVER_NAME" "$TIMESTAMP"
                    
                    # Tạo thư mục trên cloud nếu chưa có
                    rclone mkdir "$CONFIG_NAME:$SERVER_NAME/$TIMESTAMP" >/dev/null 2>&1 || true
                    
                    # Sync từ BACKUP_DIR lên cloud (copy recursive với nội dung bên trong)
                    print_info "Đang sync nội dung từ $BACKUP_DIR lên Cloud..."
                    echo "Thư mục nguồn: $BACKUP_DIR"
                    echo "Thư mục đích: $CONFIG_NAME:$SERVER_NAME/$TIMESTAMP"
                    echo ""
                    local sync_start_time=$(date +%s)
                    if rclone copy "$BACKUP_DIR/" "$CONFIG_NAME:$SERVER_NAME/$TIMESTAMP/" -P --transfers=10 --checkers=20; then
                        local sync_end_time=$(date +%s)
                        local sync_duration=$((sync_end_time - sync_start_time))
                        local sync_minutes=$((sync_duration / 60))
                        local sync_seconds=$((sync_duration % 60))
                        
                        print_success "Đã sync backup lên Cloud"
                        print_info "Vị trí trên Cloud: $CONFIG_NAME:$SERVER_NAME/$TIMESTAMP"
                        
                        # Hiển thị thông tin về số file đã sync
                        local file_count=$(rclone ls "$CONFIG_NAME:$SERVER_NAME/$TIMESTAMP" 2>/dev/null | wc -l)
                        local backup_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | awk '{print $1}' || echo "N/A")
                        
                        if [[ $file_count -gt 0 ]]; then
                            print_info "Số file đã sync: $file_count"
                        fi
                        
                        # Gửi thông báo Telegram và Email
                        load_config
                        if [[ "$TELEGRAM_ENABLED" == "yes" ]] && [[ -n "$TELEGRAM_BOT_TOKEN" ]] && [[ -n "$TELEGRAM_CHAT_ID" ]]; then
                            local telegram_msg="<b>Sync Backup Thành Công</b>

Thời gian: $(date '+%Y-%m-%d %H:%M:%S')
Thư mục backup: $BACKUP_DIR
Vị trí Cloud: $CONFIG_NAME:$SERVER_NAME/$TIMESTAMP
Số file: $file_count
Kích thước: $backup_size
Thời gian sync: ${sync_minutes} phút ${sync_seconds} giây
Hệ thống: $(hostname)"
                            send_telegram "$telegram_msg" || true
                        fi
                        
                        if [[ "$EMAIL_ENABLED" == "yes" ]]; then
                            local email_subject="Rclone Master - Sync Backup Thành Công"
                            local email_body="Sync Backup Thành Công

Thời gian: $(date '+%Y-%m-%d %H:%M:%S')
Thư mục backup: $BACKUP_DIR
Vị trí Cloud: $CONFIG_NAME:$SERVER_NAME/$TIMESTAMP
Số file: $file_count
Kích thước: $backup_size
Thời gian sync: ${sync_minutes} phút ${sync_seconds} giây
Hệ thống: $(hostname)"
                            send_email_smtp "$email_subject" "$email_body" || true
                        fi
                    else
                        print_error "Sync backup thất bại. Vui lòng kiểm tra lại cấu hình Rclone."
                        
                        # Gửi thông báo lỗi
                        # Load config để lấy thông tin Telegram/Email
                        if [[ -f "$CONFIG_FILE" ]]; then
                            source "$CONFIG_FILE"
                        fi
                        
                        if [[ "$TELEGRAM_ENABLED" == "yes" ]] && [[ -n "$TELEGRAM_BOT_TOKEN" ]] && [[ -n "$TELEGRAM_CHAT_ID" ]]; then
                            local telegram_msg="<b>Sync Backup Thất Bại</b>

Thời gian: $(date '+%Y-%m-%d %H:%M:%S')
Thư mục backup: $BACKUP_DIR
Hệ thống: $(hostname)
Vui lòng kiểm tra lại cấu hình Rclone."
                            send_telegram "$telegram_msg" || true
                        fi
                        
                        if [[ "$EMAIL_ENABLED" == "yes" ]]; then
                            send_email_smtp "Rclone Master - Sync Backup Thất Bại" "Sync backup từ $BACKUP_DIR thất bại. Vui lòng kiểm tra lại cấu hình Rclone." || true
                        fi
                    fi
                    
                    echo ""
                    read -rp "Nhấn Enter để tiếp tục..." dummy
                    clear
                    ;;
                2)
                    if [[ ! -f "$BACKUP_SCRIPT" ]]; then
                        print_error "Chưa có script backup. Vui lòng cấu hình backup trước."
                        echo ""
                        read -rp "Nhấn Enter để tiếp tục..." dummy
                        clear
                        continue
                    fi
                    
                    print_info "Đang chạy backup..."
                    echo ""
                    "$BACKUP_SCRIPT"
                    echo ""
                    read -rp "Nhấn Enter để tiếp tục..." dummy
                    clear
                    ;;
                0)
                    break
                    ;;
                *)
                    print_error "Lựa chọn không hợp lệ"
                    sleep 1
                    clear
                    ;;
            esac
        fi
    done
}

# Menu: Restore ngay
menu_restore_now() {
    while true; do
        print_sub_header
        echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
        echo -e "${CYAN}  MENU RESTORE NGAY${NC}"
        echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
        echo ""
        
        load_config
        
        if [[ -z "$RCLONE_CONFIG_NAME" ]] && [[ -z "$RCLONE_CONFIG_NAME_ODD" ]]; then
            print_error "Chưa cấu hình Rclone. Vui lòng cấu hình Rclone trước."
            echo ""
            read -rp "Nhấn Enter để quay lại..." dummy
            return 1
        fi
        
        # Determine config
        DAY_OF_MONTH=$(date +%d)
        if [[ -n "$RCLONE_CONFIG_NAME_ODD" ]] && [[ -n "$RCLONE_CONFIG_NAME_EVEN" ]]; then
            if ((DAY_OF_MONTH % 2 == 0)); then
                CONFIG_NAME="$RCLONE_CONFIG_NAME_EVEN"
            else
                CONFIG_NAME="$RCLONE_CONFIG_NAME_ODD"
            fi
        else
            CONFIG_NAME="$RCLONE_CONFIG_NAME"
        fi
        
        # List available backup folders
        print_info "Đang tải danh sách backup có sẵn..."
        echo ""
        local folders=()
        while IFS= read -r folder; do
            [[ -n "$folder" ]] && folders+=("$folder")
        done < <(rclone lsf "$CONFIG_NAME:$SERVER_NAME" --dirs-only 2>/dev/null | sort -r | head -20)
        
        if [[ ${#folders[@]} -eq 0 ]]; then
            print_error "Không tìm thấy backup nào trên Cloud"
            echo ""
            read -rp "Nhấn Enter để quay lại..." dummy
            return 1
        fi
        
        echo "Danh sách backup có sẵn:"
        echo ""
        local idx=1
        for folder in "${folders[@]}"; do
            printf "  %2d) %s\n" "$idx" "$folder"
            ((idx++))
        done
        echo ""
        read -rp "Chọn backup cần restore (nhập số): " folder_choice
        
        if [[ ! "$folder_choice" =~ ^[0-9]+$ ]] || [[ "$folder_choice" -lt 1 ]] || [[ "$folder_choice" -gt ${#folders[@]} ]]; then
            print_error "Lựa chọn không hợp lệ"
            echo ""
            read -rp "Nhấn Enter để tiếp tục..." dummy
            clear
            continue
        fi
        
        local selected_folder="${folders[$((folder_choice - 1))]}"
        selected_folder="${selected_folder%/}"  # Remove trailing slash
        
        # Ask for subfolder if needed
        echo ""
        print_info "Backup đã chọn: $selected_folder"
        read -rp "Nhập tên folder con (Enter để restore toàn bộ): " subfolder
        
        local restore_path="$CONFIG_NAME:$SERVER_NAME/$selected_folder"
        if [[ -n "$subfolder" ]]; then
            restore_path="$restore_path/$subfolder"
        fi
        
        # Determine restore destination (auto-detect DirectAdmin)
        local default_restore_dir=""
        if [[ -f "/usr/local/directadmin/directadmin" ]] && [[ -d "/home/admin/admin_backups" ]]; then
            default_restore_dir="/home/admin/admin_backups"
            print_info "Phát hiện DirectAdmin, thư mục restore mặc định: $default_restore_dir"
        else
            default_restore_dir="${BACKUP_DIR:-/root/restore}"
        fi
        
        echo ""
        read -rp "Nhập thư mục restore đến (mặc định: $default_restore_dir): " restore_dest
        restore_dest="${restore_dest:-$default_restore_dir}"
        
        if [[ -z "$restore_dest" ]]; then
            print_error "Thư mục restore không được để trống"
            echo ""
            read -rp "Nhấn Enter để tiếp tục..." dummy
            clear
            continue
        fi
        
        # Create restore directory
        mkdir -p "$restore_dest" 2>/dev/null || true
        
        echo ""
        print_info "Đang restore từ: $restore_path"
        print_info "Đến: $restore_dest"
        echo ""
        read -rp "Bạn có chắc chắn muốn restore? (y/N): " confirm
        
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            print_info "Đang restore..."
            echo ""
            local restore_start_time=$(date +%s)
            rclone copy -P "$restore_path" "$restore_dest" 2>&1 | tee "$RESTORE_LOG"
            local restore_exit_code=${PIPESTATUS[0]}
            local restore_end_time=$(date +%s)
            local restore_duration=$((restore_end_time - restore_start_time))
            local restore_minutes=$((restore_duration / 60))
            local restore_seconds=$((restore_duration % 60))
            
            if [[ $restore_exit_code -eq 0 ]]; then
                print_success "Restore thành công!"
                print_info "Dữ liệu đã được restore vào: $restore_dest"
                
                # Gửi thông báo Telegram và Email
                load_config
                if [[ "$TELEGRAM_ENABLED" == "yes" ]] && [[ -n "$TELEGRAM_BOT_TOKEN" ]] && [[ -n "$TELEGRAM_CHAT_ID" ]]; then
                    local restore_size=$(du -sh "$restore_dest" 2>/dev/null | awk '{print $1}' || echo "N/A")
                    local telegram_msg="<b>Restore Thành Công</b>

Thời gian: $(date '+%Y-%m-%d %H:%M:%S')
Nguồn: $restore_path
Đích: $restore_dest
Kích thước: $restore_size
Thời gian restore: ${restore_minutes} phút ${restore_seconds} giây
Hệ thống: $(hostname)"
                    send_telegram "$telegram_msg" || true
                fi
                
                if [[ "$EMAIL_ENABLED" == "yes" ]]; then
                    local restore_size=$(du -sh "$restore_dest" 2>/dev/null | awk '{print $1}' || echo "N/A")
                    local email_subject="Rclone Master - Restore Thành Công"
                    local email_body="Restore Thành Công

Thời gian: $(date '+%Y-%m-%d %H:%M:%S')
Nguồn: $restore_path
Đích: $restore_dest
Kích thước: $restore_size
Thời gian restore: ${restore_minutes} phút ${restore_seconds} giây
Hệ thống: $(hostname)"
                    send_email_smtp "$email_subject" "$email_body" || true
                fi
            else
                print_error "Restore thất bại. Vui lòng kiểm tra log."
                
                # Gửi thông báo lỗi
                load_config
                if [[ "$TELEGRAM_ENABLED" == "yes" ]] && [[ -n "$TELEGRAM_BOT_TOKEN" ]] && [[ -n "$TELEGRAM_CHAT_ID" ]]; then
                    local telegram_msg="<b>Restore Thất Bại</b>

Thời gian: $(date '+%Y-%m-%d %H:%M:%S')
Nguồn: $restore_path
Đích: $restore_dest
Hệ thống: $(hostname)
Vui lòng kiểm tra log: $RESTORE_LOG"
                    send_telegram "$telegram_msg" || true
                fi
                
                if [[ "$EMAIL_ENABLED" == "yes" ]]; then
                    send_email_smtp "Rclone Master - Restore Thất Bại" "Restore từ $restore_path đến $restore_dest thất bại. Vui lòng kiểm tra log: $RESTORE_LOG" || true
                fi
            fi
        else
            print_info "Đã hủy restore"
        fi
        
        echo ""
        read -rp "Nhấn Enter để tiếp tục..." dummy
        clear
    done
}

print_success() {
    echo -e "${GREEN}$1${NC}"
}

print_error() {
    echo -e "${RED}$1${NC}"
}

print_info() {
    echo "$1"
}

print_step() {
    echo -e "${GREEN}$1${NC}"
}

print_warning() {
    echo "$1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Script này cần chạy với quyền root!"
        print_info "Sử dụng: sudo $0"
        exit 1
    fi
}

# Create config directory
create_config_dir() {
    mkdir -p "$CONFIG_DIR"
    chmod 700 "$CONFIG_DIR"
}

# Load existing config
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        
        # Auto-detect DirectAdmin backup directory if not configured
        if [[ -z "$BACKUP_DIR" ]] || [[ ! -d "$BACKUP_DIR" ]]; then
            if [[ -f "/usr/local/directadmin/directadmin" ]] && [[ -d "/home/admin/admin_backups" ]]; then
                BACKUP_DIR="/home/admin/admin_backups"
            fi
        fi
        
        return 0
    fi
    
    # Even if no config file, try to detect DirectAdmin
    if [[ -f "/usr/local/directadmin/directadmin" ]] && [[ -d "/home/admin/admin_backups" ]]; then
        BACKUP_DIR="/home/admin/admin_backups"
    fi
    
    return 1
}

# Save config
save_config() {
    cat > "$CONFIG_FILE" <<EOF
# Rclone Master Configuration
# Generated: $(date)

# Rclone Configuration
RCLONE_CONFIG_NAME="${RCLONE_CONFIG_NAME:-}"
RCLONE_CONFIG_NAME_ODD="${RCLONE_CONFIG_NAME_ODD:-}"
RCLONE_CONFIG_NAME_EVEN="${RCLONE_CONFIG_NAME_EVEN:-}"
SERVER_NAME="${SERVER_NAME:-Backup-System}"

# Backup Configuration
BACKUP_DIR="${BACKUP_DIR:-}"

# Cron Configuration
BACKUP_CRON_SCHEDULE="${BACKUP_CRON_SCHEDULE:-0 5 * * *}"
CLEANUP_DAYS="${CLEANUP_DAYS:-14}"

# Notification Configuration
TELEGRAM_ENABLED="${TELEGRAM_ENABLED:-no}"
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

EMAIL_ENABLED="${EMAIL_ENABLED:-no}"
EMAIL_SMTP_SERVER="${EMAIL_SMTP_SERVER:-}"
EMAIL_SMTP_PORT="${EMAIL_SMTP_PORT:-587}"
EMAIL_SMTP_TLS="${EMAIL_SMTP_TLS:-yes}"
EMAIL_TO="${EMAIL_TO:-}"
EMAIL_FROM="${EMAIL_FROM:-}"
EMAIL_FROM_NAME="${EMAIL_FROM_NAME:-}"
EMAIL_USER="${EMAIL_USER:-}"
EMAIL_PASSWORD="${EMAIL_PASSWORD:-}"
EMAIL_SUBJECT="${EMAIL_SUBJECT:-Rclone Backup Notification}"

# System Configuration
TIMEZONE="${TIMEZONE:-Asia/Ho_Chi_Minh}"
EOF
    chmod 600 "$CONFIG_FILE"
}

# Install rclone
install_rclone() {
    print_step "Kiểm tra và cài đặt Rclone..."
    
    if command -v rclone &>/dev/null; then
        local current_version=$(rclone version | head -n1 | awk '{print $2}')
        print_info "Rclone đã được cài đặt: v$current_version"
        read -rp "Bạn có muốn cập nhật lên phiên bản mới nhất? (y/N): " update_rclone
        if [[ "$update_rclone" =~ ^[Yy]$ ]]; then
            print_step "Đang cập nhật Rclone..."
            curl https://rclone.org/install.sh | sudo bash
            print_success "Đã cập nhật Rclone"
        fi
    else
        print_step "Đang cài đặt Rclone..."
        curl https://rclone.org/install.sh | sudo bash
        print_success "Đã cài đặt Rclone"
    fi
    
    # Verify installation
    if command -v rclone &>/dev/null; then
        local version=$(rclone version | head -n1 | awk '{print $2}')
        print_success "Rclone v$version đã sẵn sàng"
        return 0
    else
        print_error "Không thể cài đặt Rclone"
        return 1
    fi
}

# List and select Rclone config
select_rclone_config() {
    local purpose="$1"  # "ODD", "EVEN", or "SINGLE"
    local configs=()
    local config_names=()
    
    # Get list of existing remotes
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            config_names+=("$line")
        fi
    done < <(rclone listremotes 2>/dev/null | sed 's/:$//' || true)
    
    # Display menu to stderr (so it shows on screen but not captured)
    echo "" >&2
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}" >&2
    echo -e "${CYAN}  CHỌN RCLONE CONFIG${NC}" >&2
    if [[ "$purpose" == "ODD" ]]; then
        echo -e "${CYAN}  (Cho ngày LẺ)${NC}" >&2
    elif [[ "$purpose" == "EVEN" ]]; then
        echo -e "${CYAN}  (Cho ngày CHẴN)${NC}" >&2
    fi
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}" >&2
    echo "" >&2
    
    # Display existing configs
    if [[ ${#config_names[@]} -gt 0 ]]; then
        print_info "Các config Rclone đã có sẵn:" >&2
        echo "" >&2
        local idx=1
        for config in "${config_names[@]}"; do
            # Get config type
            local config_type=$(rclone config show "$config" 2>/dev/null | grep "^type" | awk '{print $3}' || echo "unknown")
            echo -e "  ${GREEN}$idx${NC}) $config (Type: $config_type)" >&2
            configs+=("$config")
            ((idx++))
        done
        echo "" >&2
        echo -e "  ${GREEN}0${NC}) Tạo config mới" >&2
        echo "" >&2
        print_info "Cách chọn:" >&2
        echo "  - Chọn config có sẵn: nhập số (1-${#config_names[@]})" >&2
        echo "  - Tạo config mới: nhập 0" >&2
        echo "" >&2
        read -rp "Nhập số lựa chọn: " choice
        
        # Validate choice
        if [[ "$choice" =~ ^[0-9]+$ ]]; then
            if [[ "$choice" -eq 0 ]]; then
                # Create new config
                clear
                print_info "Đang tạo config mới..."
                rclone config
                clear
                # Get the newly created config (last one in list)
                local new_configs=()
                while IFS= read -r line; do
                    [[ -n "$line" ]] && new_configs+=("$line")
                done < <(rclone listremotes 2>/dev/null | sed 's/:$//' || true)
                
                # Find the new config (one that wasn't in the original list)
                local selected_config=""
                for new_config in "${new_configs[@]}"; do
                    local found=0
                    for old_config in "${config_names[@]}"; do
                        if [[ "$new_config" == "$old_config" ]]; then
                            found=1
                            break
                        fi
                    done
                    if [[ $found -eq 0 ]]; then
                        selected_config="$new_config"
                        break
                    fi
                done
                
                if [[ -n "$selected_config" ]]; then
                    echo "$selected_config"
                else
                    # If can't find new one, ask user
                    read -rp "Nhập tên config vừa tạo: " selected_config
                    echo "$selected_config"
                fi
            elif [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#configs[@]} ]]; then
                # Use existing config
                local selected_idx=$((choice - 1))
                echo "${configs[$selected_idx]}"
            else
                print_error "Lựa chọn không hợp lệ. Vui lòng chọn từ 0 đến ${#configs[@]}"
                return 1
            fi
        else
            print_error "Vui lòng nhập số"
            return 1
        fi
    else
        # No existing configs - automatically create new one
        print_info "Chưa có config nào."
        print_info "Bạn cần tạo config mới..."
        echo ""
        read -rp "Nhấn Enter để mở rclone config..." dummy
        clear
        rclone config
        clear
        
        # Get the newly created config
        local new_configs=()
        while IFS= read -r line; do
            [[ -n "$line" ]] && new_configs+=("$line")
        done < <(rclone listremotes 2>/dev/null | sed 's/:$//' || true)
        
        if [[ ${#new_configs[@]} -gt 0 ]]; then
            print_success "Đã tạo config: ${new_configs[0]}"
            echo "${new_configs[0]}"
        else
            print_warning "Không thể tự động detect config mới."
            read -rp "Nhập tên config vừa tạo: " selected_config
            if [[ -n "$selected_config" ]]; then
                echo "$selected_config"
            else
                print_error "Tên config không được để trống"
                return 1
            fi
        fi
    fi
}

# Configure rclone
configure_rclone() {
    print_step "Cấu hình Rclone..."
    echo ""
    print_info "Bạn sẽ được yêu cầu cấu hình Rclone remote."
    print_info "Nếu bạn muốn sử dụng 2 tài khoản (ngày chẵn/lẻ), hãy cấu hình cả 2."
    echo ""
    
    read -rp "Bạn muốn sử dụng 2 tài khoản backup (ngày chẵn/lẻ)? (y/N): " use_two_accounts
    
    if [[ "$use_two_accounts" =~ ^[Yy]$ ]]; then
        # Configure for ODD days
        clear
        echo ""
        print_info "Cấu hình cho ngày LẺ..."
        local config_odd
        config_odd=$(select_rclone_config "ODD")
        if [[ -n "$config_odd" ]] && [[ "$config_odd" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            RCLONE_CONFIG_NAME_ODD="$config_odd"
            clear
            echo ""
            print_success "Đã chọn config cho ngày LẺ: $config_odd"
        else
            clear
            echo ""
            print_error "Không thể lấy config cho ngày LẺ"
            return 1
        fi
        
        # Configure for EVEN days
        echo ""
        print_info "Cấu hình cho ngày CHẴN..."
        local config_even
        config_even=$(select_rclone_config "EVEN")
        if [[ -n "$config_even" ]] && [[ "$config_even" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            RCLONE_CONFIG_NAME_EVEN="$config_even"
            clear
            echo ""
            print_success "Đã chọn config cho ngày CHẴN: $config_even"
        else
            clear
            echo ""
            print_error "Không thể lấy config cho ngày CHẴN"
            return 1
        fi
        
        RCLONE_CONFIG_NAME=""
    else
        # Single account
        clear
        echo ""
        local config_name
        config_name=$(select_rclone_config "SINGLE")
        if [[ -n "$config_name" ]] && [[ "$config_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            RCLONE_CONFIG_NAME="$config_name"
            clear
            echo ""
            print_success "Đã chọn config: $config_name"
        else
            clear
            echo ""
            print_error "Không thể lấy config"
            return 1
        fi
        
        RCLONE_CONFIG_NAME_ODD=""
        RCLONE_CONFIG_NAME_EVEN=""
    fi
    
    echo ""
    read -rp "Nhập tên thư mục backup trên Cloud (mặc định: Backup-System): " server_name
    SERVER_NAME="${server_name:-Backup-System}"
    clear
    
    # Configure backup directory on VPS
    echo ""
    print_step "Cấu hình thư mục backup trên VPS..."
    echo ""
    
    # Auto-detect DirectAdmin backup directory
    local default_backup_dir=""
    if [[ -f "/usr/local/directadmin/directadmin" ]] && [[ -d "/home/admin/admin_backups" ]]; then
        default_backup_dir="/home/admin/admin_backups"
        print_info "Phát hiện DirectAdmin, thư mục backup mặc định: $default_backup_dir"
    else
        default_backup_dir="/root/backups"
        print_info "Thư mục backup mặc định: $default_backup_dir"
    fi
    
    echo ""
    print_info "Thư mục backup hiện tại: ${BACKUP_DIR:-Chưa cấu hình}"
    echo ""
    read -rp "Nhập thư mục backup trên VPS [Mặc định: $default_backup_dir]: " backup_dir_input
    
    if [[ -z "$backup_dir_input" ]]; then
        BACKUP_DIR="$default_backup_dir"
    else
        BACKUP_DIR="$backup_dir_input"
    fi
    
    # Validate và tạo thư mục nếu chưa tồn tại
    if [[ ! -d "$BACKUP_DIR" ]]; then
        echo ""
        read -rp "Thư mục chưa tồn tại. Bạn có muốn tạo thư mục $BACKUP_DIR? (Y/n): " create_dir
        if [[ ! "$create_dir" =~ ^[Nn]$ ]]; then
            mkdir -p "$BACKUP_DIR" 2>/dev/null || {
                print_error "Không thể tạo thư mục $BACKUP_DIR"
                BACKUP_DIR="$default_backup_dir"
                print_info "Sử dụng thư mục mặc định: $BACKUP_DIR"
            }
            if [[ -d "$BACKUP_DIR" ]]; then
                print_success "Đã tạo thư mục: $BACKUP_DIR"
            fi
        else
            BACKUP_DIR="$default_backup_dir"
            print_info "Sử dụng thư mục mặc định: $BACKUP_DIR"
        fi
    fi
    
    clear
    
    # Configure cron schedule after selecting backup folder
    echo ""
    print_step "Cấu hình lịch backup tự động..."
    echo ""
    print_info "Lịch backup mặc định: 0 5 * * * (5:00 AM hàng ngày)"
    echo ""
    echo "Ví dụ lịch backup:"
    echo "  - 0 5 * * *     : 5:00 AM hàng ngày"
    echo "  - 0 2 * * *     : 2:00 AM hàng ngày"
    echo "  - 0 3 * * 0     : 3:00 AM mỗi Chủ nhật"
    echo "  - 0 */6 * * *   : Mỗi 6 giờ"
    echo ""
    read -rp "Nhập lịch backup cron (Enter để dùng mặc định: 0 5 * * *): " cron_schedule
    
    if [[ -z "$cron_schedule" ]]; then
        BACKUP_CRON_SCHEDULE="0 5 * * *"
    else
        # Validate cron format (basic check)
        if echo "$cron_schedule" | grep -qE '^[0-9\*\/\-\, ]+$' && [[ $(echo "$cron_schedule" | tr ' ' '\n' | wc -l) -eq 5 ]]; then
            BACKUP_CRON_SCHEDULE="$cron_schedule"
        else
            print_warning "Lịch cron không hợp lệ. Sử dụng mặc định: 0 5 * * *"
            BACKUP_CRON_SCHEDULE="0 5 * * *"
        fi
    fi
    
    clear
    print_success "Đã cấu hình Rclone"
    print_info "Thư mục backup trên Cloud: $SERVER_NAME"
    print_info "Thư mục backup trên VPS: $BACKUP_DIR"
    print_info "Lịch backup: $BACKUP_CRON_SCHEDULE"
    echo ""
    read -rp "Nhấn Enter để tiếp tục..." dummy
    clear
}

# Scan users from /home directory (non-DirectAdmin)
scan_system_users() {
    local users=()
    if [[ -d "/home" ]]; then
        while IFS= read -r user_dir; do
            local user=$(basename "$user_dir")
            # Skip system users and common directories
            if [[ ! "$user" =~ ^(lost\+found|backup|admin)$ ]] && [[ -d "$user_dir" ]]; then
                users+=("$user")
            fi
        done < <(find /home -maxdepth 1 -type d 2>/dev/null)
    fi
    
    # Also check /var/www for web users
    if [[ -d "/var/www" ]]; then
        while IFS= read -r user_dir; do
            local user=$(basename "$user_dir")
            if [[ ! "$user" =~ ^(html|default)$ ]] && [[ -d "$user_dir" ]]; then
                users+=("$user")
            fi
        done < <(find /var/www -maxdepth 1 -type d 2>/dev/null)
    fi
    
    printf '%s\n' "${users[@]}"
}


# Configure Telegram notifications
configure_telegram() {
    print_step "Cấu hình thông báo Telegram..."
    
    read -rp "Bạn có muốn bật thông báo Telegram? (y/N): " enable_telegram
    
    if [[ "$enable_telegram" =~ ^[Yy]$ ]]; then
        TELEGRAM_ENABLED="yes"
        
        echo ""
        print_info "Hướng dẫn lấy Telegram Bot Token và Chat ID:"
        echo "  1. Tạo bot qua @BotFather trên Telegram"
        echo "  2. Nhận API Token từ BotFather"
        echo "  3. Gửi tin nhắn cho bot của bạn"
        echo "  4. Truy cập: https://api.telegram.org/bot<TOKEN>/getUpdates"
        echo "  5. Tìm 'chat' -> 'id' trong JSON response"
        echo ""
        
        read -rp "Nhập Telegram Bot Token: " bot_token
        read -rp "Nhập Telegram Chat ID: " chat_id
        
        if [[ -n "$bot_token" ]] && [[ -n "$chat_id" ]]; then
            TELEGRAM_BOT_TOKEN="$bot_token"
            TELEGRAM_CHAT_ID="$chat_id"
            
            # Test Telegram notification
            print_info "Đang kiểm tra kết nối Telegram..."
            local test_message="Rclone Master đã được cấu hình thành công!"
            local response=$(curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
                -d chat_id="$TELEGRAM_CHAT_ID" \
                -d text="$test_message" \
                -d parse_mode="HTML" 2>&1)
            
            if echo "$response" | grep -q "\"ok\":true"; then
                print_success "Đã gửi thông báo test thành công!"
            else
                print_warning "Không thể gửi thông báo test. Vui lòng kiểm tra lại Token và Chat ID"
            fi
        else
            print_error "Token hoặc Chat ID không hợp lệ"
            TELEGRAM_ENABLED="no"
        fi
    else
        TELEGRAM_ENABLED="no"
    fi
}

# Install email tools
install_email_tools() {
    local need_install=false
    
    # Check Python first (most reliable)
    if ! command -v python3 &>/dev/null && ! command -v python &>/dev/null; then
        need_install=true
        if command -v apt &>/dev/null; then
            apt-get update -qq >/dev/null 2>&1 && apt-get install -y python3 >/dev/null 2>&1 || true
        elif command -v yum &>/dev/null; then
            yum install -y python3 >/dev/null 2>&1 || true
        elif command -v dnf &>/dev/null; then
            dnf install -y python3 >/dev/null 2>&1 || true
        fi
    fi
    
    # Try sendEmail as backup
    if ! command -v sendEmail &>/dev/null; then
        need_install=true
        if command -v apt &>/dev/null; then
            apt-get update -qq >/dev/null 2>&1 && apt-get install -y sendemail >/dev/null 2>&1 || true
        elif command -v yum &>/dev/null; then
            yum install -y sendemail >/dev/null 2>&1 || true
        elif command -v dnf &>/dev/null; then
            dnf install -y sendemail >/dev/null 2>&1 || true
        fi
    fi
    
    # Check if tools are available
    if command -v python3 &>/dev/null || command -v python &>/dev/null || command -v sendEmail &>/dev/null; then
        print_success "Công cụ gửi email đã sẵn sàng"
    else
        print_error "Không thể cài đặt công cụ gửi email"
    fi
}

# Helper function: Get Rclone config name based on day (odd/even)
get_rclone_config() {
    local day_of_month=$(date +%d)
    if [[ -n "$RCLONE_CONFIG_NAME_ODD" ]] && [[ -n "$RCLONE_CONFIG_NAME_EVEN" ]]; then
        if ((day_of_month % 2 == 0)); then
            echo "$RCLONE_CONFIG_NAME_EVEN"
        else
            echo "$RCLONE_CONFIG_NAME_ODD"
        fi
    else
        echo "${RCLONE_CONFIG_NAME:-}"
    fi
}

# Helper function: Get backup timestamp
get_backup_timestamp() {
    date +"%Y-%m-%d"
}

# Helper function: Display backup information
display_backup_info() {
    local backup_dir="$1"
    local config_name="$2"
    local server_name="$3"
    local timestamp="$4"
    
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  THÔNG TIN BACKUP"
    echo "═══════════════════════════════════════════════════════════"
    echo "Thư mục backup: $backup_dir"
    echo "Cloud config: $config_name"
    echo "Vị trí trên Cloud: $config_name:$server_name/$timestamp"
    
    # Display backup directory size
    if [[ -d "$backup_dir" ]]; then
        local backup_size=$(du -sh "$backup_dir" 2>/dev/null | awk '{print $1}' || echo "N/A")
        local file_count=$(find "$backup_dir" -type f 2>/dev/null | wc -l)
        echo "Kích thước: $backup_size"
        echo "Số file: $file_count"
    fi
    echo "═══════════════════════════════════════════════════════════"
    echo ""
}

# Helper function: Get Rclone config name based on day (odd/even)
get_rclone_config() {
    local day_of_month=$(date +%d)
    if [[ -n "$RCLONE_CONFIG_NAME_ODD" ]] && [[ -n "$RCLONE_CONFIG_NAME_EVEN" ]]; then
        if ((day_of_month % 2 == 0)); then
            echo "$RCLONE_CONFIG_NAME_EVEN"
        else
            echo "$RCLONE_CONFIG_NAME_ODD"
        fi
    else
        echo "${RCLONE_CONFIG_NAME:-}"
    fi
}

# Helper function: Get backup timestamp
get_backup_timestamp() {
    date +"%Y-%m-%d"
}

# Helper function: Display backup information
display_backup_info() {
    local backup_dir="$1"
    local config_name="$2"
    local server_name="$3"
    local timestamp="$4"
    
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  THÔNG TIN BACKUP"
    echo "═══════════════════════════════════════════════════════════"
    echo "Thư mục backup: $backup_dir"
    echo "Cloud config: $config_name"
    echo "Vị trí trên Cloud: $config_name:$server_name/$timestamp"
    
    # Display backup directory size
    if [[ -d "$backup_dir" ]]; then
        local backup_size=$(du -sh "$backup_dir" 2>/dev/null | awk '{print $1}' || echo "N/A")
        local file_count=$(find "$backup_dir" -type f 2>/dev/null | wc -l)
        echo "Kích thước: $backup_size"
        echo "Số file: $file_count"
    fi
    echo "═══════════════════════════════════════════════════════════"
    echo ""
}

# Send Telegram notification (for use in menu functions)
send_telegram() {
    if [[ "$TELEGRAM_ENABLED" == "yes" ]] && [[ -n "$TELEGRAM_BOT_TOKEN" ]] && [[ -n "$TELEGRAM_CHAT_ID" ]]; then
        local message="$1"
        curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
            -d chat_id="$TELEGRAM_CHAT_ID" \
            -d text="$message" \
            -d parse_mode="HTML" >/dev/null 2>&1 || true
    fi
}

# Send email via SMTP (simplified)
send_email_smtp() {
    local subject="$1"
    local body="$2"
    
    # Validate required parameters
    if [[ "$EMAIL_ENABLED" != "yes" ]]; then
        echo "Email không được bật trong config" >&2
        return 1
    fi
    
    if [[ -z "$EMAIL_TO" ]]; then
        echo "EMAIL_TO không được cấu hình" >&2
        return 1
    fi
    
    if [[ -z "$EMAIL_SMTP_SERVER" ]]; then
        echo "EMAIL_SMTP_SERVER không được cấu hình" >&2
        return 1
    fi
    
    if [[ -z "$EMAIL_USER" ]] || [[ -z "$EMAIL_PASSWORD" ]]; then
        echo "EMAIL_USER hoặc EMAIL_PASSWORD không được cấu hình" >&2
        return 1
    fi
    
    # Method 1: Python (most reliable, works everywhere)
    if command -v python3 &>/dev/null || command -v python &>/dev/null; then
        local python_cmd=""
        if command -v python3 &>/dev/null; then
            python_cmd="python3"
        else
            python_cmd="python"
        fi
        
        local py_script=$(mktemp)
        
        # Create Python script that receives data via environment variables
        cat > "$py_script" <<'PYEOF'
# -*- coding: utf-8 -*-
import smtplib
from email.mime.text import MIMEText
from email.header import Header
import sys
import os

# Force UTF-8 encoding for stdout/stderr
if sys.version_info[0] < 3:
    import codecs
    sys.stdout = codecs.getwriter('utf-8')(sys.stdout)
    sys.stderr = codecs.getwriter('utf-8')(sys.stderr)
else:
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

try:
    # Get data from environment variables (set by shell)
    # Use getenv with default empty string and ensure UTF-8
    def clean_string(s):
        """Remove surrogate characters and ensure valid UTF-8"""
        if not s:
            return ''
        try:
            # Remove surrogate characters by re-encoding
            if isinstance(s, bytes):
                s = s.decode('utf-8', errors='replace')
            # Re-encode to remove any surrogates
            return s.encode('utf-8', errors='replace').decode('utf-8', errors='replace')
        except:
            try:
                # Fallback to latin-1
                if isinstance(s, bytes):
                    return s.decode('latin-1', errors='replace').encode('utf-8', errors='replace').decode('utf-8', errors='replace')
                return s.encode('latin-1', errors='replace').decode('utf-8', errors='replace')
            except:
                return str(s).encode('utf-8', errors='replace').decode('utf-8', errors='replace')
    
    def get_env_utf8(key, default=''):
        value = os.environ.get(key, default)
        if value is None:
            return ''
        return clean_string(value)
    
    subject = get_env_utf8('PY_SUBJECT', '')
    body = get_env_utf8('PY_BODY', '')
    from_name = get_env_utf8('PY_FROM_NAME', '')
    email_from = get_env_utf8('PY_EMAIL_FROM', '')
    email_to = get_env_utf8('PY_EMAIL_TO', '')
    smtp_server = get_env_utf8('PY_SMTP_SERVER', '')
    smtp_port = int(os.environ.get('PY_SMTP_PORT', '587'))
    smtp_tls = get_env_utf8('PY_SMTP_TLS', 'yes')
    smtp_user = get_env_utf8('PY_SMTP_USER', '')
    smtp_password = get_env_utf8('PY_SMTP_PASSWORD', '')
    
    msg = MIMEText(body, 'plain', 'utf-8')
    msg['Subject'] = Header(subject, 'utf-8')
    msg['From'] = Header(from_name + " <" + email_from + ">", 'utf-8')
    msg['To'] = email_to
    
    server = smtplib.SMTP(smtp_server, smtp_port)
    server.set_debuglevel(0)
    
    if smtp_tls == "yes":
        server.starttls()
    
    server.login(smtp_user, smtp_password)
    server.send_message(msg)
    server.quit()
    
    sys.exit(0)
except smtplib.SMTPAuthenticationError as e:
    print("Lỗi xác thực SMTP: " + str(e), file=sys.stderr)
    sys.exit(1)
except smtplib.SMTPRecipientsRefused as e:
    print("Lỗi địa chỉ email người nhận: " + str(e), file=sys.stderr)
    sys.exit(1)
except smtplib.SMTPSenderRefused as e:
    print("Lỗi địa chỉ email người gửi: " + str(e), file=sys.stderr)
    sys.exit(1)
except smtplib.SMTPException as e:
    print("Lỗi SMTP: " + str(e), file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print("Lỗi: " + str(e), file=sys.stderr)
    sys.exit(1)
PYEOF
        
        # Export data as environment variables (shell handles encoding properly)
        # Set Python encoding environment variable
        export PYTHONIOENCODING=utf-8
        export LC_ALL=en_US.UTF-8
        export LANG=en_US.UTF-8
        
        export PY_SUBJECT="$subject"
        export PY_BODY="$body"
        export PY_FROM_NAME="$EMAIL_FROM_NAME"
        export PY_EMAIL_FROM="$EMAIL_FROM"
        export PY_EMAIL_TO="$EMAIL_TO"
        export PY_SMTP_SERVER="$EMAIL_SMTP_SERVER"
        export PY_SMTP_PORT="$EMAIL_SMTP_PORT"
        export PY_SMTP_TLS="$EMAIL_SMTP_TLS"
        export PY_SMTP_USER="$EMAIL_USER"
        export PY_SMTP_PASSWORD="$EMAIL_PASSWORD"
        
        local py_output=$(PYTHONIOENCODING=utf-8 LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 $python_cmd "$py_script" 2>&1)
        local result=$?
        rm -f "$py_script" 2>/dev/null || true
        # Unset environment variables
        unset PY_SUBJECT PY_BODY PY_FROM_NAME PY_EMAIL_FROM PY_EMAIL_TO
        unset PY_SMTP_SERVER PY_SMTP_PORT PY_SMTP_TLS PY_SMTP_USER PY_SMTP_PASSWORD
        
        if [[ $result -eq 0 ]]; then
            # Check if there's any error output
            if [[ -n "$py_output" ]]; then
                # Has output, might be an error
                echo "$py_output" >&2
                return 1
            fi
            # Success: exit code 0 and no output
            return 0
        else
            # Show Python error
            if [[ -n "$py_output" ]]; then
                echo "$py_output" >&2
            fi
            return 1
        fi
    fi
    
    # Method 2: sendEmail (backup)
    if command -v sendEmail &>/dev/null; then
        local tls_option="no"
        if [[ "$EMAIL_SMTP_TLS" == "yes" ]]; then
            tls_option="yes"
        fi
        
        local sendemail_output=$(sendEmail -f "$EMAIL_FROM" \
            -t "$EMAIL_TO" \
            -u "$subject" \
            -m "$body" \
            -s "$EMAIL_SMTP_SERVER:$EMAIL_SMTP_PORT" \
            -xu "$EMAIL_USER" \
            -xp "$EMAIL_PASSWORD" \
            -o tls="$tls_option" 2>&1)
        local sendemail_result=$?
        
        if [[ $sendemail_result -eq 0 ]]; then
            return 0
        else
            # Show sendEmail error if available
            if [[ -n "$sendemail_output" ]]; then
                echo "$sendemail_output" >&2
            fi
        fi
    fi
    
    return 1
}

# Configure Email notifications
configure_email() {
    print_step "Cấu hình thông báo Email..."
    
    read -rp "Bạn có muốn bật thông báo Email? (y/N): " enable_email
    
    if [[ "$enable_email" =~ ^[Yy]$ ]]; then
        EMAIL_ENABLED="yes"
        
        # Install email tools first
        echo ""
        install_email_tools
        echo ""
        
        # Set defaults
        local default_smtp="smtp.gmail.com"
        local default_port="587"
        local default_tls="yes"
        
        # Thứ tự nhập theo yêu cầu
        # 1. Email nhận
        read -rp "Email nhận thông báo: " email_to
        if [[ -z "$email_to" ]]; then
            print_error "Email nhận không được để trống"
            EMAIL_ENABLED="no"
            return 1
        fi
        
        # 2. Tên gửi (có thể có tiếng Việt - đọc với UTF-8 support)
        printf "Tên người gửi (VD: Rclone Master): "
        IFS= read -r from_name
        # Clean và đảm bảo UTF-8 encoding
        from_name=$(printf '%s' "$from_name" | tr -d '\r\n' | iconv -f UTF-8 -t UTF-8 2>/dev/null || printf '%s' "$from_name" | tr -d '\r\n')
        
        # 3. Server SMTP (mặc định smtp.gmail.com)
        read -rp "SMTP Server [Mặc định: $default_smtp]: " smtp_server
        EMAIL_SMTP_SERVER="${smtp_server:-$default_smtp}"
        
        # 4. PORT (mặc định 587)
        read -rp "SMTP Port [Mặc định: $default_port]: " smtp_port
        EMAIL_SMTP_PORT="${smtp_port:-$default_port}"
        
        # 5. TLS (mặc định yes)
        read -rp "Sử dụng TLS? (Y/n) [Mặc định: Y]: " use_tls
        if [[ "$use_tls" =~ ^[Nn]$ ]]; then
            EMAIL_SMTP_TLS="no"
        else
            EMAIL_SMTP_TLS="yes"
        fi
        
        # 6. Tài khoản (email gửi = email của tài khoản chứa app password)
        read -rp "Email gửi (tài khoản chứa App Password): " email_from
        if [[ -z "$email_from" ]]; then
            print_error "Email gửi không được để trống"
            EMAIL_ENABLED="no"
            return 1
        fi
        
        # Email User = Email From (theo yêu cầu)
        EMAIL_USER="$email_from"
        
        # 7. Mật khẩu
        read -rp "App Password (mật khẩu ứng dụng): " email_password
        
        # Validate email format
        if [[ "$email_to" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]] && [[ "$email_from" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            EMAIL_TO="$email_to"
            EMAIL_FROM="$email_from"
            EMAIL_FROM_NAME="${from_name:-Rclone Master}"
            # EMAIL_USER đã được set = email_from ở trên
            EMAIL_PASSWORD="$email_password"
            
            # Test email
            echo ""
            print_info "Đang kiểm tra gửi email test..."
            echo "SMTP Server: $EMAIL_SMTP_SERVER"
            echo "SMTP Port: $EMAIL_SMTP_PORT"
            echo "TLS: $EMAIL_SMTP_TLS"
            echo "From: $EMAIL_FROM"
            echo "To: $EMAIL_TO"
            echo ""
            
            local test_result=$(send_email_smtp "Rclone Master - Test Email" "Đây là email test từ Rclone Master. Cấu hình SMTP đã hoạt động thành công!" 2>&1)
            local test_exit_code=$?
            
            echo ""
            if [[ $test_exit_code -eq 0 ]] && [[ -z "$test_result" ]]; then
                print_success "Đã gửi email test thành công!"
                echo ""
                print_info "Lưu ý: Email có thể mất vài phút để đến hộp thư. Vui lòng kiểm tra cả thư mục Spam."
            else
                print_error "Không thể gửi email test"
                if [[ -n "$test_result" ]]; then
                    echo ""
                    echo "Chi tiết lỗi:"
                    echo "$test_result"
                fi
                echo ""
                print_info "Vui lòng kiểm tra:"
                echo "  - SMTP Server và Port có đúng không"
                echo "  - Email User và Password (App Password) có đúng không"
                echo "  - Firewall có chặn port SMTP không"
                echo "  - Gmail: Đảm bảo đã bật 'Less secure app access' hoặc sử dụng App Password"
            fi
        else
            print_error "Email không hợp lệ"
            EMAIL_ENABLED="no"
        fi
    else
        EMAIL_ENABLED="no"
    fi
}

# Auto-detect DirectAdmin backup directory
detect_backup_dir() {
    # Check if DirectAdmin is installed
    if [[ -f "/usr/local/directadmin/directadmin" ]] && [[ -d "/home/admin/admin_backups" ]]; then
        BACKUP_DIR="/home/admin/admin_backups"
        return 0
    fi
    
    # Fallback to configured directory or default
    if [[ -z "$BACKUP_DIR" ]]; then
        BACKUP_DIR="/root/backups"
    fi
    
    return 1
}

# Configure timezone
configure_timezone() {
    print_step "Cấu hình múi giờ..."
    
    local current_tz=$(timedatectl show --property=Timezone --value 2>/dev/null || echo "UTC")
    print_info "Múi giờ hiện tại: $current_tz"
    
    read -rp "Nhập múi giờ (Enter để dùng mặc định Asia/Ho_Chi_Minh): " timezone
    TIMEZONE="${timezone:-Asia/Ho_Chi_Minh}"
    
    # Set timezone if valid
    if timedatectl list-timezones | grep -q "^$TIMEZONE$"; then
        timedatectl set-timezone "$TIMEZONE" 2>/dev/null || true
        print_success "Đã đặt múi giờ: $TIMEZONE"
    else
        print_warning "Múi giờ không hợp lệ, giữ nguyên: $current_tz"
        TIMEZONE="$current_tz"
    fi
}

# Generate backup script
generate_backup_script() {
    print_step "Tạo script backup..."
    
    cat > "$BACKUP_SCRIPT" <<'BACKUP_EOF'
#!/bin/bash
# Rclone Master Backup Script
# Generated by setup.sh

set -e

# Load configuration
CONFIG_DIR="/root/.rclone-master"
CONFIG_FILE="$CONFIG_DIR/config.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    echo "Error: Config file not found: $CONFIG_FILE"
    exit 1
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Variables
TIMESTAMP=$(date +"%Y-%m-%d")
SECONDS=0
LOG_FILE="$CONFIG_DIR/backup.log"
RESTORE_LOG="$CONFIG_DIR/restore.log"

# Ensure log file exists
mkdir -p "$CONFIG_DIR" 2>/dev/null || true
touch "$LOG_FILE" 2>/dev/null || true

# Helper function: Get Rclone config name based on day (odd/even)
get_rclone_config() {
    local day_of_month=$(date +%d)
    if [[ -n "$RCLONE_CONFIG_NAME_ODD" ]] && [[ -n "$RCLONE_CONFIG_NAME_EVEN" ]]; then
        if ((day_of_month % 2 == 0)); then
            echo "$RCLONE_CONFIG_NAME_EVEN"
            echo "Ngày chẵn ($day_of_month). Sử dụng config: $RCLONE_CONFIG_NAME_EVEN" >&2
        else
            echo "$RCLONE_CONFIG_NAME_ODD"
            echo "Ngày lẻ ($day_of_month). Sử dụng config: $RCLONE_CONFIG_NAME_ODD" >&2
        fi
    else
        echo "${RCLONE_CONFIG_NAME:-}"
        if [[ -n "$RCLONE_CONFIG_NAME" ]]; then
            echo "Sử dụng config: $RCLONE_CONFIG_NAME" >&2
        fi
    fi
}

# Determine which config to use (odd/even day)
CONFIG_NAME=$(get_rclone_config)
TIMESTAMP=$(date +"%Y-%m-%d")

# Send Telegram notification
send_telegram() {
    if [[ "$TELEGRAM_ENABLED" == "yes" ]] && [[ -n "$TELEGRAM_BOT_TOKEN" ]] && [[ -n "$TELEGRAM_CHAT_ID" ]]; then
        local message="$1"
        curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
            -d chat_id="$TELEGRAM_CHAT_ID" \
            -d text="$message" \
            -d parse_mode="HTML" >/dev/null 2>&1 || true
    fi
}

# Send email via SMTP
send_email_smtp() {
    local subject="$1"
    local body="$2"
    
    # Validate required parameters
    if [[ "$EMAIL_ENABLED" != "yes" ]]; then
        echo "Email không được bật trong config" >&2
        return 1
    fi
    
    if [[ -z "$EMAIL_TO" ]]; then
        echo "EMAIL_TO không được cấu hình" >&2
        return 1
    fi
    
    if [[ -z "$EMAIL_SMTP_SERVER" ]]; then
        echo "EMAIL_SMTP_SERVER không được cấu hình" >&2
        return 1
    fi
    
    if [[ -z "$EMAIL_USER" ]] || [[ -z "$EMAIL_PASSWORD" ]]; then
        echo "EMAIL_USER hoặc EMAIL_PASSWORD không được cấu hình" >&2
        return 1
    fi
    
    # Method 1: Python (most reliable, works everywhere)
    if command -v python3 &>/dev/null || command -v python &>/dev/null; then
        local python_cmd=""
        if command -v python3 &>/dev/null; then
            python_cmd="python3"
        else
            python_cmd="python"
        fi
        
        local py_script=$(mktemp)
        
        # Create Python script that receives data via environment variables
        cat > "$py_script" <<'PYEOF'
# -*- coding: utf-8 -*-
import smtplib
from email.mime.text import MIMEText
from email.header import Header
import sys
import os

# Force UTF-8 encoding for stdout/stderr
if sys.version_info[0] < 3:
    import codecs
    sys.stdout = codecs.getwriter('utf-8')(sys.stdout)
    sys.stderr = codecs.getwriter('utf-8')(sys.stderr)
else:
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

try:
    # Get data from environment variables (set by shell)
    # Use getenv with default empty string and ensure UTF-8
    def clean_string(s):
        """Remove surrogate characters and ensure valid UTF-8"""
        if not s:
            return ''
        try:
            # Remove surrogate characters by re-encoding
            if isinstance(s, bytes):
                s = s.decode('utf-8', errors='replace')
            # Re-encode to remove any surrogates
            return s.encode('utf-8', errors='replace').decode('utf-8', errors='replace')
        except:
            try:
                # Fallback to latin-1
                if isinstance(s, bytes):
                    return s.decode('latin-1', errors='replace').encode('utf-8', errors='replace').decode('utf-8', errors='replace')
                return s.encode('latin-1', errors='replace').decode('utf-8', errors='replace')
            except:
                return str(s).encode('utf-8', errors='replace').decode('utf-8', errors='replace')
    
    def get_env_utf8(key, default=''):
        value = os.environ.get(key, default)
        if value is None:
            return ''
        return clean_string(value)
    
    subject = get_env_utf8('PY_SUBJECT', '')
    body = get_env_utf8('PY_BODY', '')
    from_name = get_env_utf8('PY_FROM_NAME', '')
    email_from = get_env_utf8('PY_EMAIL_FROM', '')
    email_to = get_env_utf8('PY_EMAIL_TO', '')
    smtp_server = get_env_utf8('PY_SMTP_SERVER', '')
    smtp_port = int(os.environ.get('PY_SMTP_PORT', '587'))
    smtp_tls = get_env_utf8('PY_SMTP_TLS', 'yes')
    smtp_user = get_env_utf8('PY_SMTP_USER', '')
    smtp_password = get_env_utf8('PY_SMTP_PASSWORD', '')
    
    msg = MIMEText(body, 'plain', 'utf-8')
    msg['Subject'] = Header(subject, 'utf-8')
    msg['From'] = Header(from_name + " <" + email_from + ">", 'utf-8')
    msg['To'] = email_to
    
    server = smtplib.SMTP(smtp_server, smtp_port)
    server.set_debuglevel(0)
    
    if smtp_tls == "yes":
        server.starttls()
    
    server.login(smtp_user, smtp_password)
    server.send_message(msg)
    server.quit()
    
    sys.exit(0)
except smtplib.SMTPAuthenticationError as e:
    print("Lỗi xác thực SMTP: " + str(e), file=sys.stderr)
    sys.exit(1)
except smtplib.SMTPRecipientsRefused as e:
    print("Lỗi địa chỉ email người nhận: " + str(e), file=sys.stderr)
    sys.exit(1)
except smtplib.SMTPSenderRefused as e:
    print("Lỗi địa chỉ email người gửi: " + str(e), file=sys.stderr)
    sys.exit(1)
except smtplib.SMTPException as e:
    print("Lỗi SMTP: " + str(e), file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print("Lỗi: " + str(e), file=sys.stderr)
    sys.exit(1)
PYEOF
        
        # Export data as environment variables (shell handles encoding properly)
        # Set Python encoding environment variable
        export PYTHONIOENCODING=utf-8
        export LC_ALL=en_US.UTF-8
        export LANG=en_US.UTF-8
        
        export PY_SUBJECT="$subject"
        export PY_BODY="$body"
        export PY_FROM_NAME="$EMAIL_FROM_NAME"
        export PY_EMAIL_FROM="$EMAIL_FROM"
        export PY_EMAIL_TO="$EMAIL_TO"
        export PY_SMTP_SERVER="$EMAIL_SMTP_SERVER"
        export PY_SMTP_PORT="$EMAIL_SMTP_PORT"
        export PY_SMTP_TLS="$EMAIL_SMTP_TLS"
        export PY_SMTP_USER="$EMAIL_USER"
        export PY_SMTP_PASSWORD="$EMAIL_PASSWORD"
        
        local py_output=$(PYTHONIOENCODING=utf-8 LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 $python_cmd "$py_script" 2>&1)
        local result=$?
        rm -f "$py_script" 2>/dev/null || true
        # Unset environment variables
        unset PY_SUBJECT PY_BODY PY_FROM_NAME PY_EMAIL_FROM PY_EMAIL_TO
        unset PY_SMTP_SERVER PY_SMTP_PORT PY_SMTP_TLS PY_SMTP_USER PY_SMTP_PASSWORD
        
        if [[ $result -eq 0 ]]; then
            # Check if there's any error output
            if [[ -n "$py_output" ]]; then
                # Has output, might be an error
                echo "$py_output" >&2
                return 1
            fi
            # Success: exit code 0 and no output
            return 0
        else
            # Show Python error
            if [[ -n "$py_output" ]]; then
                echo "$py_output" >&2
            fi
            return 1
        fi
    fi
    
    # Method 2: sendEmail (backup)
    if command -v sendEmail &>/dev/null; then
        local tls_option="no"
        if [[ "$EMAIL_SMTP_TLS" == "yes" ]]; then
            tls_option="yes"
        fi
        
        local sendemail_output=$(sendEmail -f "$EMAIL_FROM" \
            -t "$EMAIL_TO" \
            -u "$subject" \
            -m "$body" \
            -s "$EMAIL_SMTP_SERVER:$EMAIL_SMTP_PORT" \
            -xu "$EMAIL_USER" \
            -xp "$EMAIL_PASSWORD" \
            -o tls="$tls_option" 2>&1)
        local sendemail_result=$?
        
        if [[ $sendemail_result -eq 0 ]]; then
            return 0
        else
            # Show sendEmail error if available
            if [[ -n "$sendemail_output" ]]; then
                echo "$sendemail_output" >&2
            fi
        fi
    fi
    
    return 1
}

# Send Email notification (wrapper for backward compatibility)
send_email() {
    local subject="$1"
    local body="$2"
    send_email_smtp "$subject" "$body" || true
}

# Main backup process
main() {
    echo "=========================================="
    echo "Rclone Master Backup - $(date)"
    echo "=========================================="
    
    # Auto-detect backup directory (prioritize DirectAdmin)
    if [[ -z "$BACKUP_DIR" ]] || [[ ! -d "$BACKUP_DIR" ]]; then
        if [[ -f "/usr/local/directadmin/directadmin" ]] && [[ -d "/home/admin/admin_backups" ]]; then
            BACKUP_DIR="/home/admin/admin_backups"
            echo "Phát hiện DirectAdmin, sử dụng thư mục backup: $BACKUP_DIR"
        else
            echo "Thư mục backup chưa được cấu hình hoặc không tồn tại"
            echo "Vui lòng cấu hình BACKUP_DIR trong config hoặc đảm bảo DirectAdmin backup directory tồn tại"
            exit 1
        fi
    fi
    
    # Check backup directory size
    if [[ -d "$BACKUP_DIR" ]]; then
        size=$(du -sh "$BACKUP_DIR" 2>/dev/null | awk '{print $1}' || echo "0")
    else
        size="0"
    fi
    
    # Display backup information
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  THÔNG TIN BACKUP"
    echo "═══════════════════════════════════════════════════════════"
    echo "Thư mục backup: $BACKUP_DIR"
    echo "Cloud config: $CONFIG_NAME"
    echo "Vị trí trên Cloud: $CONFIG_NAME:$SERVER_NAME/$TIMESTAMP"
    
    # Display backup directory size and file count
    if [[ -d "$BACKUP_DIR" ]]; then
        local backup_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | awk '{print $1}' || echo "N/A")
        local file_count=$(find "$BACKUP_DIR" -type f 2>/dev/null | wc -l)
        echo "Kích thước: $backup_size"
        echo "Số file: $file_count"
    fi
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    # Ensure remote directory exists
    if ! rclone lsd "$CONFIG_NAME:$SERVER_NAME" >/dev/null 2>&1; then
        rclone mkdir "$CONFIG_NAME:$SERVER_NAME"
    fi
    
    # Upload to cloud with progress
    echo "Đang upload lên Cloud..."
    echo "Thư mục nguồn: $BACKUP_DIR"
    echo "Thư mục đích: $CONFIG_NAME:$SERVER_NAME/$TIMESTAMP"
    echo ""
    if rclone move "$BACKUP_DIR" "$CONFIG_NAME:$SERVER_NAME/$TIMESTAMP" -P --transfers=10 --checkers=20 2>&1 | tee -a "$LOG_FILE"; then
        echo "Backup thành công!"
        
        # Cleanup local backup directory
        rm -rf "$BACKUP_DIR"/* 2>/dev/null || true
        
        # Cleanup old backups
        if [[ -n "$CLEANUP_DAYS" ]]; then
            echo "Đang xóa backup cũ hơn $CLEANUP_DAYS ngày..."
            for folder in $(rclone lsf "$CONFIG_NAME:$SERVER_NAME" --dirs-only 2>/dev/null); do
                folder_date=$(basename "$folder")
                if [[ "$folder_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
                    folder_timestamp=$(date -d "$folder_date" +%s 2>/dev/null || echo "0")
                    timestamp_limit=$(date -d "$TIMESTAMP -$CLEANUP_DAYS days" +%s 2>/dev/null || echo "0")
                    if [[ $folder_timestamp -lt $timestamp_limit ]] && [[ $folder_timestamp -gt 0 ]]; then
                        echo "Xóa backup cũ: $folder"
                        rclone purge "$CONFIG_NAME:$SERVER_NAME/$folder" >> "$LOG_FILE" 2>&1 || true
                    fi
                fi
            done
        fi
        
        # Cleanup trash for OneDrive and Google Drive
        echo "Đang dọn dẹp thùng rác Cloud..."
        local remote_type=$(rclone config show "$CONFIG_NAME" 2>/dev/null | grep "^type" | awk '{print $3}' || echo "")
        if [[ "$remote_type" == "onedrive" ]] || [[ "$remote_type" == "drive" ]]; then
            # Cleanup trash/recycle bin
            rclone cleanup "$CONFIG_NAME:" >> "$LOG_FILE" 2>&1 || true
            # For OneDrive, also try to purge trash
            if [[ "$remote_type" == "onedrive" ]]; then
                rclone purge "$CONFIG_NAME:Trash" >> "$LOG_FILE" 2>&1 || true
            fi
            # For Google Drive, purge trash
            if [[ "$remote_type" == "drive" ]]; then
                rclone purge "$CONFIG_NAME:.Trash" >> "$LOG_FILE" 2>&1 || true
            fi
        else
            rclone cleanup "$CONFIG_NAME:" >> "$LOG_FILE" 2>&1 || true
        fi
        
        # Get cloud storage info
        local cloud_info=$(rclone about "$CONFIG_NAME:" 2>/dev/null | grep -E "Total|Used|Free" | head -3 || echo "")
        local cloud_size=""
        if [[ -n "$cloud_info" ]]; then
            cloud_size=$(echo "$cloud_info" | grep -i "free\|available" | head -1 | sed 's/.*://' | xargs || echo "")
        fi
        
        # Get system info
        local disk_usage=$(df -h / | tail -1 | awk '{print $5 " used (" $3 "/" $2 ")"}')
        local hostname=$(hostname)
        local uptime=$(uptime -p 2>/dev/null | sed 's/up //' || uptime | awk -F'up' '{print $2}' | awk '{print $1,$2}')
        
        # Calculate duration
        duration=$SECONDS
        minutes=$((duration / 60))
        seconds=$((duration % 60))
        
        # Send notifications with system and cloud info
        local telegram_msg="<b>Backup thành công!</b>

<b>Dung lượng backup:</b> $size
<b>Thời gian:</b> $minutes phút $seconds giây
<b>Thư mục:</b> $SERVER_NAME/$TIMESTAMP
<b>Config:</b> $CONFIG_NAME

<b>Thông tin hệ thống:</b>
   - Server: $hostname
   - Disk: $disk_usage
   - Uptime: $uptime

<b>Cloud Storage:</b>"
        
        if [[ -n "$cloud_size" ]]; then
            telegram_msg="$telegram_msg
   - Dung lượng còn lại: $cloud_size"
        else
            telegram_msg="$telegram_msg
   - Đã cleanup thùng rác"
        fi
        
        local email_msg="Backup thành công!

Dung lượng backup: $size
Thời gian: $minutes phút $seconds giây
Thư mục: $SERVER_NAME/$TIMESTAMP
Config: $CONFIG_NAME

Thông tin hệ thống:
   - Server: $hostname
   - Disk: $disk_usage
   - Uptime: $uptime

Cloud Storage:"
        
        if [[ -n "$cloud_size" ]]; then
            email_msg="$email_msg
   - Dung lượng còn lại: $cloud_size"
        else
            email_msg="$email_msg
   - Đã cleanup thùng rác"
        fi
        
        send_telegram "$telegram_msg"
        send_email "$EMAIL_SUBJECT - Backup thành công" "$email_msg"
        
        echo "Tổng kích thước: $size, Backup trong $minutes phút $seconds giây"
    else
        # Get system info for error message
        local hostname=$(hostname)
        local disk_usage=$(df -h / | tail -1 | awk '{print $5 " used (" $3 "/" $2 ")"}')
        
        local error_msg_telegram="<b>Backup thất bại!</b>

<b>Server:</b> $hostname
<b>Disk:</b> $disk_usage

Vui lòng kiểm tra log để biết thêm chi tiết."
        
        local error_msg_email="Backup thất bại!

Server: $hostname
Disk: $disk_usage

Vui lòng kiểm tra log để biết thêm chi tiết."
        
        echo "$error_msg_email"
        send_telegram "$error_msg_telegram"
        send_email "$EMAIL_SUBJECT - Backup thất bại" "$error_msg_email"
            exit 1
        fi
}

main "$@"
BACKUP_EOF

    chmod +x "$BACKUP_SCRIPT"
    print_success "Đã tạo script backup: $BACKUP_SCRIPT"
}

# Generate restore script
generate_restore_script() {
    print_step "Tạo script restore..."
    
    cat > "$RESTORE_SCRIPT" <<'RESTORE_EOF'
#!/bin/bash
# Rclone Master Restore Script
# Generated by setup.sh

set -e

# Load configuration
CONFIG_DIR="/root/.rclone-master"
CONFIG_FILE="$CONFIG_DIR/config.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    echo "Error: Config file not found: $CONFIG_FILE"
    exit 1
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Variables
RESTORE_LOG="$CONFIG_DIR/restore.log"

print_info() {
    echo "$1"
}

print_success() {
    echo -e "${GREEN}$1${NC}"
}

print_error() {
    echo -e "${RED}$1${NC}"
}

# Get available backup dates
list_backups() {
    local config_name="$1"
        echo ""
    print_info "Danh sách backup có sẵn:"
    rclone lsf "$config_name:$SERVER_NAME" --dirs-only 2>/dev/null | sort -r | head -20
}

# Main restore function
main() {
    echo "=========================================="
    echo "Rclone Master Restore"
    echo "=========================================="
    
    # Determine config name
    if [[ -n "$RCLONE_CONFIG_NAME_ODD" ]] && [[ -n "$RCLONE_CONFIG_NAME_EVEN" ]]; then
        print_info "Bạn đang sử dụng 2 tài khoản backup"
        read -rp "Chọn config (1=ODD, 2=EVEN, hoặc nhập tên config): " config_choice
        case "$config_choice" in
            1) CONFIG_NAME="$RCLONE_CONFIG_NAME_ODD" ;;
            2) CONFIG_NAME="$RCLONE_CONFIG_NAME_EVEN" ;;
            *) CONFIG_NAME="$config_choice" ;;
        esac
    else
        CONFIG_NAME="$RCLONE_CONFIG_NAME"
    fi
    
    # List available backups
    list_backups "$CONFIG_NAME"
    
    echo ""
    read -rp "Nhập ngày backup cần restore (format: YYYY-MM-DD): " folder_day
    
    if [[ -z "$folder_day" ]]; then
        print_error "Ngày backup không được để trống"
        exit 1
    fi
    
    # Auto-detect restore directory (prioritize DirectAdmin)
    if [[ -z "$BACKUP_DIR" ]] || [[ ! -d "$BACKUP_DIR" ]]; then
        if [[ -f "/usr/local/directadmin/directadmin" ]] && [[ -d "/home/admin/admin_backups" ]]; then
            BACKUP_DIR="/home/admin/admin_backups"
            echo "Phát hiện DirectAdmin, sử dụng thư mục restore: $BACKUP_DIR"
        fi
    fi
    
    read -rp "Nhập thư mục restore (mặc định: ${BACKUP_DIR:-/root/restore}): " restore_dir
    restore_dir="${restore_dir:-${BACKUP_DIR:-/root/restore}}"
    
    # Create restore directory
    mkdir -p "$restore_dir"
    
    print_info "Bắt đầu restore từ $CONFIG_NAME:$SERVER_NAME/$folder_day"
    print_info "Đến: $restore_dir"
    
    if rclone copy -P "$CONFIG_NAME:$SERVER_NAME/$folder_day" "$restore_dir" 2>&1 | tee "$RESTORE_LOG"; then
        print_success "Restore thành công!"
        print_info "Dữ liệu đã được restore vào: $restore_dir"
    else
        print_error "Restore thất bại. Kiểm tra log: $RESTORE_LOG"
        exit 1
    fi
}

main "$@"
RESTORE_EOF

    chmod +x "$RESTORE_SCRIPT"
    print_success "Đã tạo script restore: $RESTORE_SCRIPT"
}

# Setup cron jobs
setup_cron() {
    print_step "Thiết lập Cron jobs..."
    
    # Ensure backup script exists and is executable
    if [[ ! -f "$BACKUP_SCRIPT" ]]; then
        print_error "Backup script không tồn tại: $BACKUP_SCRIPT"
        print_info "Vui lòng chạy 'Cấu hình Backup' trước để tạo script"
        return 1
    fi
    
    # Ensure script is executable
    chmod +x "$BACKUP_SCRIPT" 2>/dev/null || true
    
    # Verify script is executable
    if [[ ! -x "$BACKUP_SCRIPT" ]]; then
        print_error "Không thể cấp quyền thực thi cho script: $BACKUP_SCRIPT"
        return 1
    fi
    
    # Use configured schedule or default
    local cron_schedule="${BACKUP_CRON_SCHEDULE:-0 5 * * *}"
    
    # Get current crontab (preserve all existing entries)
    local current_crontab=$(crontab -l 2>/dev/null || echo "")
    
    # Remove old Rclone Master entries (if any)
    local new_crontab=$(echo "$current_crontab" | grep -v "rclone-master\|$BACKUP_SCRIPT\|$RESTORE_SCRIPT\|Rclone Master" || echo "")
    
    # Add new Rclone Master entry
    local cron_entry="# Rclone Master Backup - Generated $(date)"
    local cron_job="$cron_schedule /bin/bash $BACKUP_SCRIPT >> $LOG_FILE 2>&1"
    
    # Append new entries to crontab
    if [[ -n "$new_crontab" ]]; then
        echo "$new_crontab" > "$CRON_FILE"
        echo "" >> "$CRON_FILE"
    else
        touch "$CRON_FILE"
    fi
    
    echo "$cron_entry" >> "$CRON_FILE"
    echo "$cron_job" >> "$CRON_FILE"
    
    # Install crontab (this preserves all existing cron jobs)
    if crontab "$CRON_FILE" 2>/dev/null; then
        print_success "Đã thêm cron job vào crontab"
    else
        print_error "Không thể cài đặt crontab"
        rm -f "$CRON_FILE"
        return 1
    fi
    
    rm -f "$CRON_FILE"
    
    # Verify crontab was installed correctly
    if crontab -l 2>/dev/null | grep -q "$BACKUP_SCRIPT"; then
        print_success "Đã xác nhận cron job trong crontab"
        echo ""
        print_info "Cron job đã được thêm vào crontab:"
        crontab -l 2>/dev/null | grep -A 1 "Rclone Master" | sed 's/^/  /'
    else
        print_warning "Cron job có thể chưa được cài đặt đúng"
    fi
    
    echo ""
    print_success "Đã thiết lập Cron jobs"
    print_info "Lịch backup: $cron_schedule"
    print_info "Script: $BACKUP_SCRIPT"
    print_info "Log file: $LOG_FILE"
    echo ""
    print_info "Cron job đã được thêm vào crontab của bạn."
    print_info "Bạn có thể chỉnh sửa bằng lệnh: crontab -e"
    print_info "Hoặc xem bằng lệnh: crontab -l"
    echo ""
    print_info "Để kiểm tra cron job:"
    echo "  - Xem crontab: crontab -l"
    echo "  - Chỉnh sửa: crontab -e"
    echo "  - Xem log: tail -f $LOG_FILE"
    echo "  - Test chạy: $BACKUP_SCRIPT"
}

# Configure cron schedule
configure_cron() {
    print_step "Cấu hình lịch backup tự động..."
    echo ""
    load_config
    
    if [[ -n "$BACKUP_CRON_SCHEDULE" ]]; then
        print_info "Lịch backup hiện tại: $BACKUP_CRON_SCHEDULE"
    else
        print_info "Lịch backup mặc định: 0 5 * * * (5:00 AM hàng ngày)"
    fi
    
    echo ""
    echo "Ví dụ lịch backup:"
    echo "  - 0 5 * * *     : 5:00 AM hàng ngày"
    echo "  - 0 2 * * *     : 2:00 AM hàng ngày"
    echo "  - 0 3 * * 0     : 3:00 AM mỗi Chủ nhật"
    echo "  - 0 */6 * * *   : Mỗi 6 giờ"
    echo "  - 0 0 * * *     : Nửa đêm hàng ngày"
    echo ""
    read -rp "Nhập lịch backup cron (Enter để giữ nguyên): " cron_schedule
    
    if [[ -n "$cron_schedule" ]]; then
        # Validate cron format (basic check)
        if echo "$cron_schedule" | grep -qE '^[0-9\*\/\-\, ]+$' && [[ $(echo "$cron_schedule" | tr ' ' '\n' | wc -l) -eq 5 ]]; then
            BACKUP_CRON_SCHEDULE="$cron_schedule"
            print_success "Đã cập nhật lịch backup: $BACKUP_CRON_SCHEDULE"
            
            # Update cron job
            setup_cron
        else
            print_error "Lịch cron không hợp lệ. Vui lòng nhập đúng định dạng (5 giá trị)"
        fi
    else
        print_info "Giữ nguyên lịch backup hiện tại"
    fi
}

# Sub-menu: Cấu hình Rclone
menu_configure_rclone() {
    while true; do
        print_sub_header
        echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
        echo -e "${CYAN}  MENU CẤU HÌNH RCLONE${NC}"
        echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
        echo ""
        echo "  1) Cài đặt Rclone"
        echo "  2) Cập nhật Rclone"
        echo "  3) Cấu hình Rclone mới"
        echo "  4) Xóa config Rclone"
        echo "  5) Kiểm tra kết nối Rclone"
        echo "  6) Liệt kê các remote đã cấu hình"
        echo "  7) Cấu hình lịch backup tự động"
        echo "  0) Quay lại menu chính"
        echo ""
        read -rp "Lựa chọn (0-7): " choice
        
        case "$choice" in
            1)
                print_sub_header
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo -e "${CYAN}  CÀI ĐẶT RCLONE${NC}"
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo ""
                install_rclone
                echo ""
                read -rp "Nhấn Enter để tiếp tục..." dummy
                clear
                ;;
            2)
                print_sub_header
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo -e "${CYAN}  CẬP NHẬT RCLONE${NC}"
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo ""
                if command -v rclone &>/dev/null; then
                    print_info "Đang cập nhật Rclone..."
                    curl https://rclone.org/install.sh | sudo bash
                    print_success "Đã cập nhật Rclone"
                else
                    print_error "Rclone chưa được cài đặt"
                fi
                echo ""
                read -rp "Nhấn Enter để tiếp tục..." dummy
                clear
                ;;
            3)
                configure_rclone
                save_config
                read -rp "Nhấn Enter để tiếp tục..." dummy
                clear
                ;;
            4)
                print_sub_header
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo -e "${CYAN}  XÓA CONFIG RCLONE${NC}"
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo ""
                local configs=()
                while IFS= read -r config; do
                    [[ -n "$config" ]] && configs+=("$config")
                done < <(rclone listremotes 2>/dev/null | sed 's/:$//' || true)
                
                if [[ ${#configs[@]} -eq 0 ]]; then
                    print_error "Không có config nào để xóa"
                else
                    echo "Danh sách config:"
                    echo ""
                    local idx=1
                    for config in "${configs[@]}"; do
                        printf "  %2d) %s\n" "$idx" "$config"
                        ((idx++))
                    done
                    echo ""
                    read -rp "Chọn config cần xóa (nhập số): " del_choice
                    
                    if [[ "$del_choice" =~ ^[0-9]+$ ]] && [[ "$del_choice" -ge 1 ]] && [[ "$del_choice" -le ${#configs[@]} ]]; then
                        local del_config="${configs[$((del_choice - 1))]}"
                        read -rp "Bạn có chắc chắn muốn xóa config '$del_config'? (y/N): " confirm
                        if [[ "$confirm" =~ ^[Yy]$ ]]; then
                            rclone config delete "$del_config"
                            print_success "Đã xóa config: $del_config"
                        else
                            print_info "Đã hủy"
                        fi
                    else
                        print_error "Lựa chọn không hợp lệ"
                    fi
                fi
                echo ""
                read -rp "Nhấn Enter để tiếp tục..." dummy
                clear
                ;;
            5)
                print_sub_header
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo -e "${CYAN}  KIỂM TRA KẾT NỐI RCLONE${NC}"
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo ""
                load_config
                if [[ -n "$RCLONE_CONFIG_NAME" ]]; then
                    print_info "Đang kiểm tra kết nối: $RCLONE_CONFIG_NAME"
                    if rclone lsd "$RCLONE_CONFIG_NAME:" >/dev/null 2>&1; then
                        print_success "Kết nối thành công!"
                        rclone lsd "$RCLONE_CONFIG_NAME:" | head -10
                    else
                        print_error "Không thể kết nối. Kiểm tra lại cấu hình."
                    fi
                elif [[ -n "$RCLONE_CONFIG_NAME_ODD" ]] && [[ -n "$RCLONE_CONFIG_NAME_EVEN" ]]; then
                    print_info "Đang kiểm tra kết nối ODD: $RCLONE_CONFIG_NAME_ODD"
                    rclone lsd "$RCLONE_CONFIG_NAME_ODD:" 2>&1 | head -10
                    echo ""
                    print_info "Đang kiểm tra kết nối EVEN: $RCLONE_CONFIG_NAME_EVEN"
                    rclone lsd "$RCLONE_CONFIG_NAME_EVEN:" 2>&1 | head -10
                else
                    print_error "Chưa cấu hình Rclone"
                fi
                echo ""
                read -rp "Nhấn Enter để tiếp tục..." dummy
                clear
                ;;
            6)
                print_sub_header
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo -e "${CYAN}  DANH SÁCH REMOTE ĐÃ CẤU HÌNH${NC}"
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo ""
                print_info "Danh sách các remote đã cấu hình:"
                echo ""
                rclone listremotes 2>/dev/null || print_error "Không có remote nào được cấu hình"
                echo ""
                read -rp "Nhấn Enter để tiếp tục..." dummy
                clear
                ;;
            7)
                configure_cron
                save_config
                echo ""
                read -rp "Nhấn Enter để tiếp tục..." dummy
                clear
                ;;
            0)
                break
                ;;
            *)
                print_error "Lựa chọn không hợp lệ"
                sleep 1
                clear
                ;;
        esac
    done
}


# Sub-menu: Cấu hình Restore
menu_configure_restore() {
    while true; do
        print_sub_header
        echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
        echo -e "${CYAN}  MENU CẤU HÌNH RESTORE${NC}"
        echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
        echo ""
        echo "  1) Restore từ Cloud về Server"
        echo "  2) Xem danh sách backup có sẵn"
        echo "  3) Tạo script restore"
        echo "  4) Xem log restore"
        echo "  0) Quay lại menu chính"
        echo ""
        read -rp "Lựa chọn (0-4): " choice
        
        case "$choice" in
            1)
                print_sub_header
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo -e "${CYAN}  RESTORE TỪ CLOUD VỀ SERVER${NC}"
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo ""
                if [[ ! -f "$RESTORE_SCRIPT" ]]; then
                    print_info "Đang tạo script restore..."
                    generate_restore_script
                fi
                "$RESTORE_SCRIPT"
                read -rp "Nhấn Enter để tiếp tục..." dummy
                clear
                ;;
            2)
                print_sub_header
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo -e "${CYAN}  DANH SÁCH BACKUP CÓ SẴN${NC}"
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo ""
                load_config
                if [[ -n "$RCLONE_CONFIG_NAME" ]]; then
                    print_info "Danh sách backup có sẵn trên Cloud:"
                    echo ""
                    rclone lsf "$RCLONE_CONFIG_NAME:$SERVER_NAME" --dirs-only 2>/dev/null | sort -r | head -20 || print_error "Không tìm thấy backup nào"
                else
                    print_error "Chưa cấu hình Rclone"
                fi
                echo ""
                read -rp "Nhấn Enter để tiếp tục..." dummy
                clear
                ;;
            3)
                print_sub_header
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo -e "${CYAN}  TẠO SCRIPT RESTORE${NC}"
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo ""
                generate_restore_script
                echo ""
                read -rp "Nhấn Enter để tiếp tục..." dummy
                clear
                ;;
            4)
                print_sub_header
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo -e "${CYAN}  XEM LOG RESTORE${NC}"
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo ""
                if [[ -f "$RESTORE_LOG" ]]; then
                    echo "Nội dung log restore (50 dòng cuối):"
                    echo ""
                    tail -50 "$RESTORE_LOG"
                else
                    print_info "Chưa có log restore"
                fi
                echo ""
                read -rp "Nhấn Enter để tiếp tục..." dummy
                clear
                ;;
            0)
                break
                ;;
            *)
                print_error "Lựa chọn không hợp lệ"
                sleep 1
                clear
                ;;
        esac
    done
}

# Sub-menu: Cấu hình Thông báo
menu_configure_notifications() {
    while true; do
        print_sub_header
        echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
        echo -e "${CYAN}  MENU CẤU HÌNH THÔNG BÁO${NC}"
        echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
        echo ""
        echo "  1) Cấu hình Telegram"
        echo "  2) Cấu hình Email"
        echo "  3) Test gửi thông báo Telegram"
        echo "  4) Test gửi thông báo Email"
        echo "  0) Quay lại menu chính"
        echo ""
        read -rp "Lựa chọn (0-4): " choice
        
        case "$choice" in
            1)
                configure_telegram
                save_config
                read -rp "Nhấn Enter để tiếp tục..." dummy
                clear
                ;;
            2)
                configure_email
                save_config
                echo ""
                read -rp "Nhấn Enter để tiếp tục..." dummy
                clear
                ;;
            3)
                print_sub_header
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo -e "${CYAN}  TEST GỬI THÔNG BÁO TELEGRAM${NC}"
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo ""
                load_config
                if [[ "$TELEGRAM_ENABLED" == "yes" ]] && [[ -n "$TELEGRAM_BOT_TOKEN" ]] && [[ -n "$TELEGRAM_CHAT_ID" ]]; then
                    print_info "Đang gửi thông báo test..."
                    local test_msg="<b>Test thông báo từ Rclone Master</b>

Thời gian: $(date '+%Y-%m-%d %H:%M:%S')
Hệ thống: $(hostname)"
                    local response=$(curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
                        -d chat_id="$TELEGRAM_CHAT_ID" \
                        -d text="$test_msg" \
                        -d parse_mode="HTML" 2>&1)
                    if echo "$response" | grep -q "\"ok\":true"; then
                        print_success "Đã gửi thông báo test thành công!"
                    else
                        print_error "Không thể gửi thông báo. Kiểm tra lại cấu hình."
                        echo "$response"
                    fi
                else
                    print_error "Chưa cấu hình Telegram"
                fi
                echo ""
                read -rp "Nhấn Enter để tiếp tục..." dummy
                clear
                ;;
            4)
                print_sub_header
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo -e "${CYAN}  TEST GỬI THÔNG BÁO EMAIL${NC}"
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo ""
                load_config
                if [[ "$EMAIL_ENABLED" == "yes" ]]; then
                    echo ""
                    print_info "Thông tin cấu hình Email:"
                    echo "  SMTP Server: ${EMAIL_SMTP_SERVER:-CHƯA CẤU HÌNH}"
                    echo "  SMTP Port: ${EMAIL_SMTP_PORT:-587}"
                    echo "  TLS: ${EMAIL_SMTP_TLS:-yes}"
                    echo "  From: ${EMAIL_FROM:-CHƯA CẤU HÌNH}"
                    echo "  To: ${EMAIL_TO:-CHƯA CẤU HÌNH}"
                    echo "  User: ${EMAIL_USER:-CHƯA CẤU HÌNH}"
                    echo ""
                    
                    if [[ -z "$EMAIL_SMTP_SERVER" ]] || [[ -z "$EMAIL_TO" ]]; then
                        print_error "Email chưa được cấu hình đầy đủ. Vui lòng cấu hình lại."
                    else
                        print_info "Đang gửi email test..."
                        local test_body="Đây là email test từ Rclone Master

Thời gian: $(date '+%Y-%m-%d %H:%M:%S')
Hệ thống: $(hostname)
SMTP Server: $EMAIL_SMTP_SERVER:$EMAIL_SMTP_PORT"
                        
                        local test_result=$(send_email_smtp "Rclone Master - Test Email" "$test_body" 2>&1)
                        local test_exit_code=$?
                        
                        echo ""
                        if [[ $test_exit_code -eq 0 ]] && [[ -z "$test_result" ]]; then
                            print_success "Đã gửi email test đến $EMAIL_TO"
                            echo ""
                            print_info "Lưu ý: Email có thể mất vài phút để đến hộp thư. Vui lòng kiểm tra cả thư mục Spam."
                        else
                            print_error "Không thể gửi email test"
                            if [[ -n "$test_result" ]]; then
                                echo ""
                                echo "Chi tiết lỗi:"
                                echo "$test_result"
                            fi
                            echo ""
                            print_info "Vui lòng kiểm tra:"
                            echo "  - SMTP Server và Port có đúng không"
                            echo "  - Email User và Password (App Password) có đúng không"
                            echo "  - Firewall có chặn port SMTP không"
                            echo "  - Gmail: Đảm bảo đã bật 'Less secure app access' hoặc sử dụng App Password"
                        fi
                    fi
                else
                    print_error "Email chưa được bật"
                fi
                echo ""
                read -rp "Nhấn Enter để tiếp tục..." dummy
                clear
                ;;
            5)
                print_sub_header
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo -e "${CYAN}  XEM CẤU HÌNH THÔNG BÁO${NC}"
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo ""
                if [[ -f "$CONFIG_FILE" ]]; then
                    echo "Cấu hình thông báo hiện tại:"
                    echo ""
                    cat "$CONFIG_FILE" 2>/dev/null | grep -E "TELEGRAM_|EMAIL_" || echo "Chưa có cấu hình"
                else
                    print_error "Chưa có file cấu hình"
                fi
                echo ""
                read -rp "Nhấn Enter để tiếp tục..." dummy
                clear
                ;;
            0)
                break
                ;;
            *)
                print_error "Lựa chọn không hợp lệ"
                sleep 1
                clear
                ;;
        esac
    done
}

# Menu: Thông tin
menu_info() {
    while true; do
        print_sub_header
        echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
        echo -e "${CYAN}  MENU THÔNG TIN${NC}"
        echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
        echo ""
        echo "  1) Thông tin hệ thống"
        echo "  2) Xem cấu hình hiện tại"
        echo "  3) Xem log backup"
        echo "  4) Xem log restore"
        echo "  5) Kiểm tra trạng thái Cron"
        echo "  6) Kiểm tra kết nối Rclone"
        echo "  7) Kiểm tra dung lượng Cloud"
        echo "  8) Cập nhật Script"
        echo "  9) Gỡ cài đặt Script"
        echo "  0) Quay lại menu chính"
        echo ""
        read -rp "Lựa chọn (0-9): " choice
        
        case "$choice" in
            1)
                print_sub_header
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo -e "${CYAN}  THÔNG TIN HỆ THỐNG${NC}"
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                print_info "Thông tin hệ thống:"
                echo ""
                echo "  - Hostname: $(hostname)"
                echo "  - OS: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2 || uname -a)"
                echo "  - Uptime: $(uptime -p 2>/dev/null || uptime)"
                echo "  - Disk Usage:"
                df -h / | tail -1 | awk '{print "    /: " $3 " used / " $2 " total (" $5 " used)"}'
                echo ""
                echo "  - Rclone Version:"
                if command -v rclone &>/dev/null; then
                    rclone version | head -n1
                else
                    echo "    Rclone chưa được cài đặt"
                fi
                echo ""
                echo ""
                read -rp "Nhấn Enter để tiếp tục..." dummy
                clear
                ;;
            2)
                print_sub_header
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo -e "${CYAN}  CẤU HÌNH HIỆN TẠI${NC}"
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo ""
                load_config
                if [[ -f "$CONFIG_FILE" ]]; then
                    cat "$CONFIG_FILE"
                else
                    print_error "Chưa có file cấu hình"
                fi
                echo ""
                read -rp "Nhấn Enter để tiếp tục..." dummy
                clear
                ;;
            3)
                print_sub_header
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo -e "${CYAN}  LOG BACKUP (50 dòng cuối)${NC}"
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo ""
                if [[ -f "$LOG_FILE" ]]; then
                    tail -50 "$LOG_FILE"
                else
                    print_info "Chưa có log backup"
                fi
                echo ""
                read -rp "Nhấn Enter để tiếp tục..." dummy
                clear
                ;;
            4)
                print_sub_header
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo -e "${CYAN}  LOG RESTORE (50 dòng cuối)${NC}"
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo ""
                if [[ -f "$RESTORE_LOG" ]]; then
                    tail -50 "$RESTORE_LOG"
                else
                    print_info "Chưa có log restore"
                fi
                echo ""
                read -rp "Nhấn Enter để tiếp tục..." dummy
                clear
                ;;
            5)
                check_cron_status
                ;;
            6)
                print_sub_header
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo -e "${CYAN}  KIỂM TRA KẾT NỐI RCLONE${NC}"
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo ""
                load_config
                if [[ -n "$RCLONE_CONFIG_NAME" ]]; then
                    print_info "Đang kiểm tra kết nối với config: $RCLONE_CONFIG_NAME"
                    echo ""
                    rclone lsd "$RCLONE_CONFIG_NAME:" 2>&1 | head -10
                elif [[ -n "$RCLONE_CONFIG_NAME_ODD" ]] && [[ -n "$RCLONE_CONFIG_NAME_EVEN" ]]; then
                    print_info "Đang kiểm tra kết nối với config ODD: $RCLONE_CONFIG_NAME_ODD"
                    echo ""
                    rclone lsd "$RCLONE_CONFIG_NAME_ODD:" 2>&1 | head -10
                    echo ""
                    print_info "Đang kiểm tra kết nối với config EVEN: $RCLONE_CONFIG_NAME_EVEN"
                    echo ""
                    rclone lsd "$RCLONE_CONFIG_NAME_EVEN:" 2>&1 | head -10
                else
                    print_error "Chưa cấu hình Rclone"
                fi
                echo ""
                read -rp "Nhấn Enter để tiếp tục..." dummy
                clear
                ;;
            7)
                print_sub_header
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo -e "${CYAN}  DUNG LƯỢNG CLOUD${NC}"
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo ""
                load_config
                if [[ -n "$RCLONE_CONFIG_NAME" ]] && [[ -n "$SERVER_NAME" ]]; then
                    print_info "Đang kiểm tra dung lượng Cloud: $RCLONE_CONFIG_NAME:$SERVER_NAME"
                    echo ""
                    rclone size "$RCLONE_CONFIG_NAME:$SERVER_NAME" 2>&1
                elif [[ -n "$RCLONE_CONFIG_NAME_ODD" ]] && [[ -n "$SERVER_NAME" ]]; then
                    print_info "Đang kiểm tra dung lượng Cloud (ODD): $RCLONE_CONFIG_NAME_ODD:$SERVER_NAME"
                    echo ""
                    rclone size "$RCLONE_CONFIG_NAME_ODD:$SERVER_NAME" 2>&1
                    echo ""
                    print_info "Đang kiểm tra dung lượng Cloud (EVEN): $RCLONE_CONFIG_NAME_EVEN:$SERVER_NAME"
                    echo ""
                    rclone size "$RCLONE_CONFIG_NAME_EVEN:$SERVER_NAME" 2>&1
                else
                    print_error "Chưa cấu hình đầy đủ"
                fi
                echo ""
                read -rp "Nhấn Enter để tiếp tục..." dummy
                clear
                ;;
            8)
                menu_update_sub
                ;;
            9)
                menu_uninstall_sub
                ;;
            0)
                break
                ;;
            *)
                print_error "Lựa chọn không hợp lệ"
                sleep 1
                clear
                ;;
        esac
    done
}

# Sub-menu: Cập nhật Script (trong menu Thông tin)
menu_update_sub() {
    while true; do
        print_sub_header
        echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
        echo -e "${CYAN}  CẬP NHẬT SCRIPT${NC}"
        echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
        echo ""
        echo "  1) Cập nhật Rclone"
        echo "  2) Cập nhật Script Rclone Master"
        echo "  3) Kiểm tra phiên bản Rclone"
        echo "  0) Quay lại"
        echo ""
        read -rp "Lựa chọn (0-3): " choice
        
        case "$choice" in
            1)
                print_sub_header
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo -e "${CYAN}  CẬP NHẬT RCLONE${NC}"
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo ""
                print_info "Cập nhật Rclone..."
                install_rclone
                
                echo ""
                print_info "Cập nhật scripts..."
                generate_backup_script
                generate_restore_script
                
                echo ""
                print_success "Cập nhật hoàn tất!"
                echo ""
                read -rp "Nhấn Enter để tiếp tục..." dummy
                clear
                ;;
            2)
                print_sub_header
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo -e "${CYAN}  CẬP NHẬT SCRIPT RCLONE MASTER${NC}"
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo ""
                print_info "Tính năng này sẽ được cập nhật trong tương lai"
                print_info "Hiện tại bạn có thể cập nhật thủ công bằng cách tải lại script"
                echo ""
                read -rp "Nhấn Enter để tiếp tục..." dummy
                clear
                ;;
            3)
                print_sub_header
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo -e "${CYAN}  PHIÊN BẢN RCLONE${NC}"
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo ""
                if command -v rclone &>/dev/null; then
                    rclone version
                else
                    print_error "Rclone chưa được cài đặt"
                fi
                echo ""
                read -rp "Nhấn Enter để tiếp tục..." dummy
                clear
                ;;
            0)
                break
                ;;
            *)
                print_error "Lựa chọn không hợp lệ"
                sleep 1
                clear
                ;;
        esac
    done
}

# Sub-menu: Gỡ cài đặt Script (trong menu Thông tin)
menu_uninstall_sub() {
    while true; do
        print_sub_header
        echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
        echo -e "${CYAN}  GỠ CÀI ĐẶT SCRIPT${NC}"
        echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
        echo ""
        echo "  1) Gỡ script (giữ config)"
        echo "  2) Gỡ hoàn toàn (xóa cả config)"
        echo "  3) Gỡ cron jobs"
        echo "  0) Quay lại"
        echo ""
        read -rp "Lựa chọn (0-3): " choice
        
        case "$choice" in
            1)
                print_sub_header
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo -e "${CYAN}  GỠ SCRIPT (GIỮ CONFIG)${NC}"
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo ""
                print_warning "Thao tác này sẽ xóa script nhưng giữ lại cấu hình"
                echo ""
                read -rp "Bạn có chắc chắn? (y/N): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    if [[ -f "$INSTALLED_SCRIPT" ]]; then
                        rm -f "$INSTALLED_SCRIPT"
                        print_success "Đã gỡ script"
                    else
                        print_info "Script chưa được cài đặt trong $INSTALLED_SCRIPT"
                    fi
                    print_info "Config vẫn được giữ tại: $CONFIG_DIR"
                else
                    print_info "Đã hủy"
                fi
                echo ""
                read -rp "Nhấn Enter để tiếp tục..." dummy
                clear
                ;;
            2)
                print_sub_header
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo -e "${CYAN}  GỠ HOÀN TOÀN${NC}"
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo ""
                print_warning "Thao tác này sẽ xóa TẤT CẢ bao gồm:"
                echo "  - Script"
                echo "  - Config"
                echo "  - Backup/Restore scripts"
                echo "  - Logs"
                echo ""
                read -rp "Bạn có chắc chắn? (y/N): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    # Remove script
                    if [[ -f "$INSTALLED_SCRIPT" ]]; then
                        rm -f "$INSTALLED_SCRIPT"
                        print_success "Đã xóa script"
                    fi
                    
                    # Remove config directory
                    if [[ -d "$CONFIG_DIR" ]]; then
                        rm -rf "$CONFIG_DIR"
                        print_success "Đã xóa config và tất cả files liên quan"
                    fi
                    
                    # Remove cron jobs
                    crontab -l 2>/dev/null | grep -v "rclone\|backup\|restore" | crontab - 2>/dev/null || true
                    print_success "Đã gỡ cron jobs"
                    
                    print_success "Đã gỡ cài đặt hoàn toàn"
                else
                    print_info "Đã hủy"
                fi
                echo ""
                read -rp "Nhấn Enter để tiếp tục..." dummy
                clear
                ;;
            3)
                print_sub_header
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo -e "${CYAN}  GỠ CRON JOBS${NC}"
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo ""
                print_info "Các cron jobs sẽ bị gỡ:"
                crontab -l 2>/dev/null | grep -i "rclone\|backup\|restore" || print_info "Không có cron job nào"
                echo ""
                read -rp "Bạn có chắc chắn muốn gỡ? (y/N): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    crontab -l 2>/dev/null | grep -v "rclone\|backup\|restore" | crontab - 2>/dev/null || true
                    print_success "Đã gỡ tất cả cron jobs liên quan"
                else
                    print_info "Đã hủy"
                fi
                echo ""
                read -rp "Nhấn Enter để tiếp tục..." dummy
                clear
                ;;
            0)
                break
                ;;
            *)
                print_error "Lựa chọn không hợp lệ"
                sleep 1
                clear
                ;;
        esac
    done
}

# Menu: Cập nhật (deprecated - moved to menu_info)
menu_update() {
    while true; do
        print_sub_header
        echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
        echo -e "${CYAN}  MENU CẬP NHẬT${NC}"
        echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
        echo ""
        echo "  1) Cập nhật Rclone"
        echo "  2) Cập nhật Script Rclone Master"
        echo "  3) Kiểm tra phiên bản Rclone"
        echo "  4) Kiểm tra phiên bản Script"
        echo "  0) Quay lại menu chính"
        echo ""
        read -rp "Lựa chọn (0-4): " choice
        
        case "$choice" in
            1)
                print_sub_header
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo -e "${CYAN}  CẬP NHẬT RCLONE${NC}"
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo ""
                print_info "Cập nhật Rclone..."
                install_rclone
                
                echo ""
                print_info "Cập nhật scripts..."
                generate_backup_script
                generate_restore_script
                
                echo ""
                print_success "Cập nhật hoàn tất!"
                echo ""
                read -rp "Nhấn Enter để tiếp tục..." dummy
                clear
                ;;
            2)
                print_sub_header
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo -e "${CYAN}  CẬP NHẬT SCRIPT RCLONE MASTER${NC}"
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo ""
                print_info "Tính năng này sẽ được cập nhật trong tương lai"
                print_info "Hiện tại bạn có thể cập nhật thủ công bằng cách tải lại script"
                echo ""
                read -rp "Nhấn Enter để tiếp tục..." dummy
                clear
                ;;
            3)
                print_sub_header
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo -e "${CYAN}  PHIÊN BẢN RCLONE${NC}"
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo ""
                if command -v rclone &>/dev/null; then
                    rclone version
                else
                    print_error "Rclone chưa được cài đặt"
                fi
                echo ""
                read -rp "Nhấn Enter để tiếp tục..." dummy
                clear
                ;;
            4)
                print_sub_header
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo -e "${CYAN}  PHIÊN BẢN SCRIPT${NC}"
                echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
                echo ""
                print_info "Rclone Master Setup Script"
                echo ""
                read -rp "Nhấn Enter để tiếp tục..." dummy
                clear
                ;;
            0)
                break
                ;;
            *)
                print_error "Lựa chọn không hợp lệ"
                sleep 1
                clear
                ;;
        esac
    done
}

# Main menu
main_menu() {
    while true; do
        print_sub_header
        echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
        echo -e "${CYAN}     RCLONE MASTER - MENU CHÍNH${NC}"
        echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "  ${GREEN}1${NC}) Cấu hình từ đầu"
        echo -e "  ${GREEN}2${NC}) Cấu hình Rclone"
        echo -e "  ${GREEN}3${NC}) Cấu hình Restore"
        echo -e "  ${GREEN}4${NC}) Cấu hình Thông báo"
        echo -e "  ${GREEN}5${NC}) Backup ngay"
        echo -e "  ${GREEN}6${NC}) Restore ngay"
        echo -e "  ${GREEN}7${NC}) Thông tin"
        echo -e "  ${RED}0${NC}) Thoát"
        echo ""
        echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
        read -rp "Nhập số lựa chọn (0-7): " choice
        
        case "$choice" in
            1)
                # Full setup
                print_header
                print_step "Bắt đầu cấu hình từ đầu..."
                echo ""
                
                # Install rclone
                if ! install_rclone; then
                    print_error "Không thể cài đặt Rclone"
                    echo ""
                    read -rp "Nhấn Enter để tiếp tục..." dummy
                    clear
                    continue
                fi
    
    echo ""
                read -rp "Nhấn Enter để tiếp tục..." dummy
                clear
                
                # Configure rclone
                configure_rclone
                save_config
                
                # Configure notifications
                configure_telegram
                save_config
                
                configure_email
                save_config
                
                echo ""
                read -rp "Nhấn Enter để tiếp tục..." dummy
                clear
                
                # Configure timezone
                configure_timezone
                save_config
                
                # Generate scripts
                generate_backup_script
                generate_restore_script
                
                # Setup cron
                setup_cron
                
                # Install to /usr/local/bin
                install_to_bin
                
                print_success "Cấu hình hoàn tất!"
                echo ""
                read -rp "Nhấn Enter để quay lại menu chính..." dummy
                clear
                ;;
            2)
                menu_configure_rclone
                ;;
            3)
                menu_configure_restore
                ;;
            4)
                menu_configure_notifications
                ;;
            5)
                menu_backup_now
                ;;
            6)
                menu_restore_now
                ;;
            7)
                menu_info
                ;;
            0)
                print_sub_header
                print_info "Cảm ơn bạn đã sử dụng Rclone Master!"
                echo ""
                exit 0
                ;;
            *)
                print_error "Lựa chọn không hợp lệ. Vui lòng chọn lại."
                sleep 1
                ;;
        esac
    done
}

# Check cron function (from check_cron.sh)
check_cron_status() {
    print_sub_header
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  KIỂM TRA CRON JOB${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Check cron service
    echo "1. Kiểm tra Cron Service:"
    if command -v systemctl &>/dev/null; then
        if systemctl is-active --quiet cron 2>/dev/null || systemctl is-active --quiet crond 2>/dev/null; then
            print_success "Cron service đang chạy"
            systemctl status cron 2>/dev/null | head -3 || systemctl status crond 2>/dev/null | head -3
        else
            print_error "Cron service KHÔNG chạy"
            print_info "Khởi động: sudo systemctl start cron hoặc sudo systemctl start crond"
        fi
    elif command -v service &>/dev/null; then
        if service cron status &>/dev/null || service crond status &>/dev/null; then
            print_success "Cron service đang chạy"
        else
            print_error "Cron service KHÔNG chạy"
            print_info "Khởi động: sudo service cron start hoặc sudo service crond start"
        fi
    else
        print_warning "Không thể kiểm tra cron service"
    fi
    echo ""
    
    # Check crontab
    echo "2. Kiểm tra Crontab của user $(whoami):"
    local crontab_content=$(crontab -l 2>/dev/null)
    if [[ -n "$crontab_content" ]]; then
        print_success "Có crontab"
        echo ""
        echo "Nội dung crontab:"
        echo "$crontab_content" | sed 's/^/   /'
        echo ""
        
        if echo "$crontab_content" | grep -qi "rclone\|backup\|restore"; then
            print_success "Tìm thấy cron job liên quan đến Rclone Master:"
            echo "$crontab_content" | grep -i "rclone\|backup\|restore" | sed 's/^/   /'
        else
            print_error "KHÔNG tìm thấy cron job liên quan đến Rclone Master"
        fi
    else
        print_error "Không có crontab"
    fi
    echo ""
    
    # Check backup script
    echo "3. Kiểm tra Backup Script:"
    if [[ -f "$BACKUP_SCRIPT" ]]; then
        print_success "Script tồn tại: $BACKUP_SCRIPT"
        if [[ -x "$BACKUP_SCRIPT" ]]; then
            print_success "Script có quyền thực thi"
        else
            print_error "Script KHÔNG có quyền thực thi"
            print_info "Sửa: chmod +x $BACKUP_SCRIPT"
        fi
    else
        print_error "Script KHÔNG tồn tại: $BACKUP_SCRIPT"
        print_info "Vui lòng chạy setup.sh để tạo script"
    fi
    echo ""
    
    # Check config file
    echo "4. Kiểm tra Config File:"
    if [[ -f "$CONFIG_FILE" ]]; then
        print_success "Config file tồn tại: $CONFIG_FILE"
        if grep -q "BACKUP_DIR=" "$CONFIG_FILE"; then
            local backup_dir=$(grep "^BACKUP_DIR=" "$CONFIG_FILE" | cut -d'"' -f2)
            print_info "BACKUP_DIR: $backup_dir"
            if [[ -d "$backup_dir" ]]; then
                print_success "Thư mục backup tồn tại"
            else
                print_error "Thư mục backup KHÔNG tồn tại"
            fi
        fi
    else
        print_error "Config file KHÔNG tồn tại: $CONFIG_FILE"
    fi
    echo ""
    
    # Check log file
    echo "5. Kiểm tra Log File:"
    if [[ -f "$LOG_FILE" ]]; then
        print_success "Log file tồn tại: $LOG_FILE"
        print_info "Kích thước: $(du -h "$LOG_FILE" | cut -f1)"
        echo ""
        echo "Nội dung log gần nhất (10 dòng cuối):"
        tail -10 "$LOG_FILE" | sed 's/^/   /'
    else
        print_info "Log file chưa tồn tại (sẽ được tạo khi chạy backup)"
    fi
    echo ""
    
    echo "───────────────────────────────────────────────────────────────"
    echo ""
    print_info "Lưu ý về Crontab:"
    echo "  - Crontab được lưu tại: /var/spool/cron/$(whoami) (CentOS/RHEL)"
    echo "  - Hoặc: /var/spool/cron/crontabs/$(whoami) (Debian/Ubuntu)"
    echo "  - Xem tất cả: crontab -l"
    echo "  - Chỉnh sửa: crontab -e"
    echo ""
    read -rp "Nhấn Enter để tiếp tục..." dummy
    clear
}

# Main setup process
main_setup() {
    print_header
    
    print_step "Bắt đầu quá trình cài đặt Rclone Master..."
    echo ""
    
    # Step 1: Install rclone
    if ! install_rclone; then
        print_error "Không thể cài đặt Rclone. Thoát."
        exit 1
    fi
    
    echo ""
    read -rp "Nhấn Enter để tiếp tục..." dummy
    clear
    
    # Step 2: Configure rclone
    configure_rclone
    save_config
    
    echo ""
    read -rp "Nhấn Enter để tiếp tục..." dummy
    clear
    
    # Step 3: Configure backup
    save_config
    
    echo ""
    read -rp "Nhấn Enter để tiếp tục..." dummy
    clear
    
    # Step 4: Configure notifications
    configure_telegram
    save_config
    
    echo ""
    configure_email
    save_config
    
    echo ""
    read -rp "Nhấn Enter để tiếp tục..." dummy
    clear
    
    # Step 5: Configure timezone
    configure_timezone
    save_config
    
    # Step 7: Generate scripts
    print_header
    generate_backup_script
    generate_restore_script
    
    # Step 8: Setup cron
    setup_cron
    
    # Final summary
    print_header
    print_success "Cài đặt hoàn tất!"
    echo ""
    print_info "Bạn có thể sử dụng menu để backup, restore và quản lý hệ thống."
    echo ""
    
    read -rp "Bạn có muốn chạy backup test ngay? (y/N): " test_backup
    if [[ "$test_backup" =~ ^[Yy]$ ]]; then
        print_info "Đang chạy backup test..."
        "$BACKUP_SCRIPT"
    fi
    
    echo ""
    read -rp "Nhấn Enter để mở menu tùy chỉnh..." dummy
    clear
    main_menu
}

# Handle command line arguments
case "${1:-}" in
"--menu" | "-m")
    # Menu mode - called by rmaster
    check_root
    create_config_dir
    load_config
    main_menu
    ;;
"--setup" | "-s")
    # Setup mode - initial setup
    check_root
    create_config_dir
    main_setup
    ;;
"--config" | "-c")
    check_root
    create_config_dir
    load_config
    main_menu
    ;;
"--help" | "-h")
    print_header
    echo "Rclone Master Setup Script"
    echo ""
    echo "Cách sử dụng:"
    echo "  $0 --setup     - Chạy setup ban đầu (cài đặt và cấu hình)"
    echo "  $0 --menu      - Mở menu quản lý (hoặc gọi script là 'rmaster')"
    echo "  $0 --help      - Hiển thị trợ giúp"
    echo ""
    echo "Menu chính bao gồm:"
    echo "  1) Cấu hình từ đầu"
    echo "  2) Cấu hình Rclone"
    echo "  3) Cấu hình Restore"
    echo "  4) Cấu hình Thông báo"
    echo "  5) Backup ngay"
    echo "  6) Restore ngay"
    echo "  7) Thông tin"
    echo "  0) Thoát"
    echo ""
    echo "Sau khi cài đặt, script sẽ được copy vào /usr/local/bin/rclone-master"
    echo "và tạo symlink /usr/local/bin/rmaster để gọi menu nhanh"
    echo ""
    exit 0
    ;;
*)
    # Default: Run setup if no config exists, otherwise show menu
    check_root
    create_config_dir
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        # No config file, run setup
        print_header
        print_info "Chưa có cấu hình. Bắt đầu setup..."
        echo ""
        read -rp "Nhấn Enter để tiếp tục..." dummy
        clear
        main_setup
    else
        # Config exists, show menu
        load_config
        main_menu
    fi
    ;;
esac

