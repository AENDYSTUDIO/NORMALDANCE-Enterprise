#!/bin/bash

# Скрипт для настройки SSL сертификата через Let's Encrypt для домена normaldance.ru
# Автор: Roo AI Assistant
# Дата создания: 2025-09-21
# Версия: 1.0

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Переменные конфигурации
DOMAIN="normaldance.ru"
WWW_DOMAIN="www.normaldance.ru"
EMAIL="admin@normaldance.ru"
NGINX_CONFIG_DIR="/etc/nginx"
NGINX_SITES_DIR="$NGINX_CONFIG_DIR/sites-available"
NGINX_SITES_ENABLED="$NGINX_CONFIG_DIR/sites-enabled"
BACKUP_DIR="/root/nginx-backups"
CERTBOT_DIR="/etc/letsencrypt"
SSL_LOG_DIR="/var/log/ssl"

# Функции для вывода сообщений
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Функция для проверки прав root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Этот скрипт должен быть запущен от имени root пользователя"
        log_info "Используйте: sudo ./setup-ssl-ruvds.sh"
        exit 1
    fi
}

# Функция проверки наличия необходимых пакетов
check_dependencies() {
    log_info "Проверка наличия необходимых пакетов..."
    
    # Проверка наличия curl
    if ! command -v curl &> /dev/null; then
        log_warning "curl не найден, устанавливаем..."
        apt-get update -qq
        apt-get install -y curl
    fi
    
    # Проверка наличия wget
    if ! command -v wget &> /dev/null; then
        log_warning "wget не найден, устанавливаем..."
        apt-get install -y wget
    fi
    
    log_success "Все необходимые пакеты установлены"
}

# Функция создания директорий
create_directories() {
    log_info "Создание необходимых директорий..."
    
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$SSL_LOG_DIR"
    mkdir -p "$CERTBOT_DIR/live/$DOMAIN"
    mkdir -p "$CERTBOT_DIR/renewal"
    
    log_success "Директории созданы успешно"
}

# Функция резервного копирования конфигурации Nginx
backup_nginx_config() {
    log_info "Создание резервной копии конфигурации Nginx..."
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/nginx_config_backup_$timestamp.tar.gz"
    
    # Создаем архив с текущей конфигурацией Nginx
    if tar -czf "$backup_file" "$NGINX_CONFIG_DIR" 2>/dev/null; then
        log_success "Резервная копия создана: $backup_file"
        # Сохраняем путь к последней резервной копии
        echo "$backup_file" > "$BACKUP_DIR/latest_backup.txt"
    else
        log_error "Не удалось создать резервную копию"
        return 1
    fi
}

# Функция обновления системы
update_system() {
    log_info "Обновление системы..."
    
    if apt-get update -qq && apt-get upgrade -y; then
        log_success "Система обновлена успешно"
    else
        log_error "Не удалось обновить систему"
        return 1
    fi
}

# Функция установки Certbot и плагина для Nginx
install_certbot() {
    log_info "Установка Certbot и плагина для Nginx..."
    
    # Добавляем репозиторий Certbot
    if ! apt list --installed | grep -q certbot; then
        log_info "Установка Certbot..."
        apt-get update -qq
        apt-get install -y certbot python3-certbot-nginx
        
        if command -v certbot &> /dev/null; then
            log_success "Certbot установлен успешно"
        else
            log_error "Не удалось установить Certbot"
            return 1
        fi
    else
        log_info "Certbot уже установлен"
    fi
}

# Функция проверки доступности домена
check_domain_availability() {
    log_info "Проверка доступности домена $DOMAIN..."
    
    if curl -s --head "http://$DOMAIN" &> /dev/null; then
        log_success "Домен $ доступен"
    else
        log_warning "Домен $DOMAIN недоступен. Проверьте DNS настройки."
        log_info "Убедитесь, что домен указывает на IP адрес этого сервера"
        return 1
    fi
}

