#!/bin/bash
# Скрипт развертывания NORMALDANCE Enterprise на сервере через Git clone + systemd
# Для работы скрипта требуется: Ubuntu/Debian, Git, Node.js 20+, Nginx, systemd

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Конфигурация развертывания
REPO_URL="https://github.com/normaldance/NORMALDANCE-Enterprise.git"
APP_NAME="normaldance"
APP_USER="normaldance"
APP_DIR="/opt/$APP_NAME"
BACKUP_DIR="/var/backups/$APP_NAME"
NGINX_CONFIG="/etc/nginx/sites-available/$APP_NAME"
SYSTEMD_SERVICE="/etc/systemd/system/$APP_NAME.service"

# Переменные окружения (замените значения перед использованием)
DATABASE_URL="file:./db/custom.db"
NEXTAUTH_SECRET="your-super-secret-key-change-me"
NEXTAUTH_URL="https://your-domain.com"
NEXT_PUBLIC_SOLANA_RPC_URL="https://api.mainnet-beta.solana.com"
REDIS_URL="redis://localhost:6379"

# Функции для вывода сообщений
print_status() {
    echo -e "${BLUE}[ИНФО]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[УСПЕХ]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[ПРЕДУПРЕЖДЕНИЕ]${NC} $1"
}

print_error() {
    echo -e "${RED}[ОШИБКА]${NC} $1"
}

# Функция для логирования
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$APP_DIR/deployment.log"
}

# Проверка прав root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Этот скрипт должен быть запущен с правами root"
        exit 1
    fi
}

# Проверка зависимостей
check_dependencies() {
    print_status "Проверка зависимостей..."
    
    local missing_deps=()
    
    if ! command -v git &> /dev/null; then
        missing_deps+=("git")
    fi
    
    if ! command -v node &> /dev/null; then
        missing_deps+=("nodejs")
    fi
    
    if ! command -v npm &> /dev/null; then
        missing_deps+=("npm")
    fi
    
    if ! command -v nginx &> /dev/null; then
        missing_deps+=("nginx")
    fi
    
    if ! command -v systemctl &> /dev/null; then
        missing_deps+=("systemd")
    fi
    
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Отсутствуют следующие зависимости: ${missing_deps[*]}"
        print_status "Установка недостающих зависимостей..."
        apt update
        apt install -y "${missing_deps[@]}"
    fi
    
    print_success "Все зависимости установлены"
}

# Установка Node.js 20 (если не установлена)
install_nodejs() {
    if ! node --version | grep -q "v20"; then
        print_status "Установка Node.js 20..."
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        apt-get install -y nodejs
        print_success "Node.js 20 установлен"
    else
        print_success "Node.js 20 уже установлен"
    fi
}

# Создание пользователя и директорий
setup_user_and_directories() {
    print_status "Настройка пользователя и директорий..."
    
    # Создание пользователя
    if ! id "$APP_USER" &>/dev/null; then
        useradd -m -s /bin/bash "$APP_USER"
        print_success "Пользователь $APP_USER создан"
    else
        print_warning "Пользователь $APP_USER уже существует"
    fi
    
    # Создание директорий
    mkdir -p "$APP_DIR"
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$APP_DIR/logs"
    mkdir -p "$APP_DIR/uploads"
    mkdir -p "$APP_DIR/cache"
    mkdir -p "$APP_DIR/backups"
    
    # Установка прав
    chown -R "$APP_USER:$APP_USER" "$APP_DIR"
    chown -R "$APP_USER:$APP_USER" "$BACKUP_DIR"
    
    print_success "Директории созданы и настроены"
}

# Резервное копирование перед развертыванием
create_backup() {
    print_status "Создание резервной копии перед развертыванием..."
    
    if [ -d "$APP_DIR" ]; then
        local backup_name="$APP_NAME-backup-$(date +%Y%m%d_%H%M%S)"
        local backup_path="$BACKUP_DIR/$backup_name"
        
        # Создание бэкапа
        cp -r "$APP_DIR" "$backup_path"
        
        # Удаление старых бэкапов (оставляем последние 5)
        cd "$BACKUP_DIR"
        ls -t "$APP_NAME-backup-"* | tail -n +6 | xargs rm -rf
        
        print_success "Резервная копия создана: $backup_path"
        log_message "Создана резервная копия: $backup_path"
    else
        print_warning "Директория приложения не найдена, пропускаем бэкап"
    fi
}

# Клонирование репозитория
clone_repository() {
    print_status "Клонирование репозитория $REPO_URL..."
    
    # Удаление старого кода
    if [ -d "$APP_DIR" ]; then
        rm -rf "$APP_DIR"
    fi
    
    # Клонирование репозитория
    git clone "$REPO_URL" "$APP_DIR"
    
    if [ $? -eq 0 ]; then
        print_success "Репозиторий успешно клонирован"
        log_message "Репозиторий клонирован: $REPO_URL"
    else
        print_error "Не удалось клонировать репозиторий"
        exit 1
    fi
}

