#!/bin/bash

set -e
set +H

# ==============================
# CONFIG
# ==============================
APP_DIR="/var/www/billing-radius"
REPO_URL="https://github.com/amanisp/billing-radius.git"

DB_HOST="localhost"
DB_NAME="billing"
DB_USER="radiususer"
DB_PASS="!Tahun2026"

echo "🚀 Update system..."
apt update -y

echo "🌐 Install Apache..."
apt install -y apache2
a2enmod rewrite

echo "🐘 Install PHP 8.3 + Apache module..."
apt install -y php8.3 libapache2-mod-php php8.3-mysql php8.3-xml php8.3-mbstring php8.3-curl php8.3-zip php8.3-bcmath php8.3-gd redis-server

systemctl restart apache2
systemctl enable redis
systemctl start redis

echo "📦 Install dependencies..."
apt install -y git curl unzip

echo "🎼 Install Composer..."
EXPECTED_SIGNATURE=$(wget -q -O - https://composer.github.io/installer.sig)
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
ACTUAL_SIGNATURE=$(php -r "echo hash_file('sha384', 'composer-setup.php');")

if [ "$EXPECTED_SIGNATURE" != "$ACTUAL_SIGNATURE" ]; then
    echo '❌ Invalid Composer installer'
    rm composer-setup.php
    exit 1
fi

php composer-setup.php --install-dir=/usr/local/bin --filename=composer
rm composer-setup.php

echo "📥 Clone project..."
rm -rf $APP_DIR
git clone $REPO_URL $APP_DIR

cd $APP_DIR

echo "📦 Install Laravel..."
composer install --no-interaction --prefer-dist --optimize-autoloader

echo "⚙️ Setup ENV..."
cp .env.example .env

sed -i "s/DB_HOST=.*/DB_HOST=${DB_HOST}/g" .env
sed -i "s/DB_DATABASE=.*/DB_DATABASE=${DB_NAME}/g" .env
sed -i "s/DB_USERNAME=.*/DB_USERNAME=${DB_USER}/g" .env
sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=${DB_PASS}/g" .env

echo "🔑 Generate key..."
php artisan key:generate

echo "🗄️ Migrate database..."
php artisan migrate --force

echo "👨🏻‍💼 Jalankan seeder user"
php artisan db:seed --class UserSeeder
echo "🔐 Set permission..."
chown -R www-data:www-data $APP_DIR
chmod -R 775 $APP_DIR/storage
chmod -R 775 $APP_DIR/bootstrap/cache

echo "🌐 Setup Apache VirtualHost..."

cat > /etc/apache2/sites-available/billing.conf <<EOF
<VirtualHost *:80>
    ServerName _

    DocumentRoot $APP_DIR/public

    <Directory $APP_DIR/public>
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/billing_error.log
    CustomLog \${APACHE_LOG_DIR}/billing_access.log combined
</VirtualHost>
EOF

a2dissite 000-default.conf || true
a2ensite billing.conf

systemctl reload apache2

echo "🔥 Optimize Laravel..."
php artisan config:cache
php artisan route:cache
php artisan view:cache

echo "✅ DONE!"
echo "======================================="
echo "🌐 Akses: http://IP_SERVER"
echo "📁 Path : $APP_DIR"
echo "🗄️ DB   : $DB_NAME"
echo "👤 User : $DB_USER"
echo "======================================="