# Функция получения SSL сертификата
get_ssl_certificate() {
    log_info "Получение SSL сертификата для $DOMAIN и $WWW_DOMAIN..."
    
    # Остановка Nginx для получения сертификата
    log_info "Остановка Nginx для получения сертификата..."
    systemctl stop nginx
    
    # Получение сертификата
    if certbot certonly --standalone \
        --email "$EMAIL" \
        --agree-tos \
        --no-eff-email \
        -d "$DOMAIN" \
        -d "$WWW_DOMAIN" \
        --preferred-challenges http; then
        
        log_success "SSL сертификат получен успешно"
        
        # Проверка наличия сертификата
        if [[ -f "$CERTBOT_DIR/live/$DOMAIN/fullchain.pem" && -f "$CERTBOT_DIR/live/$DOMAIN/privkey.pem" ]]; then
            log_success "Сертификат найден в директории: $CERTBOT_DIR/live/$DOMAIN/"
        else
            log_error "Сертификат не найден после получения"
            return 1
        fi
    else
        log_error "Не удалось получить SSL сертификат"
        systemctl start nginx
        return 1
    fi
    
    # Запуск Nginx
    log_info "Запуск Nginx..."
    systemctl start nginx
}

# Функция создания конфигурации Nginx для HTTPS
create_nginx_https_config() {
    log_info "Создание конфигурации Nginx для HTTPS..."
    
    local config_file="$NGINX_SITES_DIR/$DOMAIN"
    
    # Создаем конфигурацию с поддержкой IPv6
    cat > "$config_file" << 'EOF'
# Конфигурация для normaldance.ru с поддержкой SSL и IPv6

server {
    # Слушаем порт 80 (HTTP) и перенаправляем на HTTPS
    listen 80;
    listen [::]:80;
    server_name normaldance.ru www.normaldance.ru;
    
    # Перенаправление на HTTPS
    return 301 https://$host$request_uri;
}

server {
    # Слушаем порт 443 (HTTPS)
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name normaldance.ru www.normaldance.ru;
    
    # Пути к SSL сертификатам
    ssl_certificate /etc/letsencrypt/live/normaldance.ru/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/normaldance.ru/privkey.pem;
    
    # Настройка SSL
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;
    ssl_session_tickets off;
    
    # HSTS заголовки
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Referrer-Policy "strict-origin-when-cross-origin";
    
    # Корневая директория вашего сайта
    root /var/www/html;
    index index.html index.htm;
    
    # Логи
    access_log /var/log/nginx/normaldance.ru.access.log;
    error_log /var/log/nginx/normaldance.ru.error.log;
    
    # Основные настройки
    location / {
        try_files $uri $uri/ =404;
    }
    
    # Обработка ошибок
    error_page 404 /404.html;
    error_page 500 502 503 504 /50x.html;
    
    location = /50x.html {
        root /var/www/html;
    }
}
EOF

    # Создаем символическую ссылку в sites-enabled
    if [[ ! -f "$NGINX_SITES_ENABLED/$DOMAIN" ]]; then
        ln -sf "$config_file" "$NGINX_SITES_ENABLED/$DOMAIN"
        log_success "Конфигурация Nginx создана и активирована"
    else
        log_warning "Конфигурация уже существует"
    fi
}

# Функция проверки конфигурации Nginx
test_nginx_config() {
    log_info "Проверка конфигурации Nginx..."
    
    if nginx -t; then
        log_success "Конфигурация Nginx валидна"
    else
        log_error "Конфигурация Nginx содержит ошибки"
        return 1
    fi
}

# Функция перезапуска Nginx
restart_nginx() {
    log_info "Перезапуск Nginx..."
    
    if systemctl restart nginx; then
        log_success "Nginx перезапущен успешно"
    else
        log_error "Не удалось перезапустить Nginx"
        return 1
    fi
}

