#!/bin/bash

# --- CẤU HÌNH BAN ĐẦU (CÓ THỂ THAY ĐỔI) ---
# Tên người dùng cho Web UI của qBittorrent
QBITTORRENT_USER="admin"

# Mật khẩu ban đầu cho Web UI của qBittorrent.
# KHUYẾN CÁO: Sử dụng mật khẩu đơn giản cho lần cài đặt đầu tiên (ví dụ: adminpass)
# để tránh các vấn đề với ký tự đặc biệt trong quá trình băm mật khẩu ban đầu.
# SAU KHI ĐĂNG NHẬP THÀNH CÔNG, HÃY THAY ĐỔI NÓ NGAY LẬP TỨC TRONG GIAO DIỆN WEB UI!
QBITTORRENT_PASS="adminadmin" # Đổi thành mật khẩu bạn muốn nếu cần.

# Cổng Web UI của qBittorrent (mặc định là 8080)
WEBUI_PORT="8080"

# Cổng P2P của qBittorrent (mặc định là 6881, có thể thay đổi trong Web UI sau)
PEER_PORT="6881"

# Đường dẫn đến thư mục tải xuống và cấu hình
DOWNLOAD_DIR="/var/lib/qbittorrent-nox/downloads"
CONFIG_DIR="/var/lib/qbittorrent-nox/.config/qBittorrent"
SERVICE_FILE="/etc/systemd/system/qbittorrent-nox.service"
QBITTORRENT_CONF_PATH="${CONFIG_DIR}/qBittorrent.conf"

# Địa chỉ IP của VPS (sẽ tự động phát hiện)
VPS_IP=$(curl -s api.ipify.org)

# --- BẮT ĐẦU CÀI ĐẶT ---
echo "--- BẮT ĐẦU CÀI ĐẶT QBITTORRENT-NOX TRÊN UBUNTU SERVER 22.04 LTS ---"
echo "Địa chỉ IP của VPS của bạn là: ${VPS_IP}"
echo "Tên người dùng qBittorrent Web UI mặc định: ${QBITTORRENT_USER}"
echo "Mật khẩu qBittorrent Web UI mặc định: ${QBITTORRENT_PASS}"
echo ""
echo "LƯU Ý QUAN TRỌNG: Bạn PHẢI đổi mật khẩu này ngay lập tức sau khi đăng nhập!"
echo "Tiếp tục trong 5 giây..."
sleep 5

# 1. Cập nhật hệ thống và cài đặt các gói cơ bản cần thiết
echo "1. Cập nhật hệ thống và cài đặt các gói cơ bản (curl, wget, git, jq, ufw)..."
sudo apt update -y || { echo "Lỗi: Không thể cập nhật apt. Kiểm tra kết nối mạng."; exit 1; }
sudo apt upgrade -y
sudo apt install -y curl wget git jq ufw || { echo "Lỗi: Không thể cài đặt các công cụ cơ bản."; exit 1; }
echo "Hoàn tất cập nhật hệ thống và cài đặt gói cơ bản."
echo ""

# 2. Cài đặt qBittorrent-nox
echo "2. Cài đặt qBittorrent-nox..."
sudo apt install -y qbittorrent-nox || { echo "Lỗi: Không thể cài đặt qbittorrent-nox. Vui lòng kiểm tra lại."; exit 1; }
echo "Hoàn tất cài đặt qBittorrent-nox."
echo ""

# 3. Tạo người dùng và nhóm riêng cho qBittorrent-nox
echo "3. Tạo người dùng và nhóm hệ thống 'qbittorrent-nox'..."
if ! id -u qbittorrent-nox &>/dev/null; then
    # --system: Tạo tài khoản hệ thống (không login được)
    # --group: Tạo nhóm cùng tên
    # --no-create-home: Không tạo thư mục home riêng (chúng ta dùng /var/lib)
    sudo adduser --system --group --no-create-home qbittorrent-nox || { echo "Lỗi: Không thể tạo người dùng qbittorrent-nox."; exit 1; }
else
    echo "Người dùng 'qbittorrent-nox' đã tồn tại."
fi
echo "Hoàn tất tạo người dùng."
echo ""

# 4. Dọn dẹp thư mục cũ và tạo thư mục tải xuống, cấu hình, cấp quyền
echo "4. Dọn dẹp thư mục cấu hình/cache cũ và tạo thư mục mới, cấp quyền..."
# Xóa các thư mục cũ (nếu có từ lần cài đặt/thử nghiệm trước) để đảm bảo sạch sẽ
sudo rm -rf /var/lib/qbittorrent-nox/.config
sudo rm -rf /var/lib/qbittorrent-nox/.cache

# Tạo lại các thư mục chính
sudo mkdir -p "${DOWNLOAD_DIR}"
sudo mkdir -p "${CONFIG_DIR}"
sudo mkdir -p /var/lib/qbittorrent-nox/.cache # Thư mục cache mặc định

# Cấp quyền sở hữu cho người dùng qbittorrent-nox cho toàn bộ /var/lib/qbittorrent-nox
sudo chown -R qbittorrent-nox:qbittorrent-nox /var/lib/qbittorrent-nox

# Thiết lập quyền cụ thể cho từng thư mục
sudo chmod -R 700 "${CONFIG_DIR}"   # Quyền chặt chẽ (chỉ chủ sở hữu đọc/ghi/thực thi) cho thư mục cấu hình
sudo chmod -R 775 "${DOWNLOAD_DIR}" # Cho phép user/group ghi, others đọc/thực thi (thường dùng cho downloads)
sudo chmod -R 775 /var/lib/qbittorrent-nox/.cache # Quyền rộng hơn cho thư mục cache

