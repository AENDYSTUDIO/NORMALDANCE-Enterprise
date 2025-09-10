#!/bin/bash

echo "=== УСТАНОВКА SSL СЕРТИФИКАТОВ ==="

# Установка Certbot
sudo apt install snapd -y
sudo snap install core; sudo snap refresh core
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot

# Получение сертификатов
sudo certbot --nginx -d dnb1st.ru -d www.dnb1st.ru
sudo certbot --nginx -d dnb1st.store -d www.dnb1st.store

# Автообновление
sudo crontab -l | { cat; echo "0 12 * * * /usr/bin/certbot renew --quiet"; } | sudo crontab -

echo "=== SSL НАСТРОЕН ==="