# Скрипт развертывания NORMALDANCE Enterprise

## Описание

Скрипт `deploy-nextjs-ruvds.sh` автоматизирует развертывание Next.js приложения NORMALDANCE Enterprise на сервере Ubuntu/Debian через Git clone + systemd.

## Требования

### Системные требования:

- Ubuntu 20.04+ или Debian 11+
- Root права (sudo)
- Минимум 2GB RAM
- 10GB свободного места на диске

### Программные зависимости:

- Git
- Node.js 20+
- Nginx
- Systemd
- curl

## Подготовка к развертыванию

### 1. Настройка DNS

Добавьте A и AAAA записи для вашего домена:

```
A    your-domain.com    IP_ВАШЕГО_СЕРВЕРА
AAAA your-domain.com    IPv6_ВАШЕГО_СЕРВЕРА
```

### 2. Открытие портов

```bash
# Открыть порты в firewall
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw allow 3000/tcp  # Next.js (для отладки)
sudo ufw --force enable
```

### 3. Настройка переменных окружения

Отредактируйте переменные в начале скрипта:

```bash
DATABASE_URL="postgresql://user:pass@localhost:5432/normaldance"
NEXTAUTH_SECRET="your-super-secret-key-here"
NEXTAUTH_URL="https://your-domain.com"
NEXT_PUBLIC_SOLANA_RPC_URL="https://api.mainnet-beta.solana.com"
REDIS_URL="redis://localhost:6379"
```

## Запуск развертывания

### 1. Загрузка скрипта на сервер

```bash
# Копирование скрипта на сервер
scp scripts/deploy-nextjs-ruvds.sh user@your-server:/tmp/
```

### 2. Подключение к серверу

```bash
ssh user@your-server
```

### 3. Запуск скрипта

```bash
# Перемещение скрипта в /usr/local/bin
sudo mv /tmp/deploy-nextjs-ruvds.sh /usr/local/bin/

# Запуск развертывания
sudo deploy-nextjs-ruvds.sh
```

## Процесс развертывания

Скрипт выполняет следующие шаги:

1. **Проверка зависимостей** - проверка наличия необходимых программ
2. **Установка Node.js 20** - установка или обновление Node.js
3. **Настройка пользователя** - создание пользователя `normaldance`
4. **Резервное копирование** - создание бэкапа перед развертыванием
5. **Клонирование репозитория** - клонирование кода с GitHub
6. **Установка зависимостей** - установка npm пакетов
7. **Генерация Prisma клиента** - создание Prisma клиента
8. **Применение схемы БД** - создание и миграция базы данных
9. **Сборка приложения** - компиляция Next.js приложения
10. **Создание systemd сервиса** - настройка сервиса для управления приложением
11. **Настройка Nginx** - настройка reverse proxy и SSL
12. **Запуск приложения** - запуск и проверка работы
13. **Финальная проверка** - проверка здоровья приложения

## Управление приложением

### Основные команды

```bash
# Проверка статуса
sudo systemctl status normaldance

# Просмотр логов
sudo journalctl -u normaldance -f

# Перезапуск приложения
sudo systemctl restart normaldance

# Остановка приложения
sudo systemctl stop normaldance

# Запуск приложения
sudo systemctl start normaldance

# Включение автозапуска
sudo systemctl enable normaldance
```

### Логирование

```bash
# Лог развертывания
tail -f /opt/normaldance/deployment.log

# Логи приложения
tail -f /opt/normaldance/logs/combined.log
```

## Настройка SSL

### 1. Установка SSL сертификата

```bash
# Запуск Certbot
sudo certbot --nginx -d your-domain.com -d www.your-domain.com
```

### 2. Автоматическое обновление SSL

```bash
# Добавление в cron
sudo crontab -e
```

Добавьте строку:

```
0 12 * * * /usr/bin/certbot renew --quiet
```

## Мониторинг

### 1. Проверка здоровья приложения

```bash
curl http://localhost/health
```

### 2. Проверка WebSocket

```bash
# Тестирование WebSocket соединения
wscat -c ws://your-domain.com/api/socketio
```

### 3. Мониторинг ресурсов

```bash
# Использование CPU и памяти
htop

# Дисковое пространство
df -h

# Использование памяти
free -h
```

## Обновление приложения

### 1. Обновление кода

```bash
cd /opt/normaldance
git pull origin main
```

### 2. Обновление зависимостей

```bash
npm ci
```

### 3. Пересборка приложения

```bash
npm run build
```

### 4. Перезапуск сервиса

```bash
sudo systemctl restart normaldance
```

## Откат изменений

### 1. Восстановление из бэкапа

```bash
# Список бэкапов
ls -la /var/backups/normaldance/

# Восстановление бэкапа
cp -r /var/backups/normaldance/normaldance-backup-20240101_120000 /opt/normaldance

# Перезапуск приложения
sudo systemctl restart normaldance
```

## Решение проблем

### 1. Приложение не запускается

```bash
# Проверка статуса
sudo systemctl status normaldance

# Просмотр логов
sudo journalctl -u normaldance --since "1 hour ago"

# Проверка портов
sudo ss -tulpn | grep 3000
```

### 2. Ошибки Nginx

```bash
# Проверка конфигурации
sudo nginx -t

# Просмотр логов Nginx
sudo tail -f /var/log/nginx/error.log
```

### 3. Ошибки базы данных

```bash
# Проверка подключения к базе данных
cd /opt/normaldance
npx prisma db status

# Просмотр логов Prisma
tail -f /opt/normaldance/logs/prisma.log
```

### 4. Ошибки сборки

```bash
# Повторная сборка
cd /opt/normaldance
npm run build

# Проверка зависимостей
npm audit
```

## Безопасность

### 1. Обновление системы

```bash
# Обновление пакетов
sudo apt update && sudo apt upgrade -y

# Обновление Node.js
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
```

### 2. Настройка firewall

```bash
# Разрешение только необходимых портов
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable
```

### 3. Защита от DDoS

```bash
# Установка fail2ban
sudo apt install -y fail2ban

# Настройка fail2ban
sudo nano /etc/fail2ban/jail.local
```

## Оптимизация производительности

### 1. Кеширование Nginx

```bash
# Настройка кеширования в Nginx
sudo nano /etc/nginx/nginx.conf
```

Добавьте в http секцию:

```nginx
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=cache:10m inactive=60m;
```

### 2. Оптимизация Node.js

```bash
# Увеличение лимита файловых дескрипторов
echo "fs.file-max = 100000" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### 3. Оптимация базы данных

```bash
# Настройка PostgreSQL
sudo nano /etc/postgresql/13/main/postgresql.conf
```

## Поддержка

### 1. Логи для отладки

```bash
# Логи развертывания
tail -f /opt/normaldance/deployment.log

# Логи приложения
sudo journalctl -u normaldance -f

# Логи Nginx
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

### 2. Профилирование производительности

```bash
# Профилирование Node.js
node --prof /usr/bin/npm start

# Анализ heap dump
node --inspect /usr/bin/npm start
```

## Версия скрипта

**Версия:** 1.0.0  
**Дата:** 2024-01-01  
**Совместимость:** Ubuntu 20.04+, Debian 11+

## Лицензия

Этот скрипт предоставляется как есть, без каких-либо гарантий. Используйте на свой страх и риск.