# Установка зависимостей
install_dependencies() {
    print_status "Установка Node.js зависимостей..."
    
    cd "$APP_DIR"
    
    # Установка зависимостей
    npm ci --production
    
    if [ $? -eq 0 ]; then
        print_success "Зависимости успешно установлены"
        log_message "Зависимости установлены"
    else
        print_error "Не удалось установить зависимости"
        exit 1
    fi
}

# Генерация Prisma клиента
generate_prisma_client() {
    print_status "Генерация Prisma клиента..."
    
    cd "$APP_DIR"
    
    # Генерация Prisma клиента
    npx prisma generate
    
    if [ $? -eq 0 ]; then
        print_success "Prisma клиент сгенерирован"
        log_message "Prisma клиент сгенерирован"
    else
        print_error "Не удалось сгенерировать Prisma клиент"
        exit 1
    fi
}

# Применение схемы базы данных
apply_database_schema() {
    print_status "Применение схемы базы данных..."
    
    cd "$APP_DIR"
    
    # Создание .env файла если его нет
    if [ ! -f "$APP_DIR/.env" ]; then
        create_env_file
    fi
    
    # Применение схемы
    npx prisma db push
    
    if [ $? -eq 0 ]; then
        print_success "Схема базы данных применена"
        log_message "Схема базы данных применена"
    else
        print_error "Не удалось применить схему базы данных"
        exit 1
    fi
}

# Создание .env файла
create_env_file() {
    print_status "Создание .env файла..."
    
    cat > "$APP_DIR/.env" << EOF
# Database
DATABASE_URL="$DATABASE_URL"

# NextAuth
NEXTAUTH_SECRET="$NEXTAUTH_SECRET"
NEXTAUTH_URL="$NEXTAUTH_URL"

# Solana Configuration
NEXT_PUBLIC_SOLANA_RPC_URL="$NEXT_PUBLIC_SOLANA_RPC_URL"
SOLANA_RPC_TIMEOUT="8000"

# Web3 Program IDs
NEXT_PUBLIC_NDT_PROGRAM_ID="NDT111111111111111111111111111111111111111"
NEXT_PUBLIC_NDT_MINT_ADDRESS="11111111111111111111111111111111"
NEXT_PUBLIC_TRACKNFT_PROGRAM_ID="TRACKNFT111111111111111111111111111111111111111"
NEXT_PUBLIC_STAKING_PROGRAM_ID="STAKING111111111111111111111111111111111111111"

# IPFS Configuration
NEXT_PUBLIC_IPFS_GATEWAY="https://ipfs.io"
PINATA_API_KEY=""
PINATA_SECRET_KEY=""

# Redis
REDIS_URL="$REDIS_URL"

# Sentry
SENTRY_DSN=""

# Environment
NODE_ENV="production"
NEXT_TELEMETRY_DISABLED="1"
EOF

    print_success ".env файл создан"
    log_message ".env файл создан"
}

# Сборка приложения для продакшена
build_application() {
    print_status "Сборка приложения для продакшена..."
    
    cd "$APP_DIR"
    
    # Сборка приложения
    npm run build
    
    if [ $? -eq 0 ]; then
        print_success "Приложение успешно собрано"
        log_message "Приложение собрано для продакшена"
    else
        print_error "Не удалось собрать приложение"
        exit 1
    fi
}

# Создание systemd сервиса
create_systemd_service() {
    print_status "Создание systemd сервиса..."
    
    cat > "$SYSTEMD_SERVICE" << EOF
[Unit]
Description= NORMALDANCE Enterprise
After=network.target

[Service]
Type=simple
User=$APP_USER
WorkingDirectory=$APP_DIR
Environment=NODE_ENV=production
Environment=PORT=3000
ExecStart=/usr/bin/npm start
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
ReadWritePaths=$APP_DIR/logs
ReadWritePaths=$APP_DIR/uploads
ReadWritePaths=$APP_DIR/cache

[Install]
WantedBy=multi-user.target
EOF

    # Перезагрузка systemd
    systemctl daemon-reload
    
    print_success "Systemd сервис создан"
    log_message "Systemd сервис создан"
}

# Настройка Nginx reverse proxy
setup_nginx() {
    print_status "Настройка Nginx reverse proxy..."
    
    cat > "$NGINX_CONFIG" << EOF
server {
    listen 80;
    server_name your-domain.com www.your-domain.com;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    # Gzip compression
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

    # Static files
    location /_next/static/ {
        alias $APP_DIR/.next/static/;
        expires 1y;
        access_log off;
        add_header Cache-Control "public, immutable";
    }

    # Static images
    location /_next/image {
        alias $APP_DIR/.next/image/;
        expires 1y;
        access_log off;
        add_header Cache-Control "public, immutable";
    }

    # API routes
    location /api/ {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_buffering off;
    }

    # Socket.IO
    location /api/socketio/ {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_buffering off;
    }

    # Main application
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

    # Health check
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}

# HTTPS redirect (для SSL)
server {
    listen 443 ssl http2;
    server_name your-domain.com www.your-domain.com;

    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;

    # Include SSL configuration
    include /etc/letsencrypt/options-ssl-nginx.conf;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;

    # Proxy configuration same as above
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
}
EOF

    # Включение сайта Nginx
    ln -sf "$NGINX_CONFIG" "/etc/nginx/sites-enabled/$APP_NAME"
    
    # Проверка конфигурации Nginx
    if nginx -t; then
        print_success "Nginx конфигурация корректна"
        systemctl restart nginx
        print_success "Nginx перезапущен"
    else
        print_error "Ошибка в конфигурации Nginx"
        exit 1
    fi
    
    log_message "Nginx настроен"
}

