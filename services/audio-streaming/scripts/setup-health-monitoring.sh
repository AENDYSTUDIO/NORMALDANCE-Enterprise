#!/bin/bash

# Скрипт для установки и настройки системы мониторинга здоровья
# Использование: ./setup-health-monitoring.sh [options]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$PROJECT_DIR/config"
HEALTH_CHECK_SCRIPT="$SCRIPT_DIR/health-check.sh"
CRON_FILE="/etc/cron.d/monitoring-health"
SYSTEMD_SERVICE="/etc/systemd/system/monitoring-health.service"
SYSTEMD_TIMER="/etc/systemd/system/monitoring-health.timer"
LOGROTATE_CONFIG="/etc/logrotate.d/monitoring-health"
VERBOSE=false
INSTALL_CRON=false
INSTALL_SYSTEMD=false
INSTALL_LOGROTATE=true
CREATE_USER=false
HEALTH_USER="monitoring"
HEALTH_GROUP="monitoring"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Парсинг аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --cron|-c)
            INSTALL_CRON=true
            shift
            ;;
        --systemd|-s)
            INSTALL_SYSTEMD=true
            shift
            ;;
        --user|-u)
            CREATE_USER=true
            HEALTH_USER="$2"
            shift 2
            ;;
        --group|-g)
            HEALTH_GROUP="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "Неизвестный аргумент: $1"
            exit 1
            ;;
    esac
done

log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")
            echo -e "${GREEN}[$timestamp] $message${NC}"
            ;;
        "WARN")
            echo -e "${YELLOW}[$timestamp] $message${NC}"
            ;;
        "ERROR")
            echo -e "${RED}[$timestamp] $message${NC}"
            ;;
        "DEBUG")
            if [ "$VERBOSE" = true ]; then
                echo -e "${BLUE}[$timestamp] $message${NC}"
            fi
            ;;
    esac
}

error() {
    log "ERROR" "$@"
    exit 1
}

warning() {
    log "WARN" "$@"
}

success() {
    log "INFO" "$@"
}

info() {
    log "INFO" "$@"
}

debug() {
    log "DEBUG" "$@"
}

# Показать справку
show_help() {
    cat <<EOF
Скрипт для установки и настройки системы мониторинга здоровья

Использование: $0 [options]

Параметры:
    --verbose, -v     Подробный вывод
    --cron, -c        Установить cron задачу
    --systemd, -s     Установить systemd сервис и таймер
    --user, -u        Создать пользователя для мониторинга
    --group, -g       Указать группу для пользователя
    --help, -h        Показать эту справку

Примеры:
    $0 --verbose --cron
    $0 --systemd --user monitoring
    $0 --cron --systemd
EOF
}

# Проверка прав root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error "Этот скрипт должен быть запущен с правами root"
    fi
}

# Проверка зависимостей
check_dependencies() {
    info "Проверка зависимостей..."
    
    local deps=("curl" "jq" "docker" "docker-compose" "openssl" "redis-cli")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" > /dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        warning "Отсутствуют зависимости: ${missing_deps[*]}"
        
        if command -v apt-get > /dev/null 2>&1; then
            info "Установка зависимостей через apt-get..."
            apt-get update
            apt-get install -y "${missing_deps[@]}"
        elif command -v yum > /dev/null 2>&1; then
            info "Установка зависимостей через yum..."
            yum install -y "${missing_deps[@]}"
        else
            error "Не удалось определить пакетный менеджер для установки зависимостей"
        fi
    fi
    
    success "Все зависимости установлены"
}

# Создание пользователя
create_user() {
    if [ "$CREATE_USER" = true ]; then
        info "Создание пользователя $HEALTH_USER..."
        
        if ! id "$HEALTH_USER" > /dev/null 2>&1; then
            useradd -r -s /bin/bash -d /opt/monitoring -g "$HEALTH_GROUP" "$HEALTH_USER"
            success "Пользователь $HEALTH_USER создан"
        else
            info "Пользователь $HEALTH_USER уже существует"
        fi
        
        # Создание группы если не существует
        if ! getent group "$HEALTH_GROUP" > /dev/null 2>&1; then
            groupadd "$HEALTH_GROUP"
            success "Группа $HEALTH_GROUP создана"
        fi
    fi
}