# Функция включения автоматического продления сертификата
enable_auto_renewal() {
    log_info "Настройка автоматического продления SSL сертификата..."
    
    # Создаем systemd таймер для автоматического продления
    cat > /etc/systemd/system/certbot-renew.timer << EOF
[Unit]
Description=Ежедневная проверка и продление SSL сертификатов
Documentation=man:certbot(1)

[Timer]
OnCalendar=daily
RandomizedDelaySec=43200
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # Создаем systemd сервис для продления
    cat > /etc/systemd/system/certbot-renew.service << EOF
[Unit]
Description=Продление SSL сертификатов
Documentation=man:certbot(1)

[Service]
Type=oneshot
ExecStart=/usr/bin/certbot renew --quiet --post-hook "systemctl reload nginx"
EOF

    # Включаем таймер
    systemctl daemon-reload
    systemctl enable certbot-renew.timer
    systemctl start certbot-renew.timer
    
    log_success "Автоматическое продление SSL сертификата настроено"
}

# Функция проверки срока действия сертификата
check_certificate_expiry() {
    log_info "Проверка срока действия SSL сертификата..."
    
    if [[ -f "$CERTBOT_DIR/live/$DOMAIN/cert.pem" ]]; then
        local expiry_date=$(openssl x509 -enddate -noout -in "$CERTBOT_DIR/live/$DOMAIN/cert.pem" | cut -d= -f2)
        local expiry_timestamp=$(date -d "$expiry_date" +%s)
        local current_timestamp=$(date +%s)
        local days_left=$(( (expiry_timestamp - current_timestamp) / 86400 ))
        
        log_info "Срок действия сертификата истекает: $expiry_date"
        log_info "Осталось дней до истечения: $days_left"
        
        if [[ $days_left -lt 30 ]]; then
            log_warning "Срок действия сертификата истекает менее чем через 30 дней!"
        else
            log_success "Срок действия сертификата в порядке"
        fi
    else
        log_error "Сертификат не найден"
        return 1
    fi
}

# Функция создания скрипта мониторинга сертификата
create_monitoring_script() {
    log_info "Создание скрипта мониторинга срока действия сертификата..."
    
    cat > /usr/local/bin/check-ssl-expiry.sh << 'EOF'
#!/bin/bash

# Скрипт для мониторинга срока действия SSL сертификата
DOMAIN="normaldance.ru"
CERT_DIR="/etc/letsencrypt/live/$DOMAIN"

if [[ -f "$CERT_DIR/cert.pem" ]]; then
    expiry_date=$(openssl x509 -enddate -noout -in "$CERT_DIR/cert.pem" | cut -d= -f2)
    expiry_timestamp=$(date -d "$expiry_date" +%s)
    current_timestamp=$(date +%s)
    days_left=$(( (expiry_timestamp - current_timestamp) / 86400 ))
    
    echo "SSL сертификат для $DOMAIN:"
    echo "Срок действия истекает: $expiry_date"
    echo "Осталось дней: $days_left"
    
    if [[ $days_left -lt 30 ]]; then
        echo "ПРЕДУПРЕЖДЕНИЕ: Срок действия сертификата истекает менее чем через 30 дней!"
        exit 1
    else
        echo "Срок действия сертификата в порядке"
        exit 0
    fi
else
    echo "ОШИБКА: Сертификат не найден"
    exit 1
fi
EOF

    chmod +x /usr/local/bin/check-ssl-expiry.sh
    
    # Добавляем в cron для ежедневной проверки
    if ! crontab -l 2>/dev/null | grep -q "check-ssl-expiry.sh"; then
        (crontab -l 2>/dev/null; echo "0 9 * * * /usr/local/bin/check-ssl-expiry.sh") | crontab -
        log_success "Скрипт мониторинга добавлен в cron"
    fi
}

# Функция проверки работы SSL
test_ssl_connection() {
    log_info "Проверка работы SSL соединения..."
    
    # Проверка HTTPS соединения
    if curl -k -s -o /dev/null -w "%{http_code}" "https://$DOMAIN" | grep -q "200\|301\|302"; then
        log_success "HTTPS соединение работает корректно"
    else
        log_error "HTTPS соединение не работает"
        return 1
    fi
    
    # Проверка перенаправления HTTP на HTTPS
    local http_status=$(curl -s -o /dev/null -w "%{http_code}" "http://$DOMAIN")
    if [[ "$http_status" == "301" || "$http_status" == "302" ]]; then
        log_success "HTTP успешно перенаправляется на HTTPS"
    else
        log_warning "HTTP перенаправление не работает корректно"
    fi
}