# Установка SSL сертификата (опционально)
setup_ssl() {
    print_status "Настройка SSL сертификата..."
    
    if [ ! -f "/etc/letsencrypt/live/your-domain.com/fullchain.pem" ]; then
        print_warning "SSL сертификат не найден. Установка Certbot..."
        
        apt install -y certbot python3-certbot-nginx
        
        print_warning "Пожалуйста, запустите: certbot --nginx -d your-domain.com"
        print_warning "После установки SSL обновите конфигурацию Nginx"
    else
        print_success "SSL сертификат уже установлен"
    fi
}

# Запуск приложения
start_application() {
    print_status "Запуск приложения..."
    
    # Запуск сервиса
    systemctl start "$APP_NAME"
    systemctl enable "$APP_NAME"
    
    if systemctl is-active --quiet "$APP_NAME"; then
        print_success "Приложение успешно запущено"
        log_message "Приложение запущено"
    else
        print_error "Не удалось запустить приложение"
        systemctl status "$APP_NAME"
        exit 1
    fi
}

# Проверка работы приложения
check_application() {
    print_status "Проверка работы приложения..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f http://localhost:3000/health > /dev/null 2>&1; then
            print_success "Приложение работает корректно"
            log_message "Приложение прошло проверку здоровья"
            return 0
        fi
        
        print_status "Попытка $attempt из $max_attempts... Ожидание..."
        sleep 5
        ((attempt++))
    done
    
    print_error "Приложение не прошло проверку здоровья"
    systemctl status "$APP_NAME"
    journalctl -u "$APP_NAME" --since "5 minutes ago"
    exit 1
}

# Отображение информации о развертывании
show_deployment_info() {
    print_success "🎉 Развертывание NORMALDANCE Enterprise завершено!"
    echo ""
    echo "📋 Информация о развертывании:"
    echo "   📁 Директория приложения: $APP_DIR"
    echo "   👤 Пользователь: $APP_USER"
    echo "   🔌 Порт: 3000"
    echo "   🌐 Nginx: 80/443"
    echo "   📊 Systemd сервис: $APP_NAME"
    echo ""
    echo "🔧 Полезные команды:"
    echo "   📊 Статус приложения: systemctl status $APP_NAME"
    echo "   📄 Логи приложения: journalctl -u $APP_NAME -f"
    echo "   🔄 Перезапуск приложения: systemctl restart $APP_NAME"
    echo "   🛑 Остановка приложения: systemctl stop $APP_NAME"
    echo "   📁 Лог развертывания: tail -f $APP_DIR/deployment.log"
    echo ""
    echo "🌐 Доступ к приложению:"
    echo "   🏠 Главная страница: http://localhost"
    echo "   🏥 Проверка здоровья: http://localhost/health"
    echo "   🔧 Админ панель: http://localhost/admin"
    echo ""
    echo "⚠️  Важно:"
    echo "   1. Замените 'your-domain.com' на ваш реальный домен"
    echo "   2. Настройте SSL сертификат: certbot --nginx -d your-domain.com"
    echo "   3. Обновите переменные окружения в .env файле"
    echo "   4. Проверьте работу WebSocket: ws://localhost/api/socketio"
}

# Основная функция
main() {
    echo "🚀 Начало развертывания NORMALDANCE Enterprise"
    echo "📅 Дата: $(date)"
    echo ""
    
    # Проверка прав root
    check_root
    
    # Проверка зависимостей
    check_dependencies
    
    # Установка Node.js
    install_nodejs
    
    # Настройка пользователя и директорий
    setup_user_and_directories
    
    # Резервное копирование
    create_backup
    
    # Клонирование репозитория
    clone_repository
    
    # Установка зависимостей
    install_dependencies
    
    # Генерация Prisma клиента
    generate_prisma_client
    
    # Применение схемы базы данных
    apply_database_schema
    
    # Сборка приложения
    build_application
    
    # Создание systemd сервиса
    create_systemd_service
    
    # Настройка Nginx
    setup_nginx
    
    # Установка SSL
    setup_ssl
    
    # Запуск приложения
    start_application
    
    # Проверка работы
    check_application
    
    # Отображение информации
    show_deployment_info
    
    log_message "Развертывание завершено успешно"
}

# Обработка ошибок
trap 'print_error "Произошла ошибка во время развертывания"; exit 1' ERR

# Запуск основной функции
main "$@"