# Настройка прав
setup_permissions() {
    info "Настройка прав..."
    
    # Создание директорий
    mkdir -p /opt/monitoring
    mkdir -p /var/log/monitoring
    mkdir -p /etc/monitoring
    
    # Копирование конфигурации
    if [ -f "$CONFIG_DIR/health-check.json" ]; then
        cp "$CONFIG_DIR/health-check.json" /etc/monitoring/
        chmod 644 /etc/monitoring/health-check.json
    fi
    
    # Копирование скриптов
    cp "$HEALTH_CHECK_SCRIPT" /opt/monitoring/
    chmod +x /opt/monitoring/health-check.sh
    
    # Настройка прав
    if [ "$CREATE_USER" = true ]; then
        chown -R "$HEALTH_USER:$HEALTH_GROUP" /opt/monitoring
        chown -R "$HEALTH_USER:$HEALTH_GROUP" /var/log/monitoring
    fi
    
    success "Права настроены"
}

# Установка cron задачи
install_cron() {
    if [ "$INSTALL_CRON" = true ]; then
        info "Установка cron задачи..."
        
        cat > "$CRON_FILE" <<EOF
# Monitoring health check cron job
# Запуск каждые 5 минут
*/5 * * * * root /opt/monitoring/health-check.sh --config /etc/monitoring/health-check.json >> /var/log/monitoring/cron.log 2>&1

# Ежедневный отчет в 9:00
0 9 * * * root /opt/monitoring/health-check.sh --config /etc/monitoring/health-check.json --verbose >> /var/log/monitoring/daily-report.log 2>&1
EOF
        
        chmod 644 "$CRON_FILE"
        systemctl reload cron 2>/dev/null || systemctl reload crond 2>/dev/null || true
        
        success "Cron задача установлена"
    fi
}

# Установка systemd сервиса
install_systemd() {
    if [ "$INSTALL_SYSTEMD" = true ]; then
        info "Установка systemd сервиса..."
        
        # Сервис
        cat > "$SYSTEMD_SERVICE" <<EOF
[Unit]
Description=Monitoring Health Check Service
After=network.target docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/opt/monitoring/health-check.sh --config /etc/monitoring/health-check.json --verbose
User=root
Group=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
        
        # Таймер
        cat > "$SYSTEMD_TIMER" <<EOF
[Unit]
Description=Run monitoring health check every 5 minutes
Requires=monitoring-health.service

[Timer]
OnCalendar=*:0/5
Persistent=true
RandomizedDelaySec=30

[Install]
WantedBy=timers.target
EOF
        
        chmod 644 "$SYSTEMD_SERVICE" "$SYSTEMD_TIMER"
        
        # Перезагрузка systemd
        systemctl daemon-reload
        systemctl enable monitoring-health.timer
        systemctl start monitoring-health.timer
        
        success "Systemd сервис и таймер установлены"
    fi
}

# Настройка logrotate
setup_logrotate() {
    if [ "$INSTALL_LOGROTATE" = true ]; then
        info "Настройка logrotate..."
        
        cat > "$LOGROTATE_CONFIG" <<EOF
/var/log/monitoring/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 root root
    postrotate
        systemctl reload rsyslog > /dev/null 2>&1 || true
    endscript
}

/var/log/monitoring-health.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 root root
}
EOF
        
        chmod 644 "$LOGROTATE_CONFIG"
        success "Logrotate настроен"
    fi
}

