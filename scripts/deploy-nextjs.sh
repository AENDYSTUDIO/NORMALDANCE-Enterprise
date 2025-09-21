#!/bin/bash

# Скрипт для развертывания Next.js приложения на сервере
# Для NORMALDANCE Enterprise

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Начинаю развертывание Next.js приложения для NORMALDANCE${NC}"
echo -e "${GREEN}========================================================${NC}"

# Переменные
SERVER_IP=""
APP_USER="normaldance"
APP_DIR="/var/www/normaldance.ru"
BACKUP_DIR="/var/backups/normaldance"
REPO_URL="https://github.com/normaldance/NORMALDANCE-Enterprise.git"

# Функция для получения IP адреса
get_server_ip() {
    echo -e "${YELLOW}🌐 Введите IP адрес сервера:${NC}"
    read -p "IP адрес: " SERVER_IP
    
    if [[ ! $SERVER_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}❌ Неверный формат IP адреса${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ IP адрес: $SERVER_IP${NC}"
}

# Функция для проверки подключения к серверу
test_connection() {
    echo -e "${YELLOW}🔌 Тестирование подключения к серверу${NC}"
    
    # Проверка доступности сервера
    echo "Проверка доступности сервера..."
    timeout 30 bash -c "until ping -c 1 $SERVER_IP &> /dev/null; do sleep 1; done"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Сервер доступен${NC}"
    else
        echo -e "${RED}❌ Сервер недоступен${NC}"
        exit 1
    fi
    
    # Проверка SSH подключения
    echo "Проверка SSH подключения..."
    if ssh -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=5 $APP_USER@$SERVER_IP "exit" 2>/dev/null; then
        echo -e "${GREEN}✅ SSH подключение работает${NC}"
    else
        echo -e "${RED}❌ SSH подключение не работает${NC}"
        exit 1
    fi
}

# Функция для создания резервной копии
create_backup() {
    echo -e "${YELLOW}💾 Создание резервной копии${NC}"
    
    # Создание бэкапа базы данных
    ssh $APP_USER@$SERVER_IP "if [ -f $APP_DIR/prisma/db/custom.db ]; then cp $APP_DIR/prisma/db/custom.db $BACKUP_DIR/normaldance_db_\$(date +%Y%m%d_%H%M%S).db; fi"
    
    # Создание бэкапа кода
    ssh $APP_USER@$SERVER_IP "if [ -d $APP_DIR ]; then tar -czf $BACKUP_DIR/normaldance_code_\$(date +%Y%m%d_%H%M%S).tar.gz -C $APP_DIR --exclude=node_modules --exclude=.next .; fi"
    
    echo -e "${GREEN}✅ Резервная копия создана${NC}"
}

# Функция для клонирования репозитория
clone_repository() {
    echo -e "${YELLOW}📥 Клонирование репозитория${NC}"
    
    ssh $APP_USER@$SERVER_IP "cd $APP_DIR && git clone $REPO_URL . || (git pull origin main && git checkout main)"
    
    echo -e "${GREEN}✅ Репозиторий клонирован${NC}"
}

# Функция для установки зависимостей
install_dependencies() {
    echo -e "${YELLOW}📦 Установка зависимостей${NC}"
    
    ssh $APP_USER@$SERVER_IP "cd $APP_DIR && npm install --production"
    
    echo -e "${GREEN}✅ Зависимости установлены${NC}"
}

# Функция для генерации Prisma клиента
generate_prisma_client() {
    echo -e "${YELLOW}🔧 Генерация Prisma клиента${NC}"
    
    ssh $APP_USER@$SERVER_IP "cd $APP_DIR && npm run db:generate"
    
    echo -e "${GREEN}✅ Prisma клиент сгенерирован${NC}"
}

# Функция для применения схемы базы данных
apply_database_schema() {
    echo -e "${YELLOW}🗄️ Применение схемы базы данных${NC}"
    
    ssh $APP_USER@$SERVER_IP "cd $APP_DIR && npm run db:push"
    
    echo -e "${GREEN}✅ Схема базы данных применена${NC}"
}

# Функция для сборки приложения
build_application() {
    echo -e "${YELLOW}🏗️ Сборка приложения${NC}"
    
    ssh $APP_USER@$SERVER_IP "cd $APP_DIR && npm run build"
    
    echo -e "${GREEN}✅ Приложение собрано${NC}"
}

# Функция для создания environment файла
create_environment() {
    echo -e "${YELLOW}🔑 Создание environment файла${NC}"
    
    ssh $APP_USER@$SERVER_IP "cat > $APP_DIR/.env << EOF
# Database
DATABASE_URL=\"file:\$APP_DIR/prisma/db/custom.db\"

# NextAuth.js
NEXTAUTH_URL=\"https://normaldance.ru\"
NEXTAUTH_SECRET=\"\$(openssl rand -base64 32)\"

# Node Environment
NODE_ENV=\"production\"

# WebSocket
SOCKET_PORT=3000

# Redis (если используется)
REDIS_URL=\"redis://localhost:6379\"

# Web3 (опционально)
WALLET_CONNECT_PROJECT_ID=\"\"

# Logging
LOG_LEVEL=\"info\"
EOF"
    
    echo -e "${GREEN}✅ Environment файл создан${NC}"
}

# Функция для создания systemd сервиса
create_systemd_service() {
    echo -e "${YELLOW}⚙️ Создание systemd сервиса${NC}"
    
    ssh $APP_USER@$SERVER_IP "cat > /etc/systemd/system/normaldance.service << EOF
[Unit]
Description=NormalDance Next.js Application
After=network.target
Wants=network.target

[Service]
Type=simple
User=$APP_USER
Group=$APP_USER
WorkingDirectory=$APP_DIR
Environment=NODE_ENV=production
Environment=PORT=3000
Environment=HOSTNAME=0.0.0.0
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=strict
ReadWritePaths=$APP_DIR

[Install]
WantedBy=multi-user.target
EOF"
    
    ssh $APP_USER@$SERVER_IP "systemctl daemon-reload"
    ssh $APP_USER@$SERVER_IP "systemctl enable normaldance"
    ssh $APP_USER@$SERVER_IP "systemctl start normaldance"
    
    echo -e "${GREEN}✅ Systemd сервис создан и запущен${NC}"
}

# Функция для проверки работы приложения
check_application() {
    echo -e "${YELLOW}🔍 Проверка работы приложения${NC}"
    
    # Проверка health check
    if curl -s -f "http://$SERVER_IP/health" > /dev/null; then
        echo -e "${GREEN}✅ Health check проходит${NC}"
    else
        echo -e "${RED}❌ Health check не проходит${NC}"
        return 1
    fi
    
    # Проверка статуса сервиса
    if ssh $APP_USER@$SERVER_IP "systemctl is-active --quiet normaldance"; then
        echo -e "${GREEN}✅ Сервис активен${NC}"
    else
        echo -e "${RED}❌ Сервис не активен${NC}"
        return 1
    fi
    
    # Проверка логов
    echo -e "${BLUE}📋 Последние логи сервиса:${NC}"
    ssh $APP_USER@$SERVER_IP "journalctl -u normaldance --no-pager -n 20"
}

# Функция для настройки SSL
setup_ssl() {
    echo -e "${YELLOW}🔒 Настройка SSL сертификата${NC}"
    
    ssh $APP_USER@$SERVER_IP "certbot --nginx -d normaldance.ru -d www.normaldance.ru --email admin@normaldance.ru --agree-tos --non-interactive"
    
    echo -e "${GREEN}✅ SSL сертификат настроен${NC}"
}

# Функция для проверки SSL
check_ssl() {
    echo -e "${YELLOW}🔒 Проверка SSL сертификата${NC}"
    
    if curl -s -f "https://$SERVER_IP/health" > /dev/null; then
        echo -e "${GREEN}✅ HTTPS работает${NC}"
    else
        echo -e "${RED}❌ HTTPS не работает${NC}"
        return 1
    fi
    
    # Проверка SSL сертификата
    if ssh $APP_USER@$SERVER_IP "certbot certificates | grep -q 'normaldance.ru'"; then
        echo -e "${GREEN}✅ SSL сертификат действителен${NC}"
    else
        echo -e "${RED}❌ SSL сертификат не найден${NC}"
        return 1
    fi
}

# Основной процесс
main() {
    echo -e "${GREEN}🚀 Запуск процесса развертывания Next.js приложения${NC}"
    echo -e "${GREEN}==================================================${NC}"
    echo ""
    
    get_server_ip
    test_connection
    create_backup
    clone_repository
    install_dependencies
    generate_prisma_client
    apply_database_schema
    build_application
    create_environment
    create_systemd_service
    check_application
    setup_ssl
    check_ssl
    
    echo -e "${GREEN}🎉 Развертывание завершено!${NC}"
    echo ""
    echo -e "${BLUE}📋 Информация о развертывании:${NC}"
    echo "IP адрес сервера: $SERVER_IP"
    echo "Директория приложения: $APP_DIR"
    echo "Пользователь: $APP_USER"
    echo "URL: https://normaldance.ru"
    echo ""
    echo -e "${YELLOW}🔧 Команды для управления:${NC}"
    echo "Просмотр логов: ssh $APP_USER@$SERVER_IP 'journalctl -u normaldance -f'"
    echo "Перезапуск сервиса: ssh $APP_USER@$SERVER_IP 'systemctl restart normaldance'"
    echo "Статус сервиса: ssh $APP_USER@$SERVER_IP 'systemctl status normaldance'"
    echo ""
    echo -e "${BLUE}📊 Мониторинг:${NC}"
    echo "Память: ssh $APP_USER@$SERVER_IP 'free -h'"
    echo "Нагрузка: ssh $APP_USER@$SERVER_IP 'htop'"
    echo "Диск: ssh $APP_USER@$SERVER_IP 'df -h'"
}

# Запуск основного процесса
main "$@"