echo "Hoàn tất tạo thư mục và cấp quyền."
echo ""

# 5. Tạo Service file cho qBittorrent-nox
echo "5. Tạo Systemd service file cho qBittorrent-nox..."
sudo tee "${SERVICE_FILE}" > /dev/null << EOF
[Unit]
Description=qBittorrent Command Line Client
After=network.target

[Service]
User=qbittorrent-nox
Group=qbittorrent-nox
Type=forking
ExecStart=/usr/bin/qbittorrent-nox --webui-port=${WEBUI_PORT} -d
Restart=on-failure
Environment="QBT_PROFILE=${CONFIG_DIR}"

[Install]
WantedBy=multi-user.target
EOF
echo "Hoàn tất tạo service file."
echo ""

# 6. Cấu hình ban đầu của qBittorrent.conf
echo "6. Tạo và cấu hình file qBittorrent.conf ban đầu với mật khẩu..."
# Tạo file cấu hình với các thiết lập cơ bản và mật khẩu
sudo tee "${QBITTORRENT_CONF_PATH}" > /dev/null << EOF
[LegalNotice]
Accepted=true

[Preferences]
WebUI/Username=${QBITTORRENT_USER}
WebUI/Password=${QBITTORRENT_PASS}
WebUI/Port=${WEBUI_PORT}
WebUI/CSRFProtection=false
Connection/PortRangeMin=${PEER_PORT}
Connection/PortRangeMax=${PEER_PORT}
EOF

# Đảm bảo quyền sở hữu và quyền truy cập đúng cho file cấu hình
sudo chown qbittorrent-nox:qbittorrent-nox "${QBITTORRENT_CONF_PATH}"
sudo chmod 600 "${QBITTORRENT_CONF_PATH}" # Chỉ chủ sở hữu đọc/ghi

echo "Hoàn tất cấu hình qBittorrent.conf."
echo ""

# 7. Khởi động và Kích hoạt qBittorrent Service
echo "7. Tải lại Systemd, kích hoạt và khởi động qBittorrent service..."
sudo systemctl daemon-reload
sudo systemctl enable qbittorrent-nox # Kích hoạt để tự khởi động khi boot
sudo systemctl start qbittorrent-nox

# Kiểm tra trạng thái dịch vụ
if systemctl is-active --quiet qbittorrent-nox; then
    echo "qBittorrent-nox đã khởi động thành công."
else
    echo "Lỗi: qBittorrent-nox không thể khởi động. Vui lòng kiểm tra nhật ký chi tiết:"
    echo "sudo journalctl -u qbittorrent-nox --no-pager -f"
    exit 1
fi
echo ""

# 8. Cấu hình Firewall (UFW)
echo "8. Cấu hình Firewall (UFW)..."
sudo ufw allow ssh comment 'Allow SSH access' # Đảm bảo SSH vẫn hoạt động
sudo ufw allow ${WEBUI_PORT}/tcp comment 'qBittorrent Web UI'
sudo ufw allow ${PEER_PORT}/tcp comment 'qBittorrent P2P TCP'
sudo ufw allow ${PEER_PORT}/udp comment 'qBittorrent P2P UDP'
sudo ufw --force enable # Bật UFW nếu nó chưa bật (sẽ yêu cầu xác nhận nếu chạy thủ công, --force để tự động)
echo "Hoàn tất cấu hình UFW. Firewall đã được bật."
echo ""

echo "--- CÀI ĐẶT QBITTORRENT-NOX HOÀN TẤT THÀNH CÔNG! ---"
echo ""
echo "Bạn có thể truy cập qBittorrent Web UI tại địa chỉ:"
echo "http://${VPS_IP}:${WEBUI_PORT}"
echo ""
echo "Sử dụng tài khoản ban đầu (bạn PHẢI đổi ngay sau khi đăng nhập):"
echo "Username: ${QBITTORRENT_USER}"
echo "Password: ${QBITTORRENT_PASS}"
echo ""
echo "### Hướng dẫn tạo Magnet Link và Quản lý qua Web UI:"
echo "1. Đăng nhập vào Web UI với tài khoản trên."
echo "2. Đi tới 'Tools' (biểu tượng bánh răng ở góc trên bên phải) -> 'Options' -> tab 'Web UI' và **thay đổi mật khẩu ngay lập tức** để bảo mật."
echo "3. Để tạo một torrent mới (bao gồm cả magnet link):"
echo "   - Trong giao diện Web UI, nhấp vào biểu tượng **'Create new torrent'** (thường là một dấu '+' hoặc bánh răng)."
echo "   - Chọn **'Source'** là **'File'** hoặc **'Folder'** và nhập đường dẫn đầy đủ đến file/thư mục của bạn trên VPS (ví dụ: \`\$DOWNLOAD_DIR/my_video.mp4\`)."
echo "   - Thêm các **'Trackers'** (có thể sử dụng các tracker công khai như:"
echo "     udp://tracker.opentrackr.org:1337/announce"
    echo "     udp://tracker.coppersurfer.tk:6969/announce"
    echo "     udp://tracker.leechers-paradise.org:6969/announce"
    echo "     udp://p4p.arenabg.com:1337/announce"
    echo "     udp://tracker.internetwarriors.net:1337/announce"
    echo "   - Đặt tên cho torrent (nếu cần), chọn thư mục lưu và các tùy chọn khác."
    echo "   - Nhấn **'Create'**. qBittorrent sẽ tạo file .torrent và hiển thị magnet link cho bạn."
    echo ""
    echo "Chúc bạn sử dụng qBittorrent-nox hiệu quả!"
