# NORMALDANCE Production Deployment Guide

## 1. Подготовка сервера

### Установка зависимостей
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install postgresql postgresql-contrib redis-server nginx nodejs npm

# Установка pnpm
npm install -g pnpm

# Установка PM2 для управления процессами
npm install -g pm2
```

## 2. Настройка базы данных

```bash
# Запуск PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Выполнение setup скрипта
sudo -u postgres psql -f setup-production.sql
```

## 3. Настройка Redis

```bash
# Запуск Redis
sudo systemctl start redis-server
sudo systemctl enable redis-server

# Проверка
redis-cli ping
```

## 4. Развертывание приложения

```bash
# Клонирование репозитория
git clone https://github.com/normaldance/NORMALDANCE-Enterprise.git
cd NORMALDANCE-Enterprise

# Установка зависимостей
pnpm install

# Копирование production конфигурации
cp .env.production .env.local

# Сборка приложения
pnpm build

# Запуск миграций базы данных
pnpm prisma migrate deploy

# Запуск с PM2
pm2 start ecosystem.config.js --env production
```

## 5. Настройка Nginx

```nginx
server {
    listen 80;
    server_name normaldance.com www.normaldance.com;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

## 6. SSL сертификат

```bash
# Установка Certbot
sudo apt install certbot python3-certbot-nginx

# Получение SSL сертификата
sudo certbot --nginx -d normaldance.com -d www.normaldance.com
```

## 7. Мониторинг

### Настройка логов
```bash
# PM2 логи
pm2 logs

# Nginx логи
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

### Настройка мониторинга PM2
```bash
pm2 install pm2-server-monit
```

## 8. Безопасность

### Firewall
```bash
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
```

### Обновления системы
```bash
sudo apt update && sudo apt upgrade -y
```

## 9. Резервное копирование

### База данных
```bash
# Создание бэкапа
pg_dump -U normaldance_prod -h localhost normaldance_production > backup_$(date +%Y%m%d_%H%M%S).sql

# Восстановление
psql -U normaldance_prod -h localhost normaldance_production < backup_file.sql
```

## 10. Проверка развертывания

```bash
# Проверка статуса сервисов
sudo systemctl status postgresql
sudo systemctl status redis-server
sudo systemctl status nginx

# Проверка PM2 процессов
pm2 status

# Проверка доступности сайта
curl -I https://normaldance.com
```