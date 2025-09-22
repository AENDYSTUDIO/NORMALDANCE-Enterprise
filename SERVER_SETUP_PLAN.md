# 🚀 План настройки бюджетного сервера для NORMALDANCE

## 📋 Общая информация

**Проект**: NORMALDANCE Enterprise - децентрализованная музыкальная платформа  
**Домен**: normaldance.ru  
**Технологии**: Next.js 15, TypeScript, Prisma, SQLite, Socket.IO, Web3  
**Бюджет**: $3.99/месяц (Hetzner)  
**Срок реализации**: 2-3 часа

## 🎯 Выбранная инфраструктура

### VPS-хостинг: Hetzner CX11

- **CPU**: 1 ядро AMD EPYC
- **RAM**: 2 GB DDR4
- **Диск**: 25 GB NVMe SSD
- **Трафик**: 20 TB/месяц
- **IPv4**: 1 адрес
- **IPv6**: Поддерживается
- **Цена**: $3.99/месяц

### Архитектура развертывания

```
Интернет → Nginx (reverse-proxy) → Next.js (systemd) → SQLite
                    ↓
                SSL/TLS (Let's Encrypt)
                    ↓
                WebSocket (Socket.IO)
```

## 📝 Детальный план реализации

### Этап 1: Подготовка VPS сервера

1. **Заказ VPS на Hetzner**

   - Выбрать локацию (FSN1 - ФРГ или NUE1 - Нюрнберг)
   - Настроить SSH ключи
   - Создать non-root пользователя

2. **Базовая настройка системы**

   ```bash
   # Обновление системы
   sudo apt update && sudo apt upgrade -y

   # Установка основных пакетов
   sudo apt install -y git curl wget htop unzip

   # Настройка swap-файла (2GB)
   sudo fallocate -l 2G /swapfile
   sudo chmod 600 /swapfile
   sudo mkswap /swapfile
   sudo swapon /swapfile
   echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
   ```

### Этап 2: Настройка DNS

1. **A-запись**: Указать IP-адрес VPS
2. **AAAA-запись**: Указать IPv6 адрес (если доступен)
3. **Проверка propagation**: Использовать tools like dnschecker.org

### Этап 3: Установка и настройка LEMP-стека

1. **Nginx**

   ```bash
   sudo apt install -y nginx
   sudo systemctl enable nginx
   sudo systemctl start nginx
   ```

2. **Node.js (для Next.js)**

   ```bash
   curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
   sudo apt install -y nodejs
   ```

3. **MariaDB (опционально)**

   ```bash
   sudo apt install -y mariadb-server
   sudo systemctl enable mariadb
   sudo systemctl start mariadb
   ```

4. **PHP 8.x**
   ```bash
   sudo apt install -y php8.2-fpm php8.2-mysql php8.2-xml php8.2-curl
   sudo systemctl enable php8.2-fpm
   ```

### Этап 4: Настройка безопасности

1. **UFW файрвол**

   ```bash
   sudo ufw allow OpenSSH
   sudo ufw allow 'Nginx Full'
   sudo ufw enable
   ```

2. **Fail2Ban**

   ```bash
   sudo apt install -y fail2ban
   sudo systemctl enable fail2ban
   ```

3. **Безопасность SSH**
   ```bash
   # Отключение root-доступа
   sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
   sudo systemctl restart sshd
   ```

### Этап 5: Создание виртуального хоста

```bash
# Создание директорий
sudo mkdir -p /var/www/normaldance.ru
sudo chown -R $USER:$USER /var/www/normaldance.ru

# Конфигурация Nginx
sudo tee /etc/nginx/sites-available/normaldance.ru > /dev/null <<EOF
server {
    listen 80;
    server_name normaldance.ru www.normaldance.ru;

    root /var/www/normaldance.ru;
    index index.html;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    # Статические файлы
    location /_next/static/ {
        alias /var/www/normaldance.ru/.next/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # WebSocket
    location /api/socketio/ {
        proxy_pass http://localhost:3000/api/socketio/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/normaldance.ru /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

### Этап 6: Развертывание Next.js приложения

1. **Клонирование репозитория**

   ```bash
   cd /var/www/normaldance.ru
   git clone https://github.com/normaldance/NORMALDANCE-Enterprise.git .
   ```

2. **Установка зависимостей**

   ```bash
   npm install --production
   npm run db:generate
   npm run db:push
   ```

3. **Сборка приложения**

   ```bash
   npm run build
   ```

4. **Настройка systemd**
   ```bash
   sudo tee /etc/systemd/system/normaldance.service > /dev/null <<EOF
   [Unit]
   Description=NormalDance Next.js Application
   After=network.target
   ```

[Service]
Type=simple
User=www-data
WorkingDirectory=/var/www/normaldance.ru
Environment=NODE_ENV=production
Environment=PORT=3000
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable normaldance
sudo systemctl start normaldance

````

### Этап 7: Настройка SSL
```bash
# Установка Certbot
sudo apt install -y certbot python3-certbot-nginx

