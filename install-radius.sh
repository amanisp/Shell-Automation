#!/bin/bash

# ================================
# AUTO INSTALL FREERADIUS + MYSQL
# ================================

MYSQL_ROOT_PASS="!Tahun2026"
DB_NAME="radius"
DB_USER="radiususer"
DB_PASS="!Tahun2026"

echo "🚀 Update & Upgrade system..."
sudo apt update && sudo apt upgrade -y

echo "📦 Install repository PHP 8.3..."
sudo apt install -y software-properties-common
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update

echo "🐘 Install PHP 8.3..."
sudo apt install -y php8.3 php8.3-cli php8.3-fpm php8.3-{bz2,curl,mbstring,intl}

echo "🔄 Disable PHP lama (jika ada)..."
sudo a2disconf php8.2-fpm 2>/dev/null || true
sudo apt purge -y php8.2* 2>/dev/null || true

echo "🌐 Install Apache + module PHP..."
sudo apt install -y apache2 libapache2-mod-php
sudo a2enconf php8.3-fpm

echo "📡 Install FreeRADIUS + MySQL..."
sudo apt install -y freeradius freeradius-mysql freeradius-utils mysql-server

echo "⚙️ Enable service..."
sudo systemctl enable apache2
sudo systemctl enable freeradius
sudo systemctl enable mysql

echo "🔐 Setup MySQL..."
sudo mysql <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASS}';
FLUSH PRIVILEGES;
EOF

echo "🗄️ Create database & user..."
mysql -u root -p${MYSQL_ROOT_PASS} <<EOF
CREATE DATABASE IF NOT EXISTS ${DB_NAME};
CREATE DATABASE IF NOT EXISTS billing;

CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';

GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
GRANT ALL PRIVILEGES ON billing.* TO '${DB_USER}'@'localhost';

FLUSH PRIVILEGES;
EOF

echo "📥 Import schema FreeRADIUS..."
sudo mysql -u root -p${MYSQL_ROOT_PASS} ${DB_NAME} < /etc/freeradius/3.0/mods-config/sql/main/mysql/schema.sql

echo "🔗 Enable SQL module FreeRADIUS..."
sudo ln -sf /etc/freeradius/3.0/mods-available/sql /etc/freeradius/3.0/mods-enabled/

echo "⚙️ Set permission..."
sudo chgrp -h freerad /etc/freeradius/3.0/mods-available/sql
sudo chown -R freerad:freerad /etc/freeradius/3.0/mods-enabled/sql

echo "🔧 Configure SQL (edit manual jika perlu)..."
sed -i "s/login = .*/login = \"${DB_USER}\"/g" /etc/freeradius/3.0/mods-enabled/sql
sed -i "s/password = .*/password = \"${DB_PASS}\"/g" /etc/freeradius/3.0/mods-enabled/sql

echo "🔄 Restart FreeRADIUS..."
sudo systemctl restart freeradius

echo "📊 Install phpMyAdmin..."
sudo apt install -y phpmyadmin

echo "✅ DONE!"
echo "======================================="
echo "Database : ${DB_NAME}"
echo "User     : ${DB_USER}"
echo "Password : ${DB_PASS}"
echo "MySQL Root Password : ${MYSQL_ROOT_PASS}"
echo "======================================="
