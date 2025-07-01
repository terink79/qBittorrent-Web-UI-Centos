#!/bin/bash
set -e

echo "=== ⚙️ Bắt đầu cài đặt qBittorrent-nox bản mới nhất ==="

# Cài công cụ build & phụ thuộc
yum install epel-release -y
yum groupinstall "Development Tools" -y
yum install qt5-qtbase-devel qt5-qtsvg-devel qt5-qttools-devel \
boost-devel openssl-devel git firewalld curl -y

# Cài cmake >= 3.16
cd /usr/local/src
rm -rf cmake-3.25.2
curl -LO https://cmake.org/files/v3.25/cmake-3.25.2.tar.gz
tar -xzf cmake-3.25.2.tar.gz
cd cmake-3.25.2
./bootstrap --prefix=/usr/local
make -j$(nproc)
make install

# Cập nhật cmake mới toàn hệ thống
mv /usr/bin/cmake /usr/bin/cmake.bak || true
ln -s /usr/local/bin/cmake /usr/bin/cmake
hash -r

# Tạo user riêng chạy qbittorrent
useradd -r -s /sbin/nologin qbittorrent || true
mkdir -p /home/qbittorrent/.config/qBittorrent
chown -R qbittorrent:qbittorrent /home/qbittorrent

# Mở firewall
systemctl enable firewalld --now
firewall-cmd --permanent --add-port=8080/tcp
firewall-cmd --permanent --add-port=6881/udp
firewall-cmd --reload

# Clone mã nguồn qBittorrent mới nhất
cd /usr/local/src
rm -rf qBittorrent
git clone --recursive https://github.com/qbittorrent/qBittorrent.git
cd qBittorrent
mkdir -p build && cd build
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DGUI=OFF ..
make -j$(nproc)
make install

# Tạo systemd service
cat <<EOF > /etc/systemd/system/qbittorrent.service
[Unit]
Description=qBittorrent-nox Web UI
After=network.target

[Service]
User=qbittorrent
ExecStart=/usr/bin/qbittorrent-nox
WorkingDirectory=/home/qbittorrent
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable qbittorrent --now

echo
echo "✅ Cài xong! qBittorrent Web UI: http://<IP>:8080"
echo "📝 Mặc định: user=admin | pass=adminadmin"