# Функция очистки
cleanup() {
    log_info "Очистка временных файлов..."
    
    # Удаляем временные файлы
    rm -f /tmp/certbot*.log
    rm -f /tmp/nginx*.log
    
    log_success "Очистка завершена"
}

# Функция основной установки
main() {
    log_info "Начало настройки SSL сертификата для $DOMAIN"
    log_info "================================================"
    
    # Проверяем права root
    check_root
    
    # Проверяем зависимости
    check_dependencies
    
    # Создаем необходимые директории
    create_directories
    
    # Создаем резервную копию конфигурации Nginx
    backup_nginx_config
    
    # Обновляем систему
    update_system
    
    # Устанавливаем Certbot
    install_certbot
    
    # Проверяем доступность домена
    check_domain_availability
    
    # Получаем SSL сертификат
    get_ssl_certificate
    
    # Создаем конфигурацию Nginx для HTTPS
    create_nginx_https_config
    
    # Проверяем конфигурацию Nginx
    test_nginx_config
    
    # Перезапускаем Nginx
    restart_nginx
    
    # Включаем автоматическое продление
    enable_auto_renewal
    
    # Проверяем срок действия сертификата
    check_certificate_expiry
    
    # Создаем скрипт мониторинга
    create_monitoring_script
    
    # Проверяем работу SSL
    test_ssl_connection
    
    # Очищаем временные файлы
    cleanup
    
    log_info "================================================"
    log_success "Настройка SSL сертификата завершена успешно!"
    log_info "Сертификат установлен для доменов: $DOMAIN и $WWW_DOMAIN"
    log_info "Автоматическое продление настроено"
    log_info "Мониторинг срока действия настроен"
    
    # Выводим информацию о сертификате
    log_info "Информация о сертификате:"
    openssl x509 -in "$CERTBOT_DIR/live/$DOMAIN/cert.pem" -text -noout | grep -E "(Subject:|Issuer:|DNS:|Not Before|Not After)"
}

# Функция справки
show_help() {
    echo "Использование: sudo ./setup-ssl-ruvds.sh [опции]"
    echo ""
    echo "Опции:"
    echo "  --help              Показать эту справку"
    echo "  --check             Проверить текущий статус SSL сертификата"
    echo "  --renew             Продлить SSL сертификат"
    echo "  --monitor           Запустить проверку срока действия"
    echo ""
    echo "Примеры:"
    echo "  sudo ./setup-ssl-ruvds.sh              # Полная установка"
    echo "  sudo ./setup-ssl-ruvds.sh --check     # Проверить статус"
    echo "  sudo ./setup-ssl-ruvds.sh --renew     # Продлить сертификат"
    echo "  sudo ./setup-ssl-ruvds.sh --monitor   # Проверить срок действия"
}

# Функция проверки статуса
check_status() {
    log_info "Проверка статуса SSL сертификата..."
    
    if [[ -f "$CERTBOT_DIR/live/$DOMAIN/cert.pem" ]]; then
        log_success "SSL сертификат найден"
        check_certificate_expiry
        test_ssl_connection
    else
        log_error "SSL сертификат не найден"
        return 1
    fi
}

# Функция продления сертификата
renew_certificate() {
    log_info "Продление SSL сертификата..."
    
    if certbot renew --quiet --post-hook "systemctl reload nginx"; then
        log_success "Сертификат успешно продлен"
        check_certificate_expiry
    else
        log_error "Не удалось продлить сертификат"
        return 1
    fi
}

# Функция мониторинга
monitor_certificate() {
    log_info "Мониторинг срока действия SSL сертификата..."
    /usr/local/bin/check-ssl-expiry.sh
}

# Обработка аргументов командной строки
case "${1:-}" in
    --help)
        show_help
        exit 0
        ;;
    --check)
        check_status
        exit 0
        ;;
    --renew)
        renew_certificate
        exit 0
        ;;
    --monitor)
        monitor_certificate
        exit 0
        ;;
    "")
        main
        ;;
    *)
        log_error "Неизвестный аргумент: $1"
        show_help
        exit 1
        ;;
esac