# Настройка firewall
setup_firewall() {
    info "Настройка firewall..."
    
    # Проверка ufw
    if command -v ufw > /dev/null 2>&1; then
        ufw allow 9090/tcp comment "Prometheus"
        ufw allow 3000/tcp comment "Grafana"
        ufw allow 9093/tcp comment "Alertmanager"
        ufw allow 80/tcp comment "HTTP"
        ufw allow 443/tcp comment "HTTPS"
        success "UFW настроен"
    fi
    
    # Проверка firewalld
    if command -v firewall-cmd > /dev/null 2>&1; then
        firewall-cmd --permanent --add-port=9090/tcp
        firewall-cmd --permanent --add-port=3000/tcp
        firewall-cmd --permanent --add-port=9093/tcp
        firewall-cmd --permanent --add-port=80/tcp
        firewall-cmd --permanent --add-port=443/tcp
        firewall-cmd --reload
        success "Firewalld настроен"
    fi
}

# Настройка SELinux
setup_selinux() {
    if command -v getenforce > /dev/null 2>&1; then
        local selinux_status=$(getenforce)
        
        if [ "$selinux_status" != "Disabled" ]; then
            info "Настройка SELinux..."
            
            # Разрешение для портов
            if command -v semanage > /dev/null 2>&1; then
                semanage port -a -t http_port_t -p tcp 9090 2>/dev/null || true
                semanage port -a -t http_port_t -p tcp 3000 2>/dev/null || true
                semanage port -a -t http_port_t -p tcp 9093 2>/dev/null || true
            fi
            
            success "SELinux настроен"
        fi
    fi
}

# Создание systemd override
create_systemd_override() {
    if [ "$INSTALL_SYSTEMD" = true ]; then
        info "Создание systemd override..."
        
        local override_dir="/etc/systemd/system/monitoring-health.service.d"
        mkdir -p "$override_dir"
        
        cat > "$override_dir/override.conf" <<EOF
[Service]
# Дополнительные параметры
Environment="SLACK_WEBHOOK="
Environment="EMAIL_RECIPIENT=admin@dnb1st.ru"
Environment="HEALTH_CHECK_TIMEOUT=30"
EOF
        
        systemctl daemon-reload
        success "Systemd override создан"
    fi
}

# Тестирование установки
test_installation() {
    info "Тестирование установки..."
    
    # Проверка скрипта
    if [ -x "/opt/monitoring/health-check.sh" ]; then
        success "Скрипт health-check.sh установлен"
    else
        error "Скрипт health-check.sh не установлен"
    fi
    
    # Проверка конфигурации
    if [ -f "/etc/monitoring/health-check.json" ]; then
        success "Конфигурация установлена"
    else
        error "Конфигурация не установлена"
    fi
    
    # Тестовый запуск
    info "Запуск тестовой проверки..."
    /opt/monitoring/health-check.sh --config /etc/monitoring/health-check.json --verbose
    
    success "Тестирование завершено"
}

# Показать статус
show_status() {
    info "=== Статус системы мониторинга ==="
    
    if [ "$INSTALL_CRON" = true ]; then
        if [ -f "$CRON_FILE" ]; then
            success "Cron задача установлена"
        else
            warning "Cron задача не установлена"
        fi
    fi
    
    if [ "$INSTALL_SYSTEMD" = true ]; then
        systemctl status monitoring-health.timer --no-pager -l || warning "Systemd таймер не активен"
    fi
    
    if [ -f "$LOGROTATE_CONFIG" ]; then
        success "Logrotate настроен"
    fi
    
    if [ "$CREATE_USER" = true ]; then
        if id "$HEALTH_USER" > /dev/null 2>&1; then
            success "Пользователь $HEALTH_USER создан"
        fi
    fi
}

# Основная функция
main() {
    info "Запуск установки системы мониторинга здоровья..."
    
    check_root
    check_dependencies
    create_user
    setup_permissions
    install_cron
    install_systemd
    setup_logrotate
    setup_firewall
    setup_selinux
    create_systemd_override
    test_installation
    show_status
    
    success "Установка завершена успешно!"
    
    echo
    echo "=== Дальнейшие шаги ==="
    echo "1. Проверьте конфигурацию в /etc/monitoring/health-check.json"
    echo "2. Настройте webhook для уведомлений"
    echo "3. Проверьте логи в /var/log/monitoring/"
    echo "4. Настройте мониторинг через cron или systemd"
}

# Запуск скрипта
main "$@"