# Получение SSL сертификата
sudo certbot --nginx -d normaldance.ru -d www.normaldance.ru

# Автоматическое обновление
sudo crontab -e
# Добавить: 0 12 * * * /usr/bin/certbot renew --quiet
````

### Этап 8: Оптимизация производительности

1. **Nginx оптимизация**

   ```bash
   sudo tee /etc/nginx/conf.d/gzip.conf > /dev/null <<EOF
   gzip on;
   gzip_vary on;
   gzip_min_length 1024;
   gzip_proxied any;
   gzip_comp_level 6;
   gzip_types
       text/plain
       text/css
       text/xml
       text/javascript
       application/javascript
       application/xml+rss
       application/json;
   EOF
   ```

2. **Кэширование**
   ```bash
   sudo tee /etc/nginx/conf.d/cache.conf > /dev/null <<EOF
   open_file_cache max=1000 inactive=20s;
   open_file_cache_valid 30s;
   open_file_cache_min_uses 2;
   open_file_cache_errors on;
   EOF
   ```

### Этап 9: Резервное копирование

```bash
# Скрипт резервного копирования
sudo tee /usr/local/bin/backup-normaldance.sh > /dev/null <<EOF
#!/bin/bash
DATE=\$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/var/backups/normaldance"
APP_DIR="/var/www/normaldance.ru"

mkdir -p \$BACKUP_DIR

# База данных
cp \$APP_DIR/prisma/db/custom.db \$BACKUP_DIR/normaldance_db_\$DATE.db

# Код приложения
tar -czf \$BACKUP_DIR/normaldance_code_\$DATE.tar.gz -C \$APP_DIR .

# Удаление старых бэкапов (остаются последние 7)
find \$BACKUP_DIR -name "*.db" -mtime +7 -delete
find \$BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete

echo "Backup completed: \$DATE"
EOF

sudo chmod +x /usr/local/bin/backup-normaldance.sh

# Настройка cron
sudo crontab -e
# Добавить: 0 2 * * * /usr/local/bin/backup-normaldance.sh
```

### Этап 10: Проверка и тестирование

1. **Проверка работы сайта**

   ```bash
   curl -I https://normaldance.ru
   ```

2. **Проверка SSL**

   ```bash
   sudo certbot certificates
   ```

3. **Проверка производительности**
   ```bash
   curl -s -w "Time: %{time_total}s\nSize: %{size_download} bytes\n" -o /dev/null https://normaldance.ru
   ```

## 🔐 Конфигурация окружения

### Файл .env для продакшена

```env
# Database
DATABASE_URL="file:./prisma/db/custom.db"

# NextAuth.js
NEXTAUTH_URL="https://normaldance.ru"
NEXTAUTH_SECRET="your-secure-secret-key-here"

# Node Environment
NODE_ENV="production"

# WebSocket
SOCKET_PORT=3000

# Redis (если используется)
REDIS_URL="redis://localhost:6379"

# Web3 (опционально)
WALLET_CONNECT_PROJECT_ID="your-wallet-connect-id"
```

## 📊 Мониторинг и логирование

### Логирование Nginx

```bash
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

### Логирование приложения

```bash
sudo journalctl -u normaldance -f
```

## 🚨 План действий при проблемах

1. **Сайт не доступен**

   - Проверить Nginx: `sudo nginx -t`
   - Проверить сервис: `sudo systemctl status normaldance`
   - Проверить логи: `sudo journalctl -u normaldance`

2. **SSL проблемы**

   - Проверить сертификат: `sudo certbot certificates`
   - Обновить сертификат: `sudo certbot renew --dry-run`

3. **Производительность**
   - Проверить нагрузку: `htop`
   - Проверить память: `free -h`
   - Проверить диск: `df -h`

## 💰 Бюджет

| Позиция              | Стоимость   | Примечание             |
| -------------------- | ----------- | ---------------------- |
| Hetzner CX11         | $3.99/месяц | Основной сервер        |
| Домен normaldance.ru | $10-15/год  | Уже есть у вас         |
| Итого                | $3.99/месяц | Максимально экономично |

## 🎯 Ожидаемые результаты

- ✅ Сайт доступен по HTTPS: https://normaldance.ru
- ✅ WebSocket соединение работает
- ✅ Оптимизированная производительность
- ✅ Базовая безопасность реализована
- ✅ Автоматическое резервное копирование
- ✅ Мониторинг состояния сервера

---

**Создано для NORMALDANCE Enterprise** 🎵
**Дата**: 2025-09-20
**Версия**: 1.0
