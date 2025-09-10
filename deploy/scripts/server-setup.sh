#!/bin/bash

echo "=== НАСТРОЙКА СЕРВЕРА ДЛЯ DNB1ST ==="

# Обновление системы
sudo apt update && sudo apt upgrade -y

# Установка Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Установка Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Установка Nginx
sudo apt install nginx -y

# Установка Git
sudo apt install git -y

# Установка Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Создание директорий
sudo mkdir -p /var/www/dnb1st.ru
sudo mkdir -p /var/www/dnb1st.store
sudo chown -R $USER:$USER /var/www/

# Копирование nginx конфигураций
sudo cp /home/aendy/deploy/nginx/dnb1st.ru.conf /etc/nginx/sites-available/
sudo cp /home/aendy/deploy/nginx/dnb1st.store.conf /etc/nginx/sites-available/

# Активация сайтов
sudo ln -sf /etc/nginx/sites-available/dnb1st.ru.conf /etc/nginx/sites-enabled/
sudo ln -sf /etc/nginx/sites-available/dnb1st.store.conf /etc/nginx/sites-enabled/

# Удаление дефолтного сайта
sudo rm -f /etc/nginx/sites-enabled/default

# Проверка и перезапуск nginx
sudo nginx -t
sudo systemctl restart nginx
sudo systemctl enable nginx

# Настройка firewall
sudo ufw allow 22
sudo ufw allow 80
sudo ufw allow 443
sudo ufw --force enable

echo "=== СЕРВЕР НАСТРОЕН ==="