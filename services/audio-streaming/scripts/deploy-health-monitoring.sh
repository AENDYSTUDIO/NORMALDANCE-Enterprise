#!/bin/bash

# Скрипт для деплоя системы мониторинга здоровья на удаленный сервер
# Использование: ./deploy-health-monitoring.sh [options]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$PROJECT_DIR/config"
SCRIPTS_DIR="$SCRIPT_DIR"
REMOTE_HOST=""
REMOTE_USER="root"
REMOTE_PORT="22"
SSH_KEY=""
VERBOSE=false
DRY_RUN=false
BACKUP_EXISTING=true
RESTART_SERVICES=true
FORCE_DEPLOY=false

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Парсинг аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        --host|-h)
            REMOTE_HOST="$2"
            shift 2
            ;;
        --user|-u)
            REMOTE_USER="$2"
            shift 2
            ;;
        --port|-p)
            REMOTE_PORT="$2"
            shift 2
            ;;
        --key|-k)
            SSH_KEY="$2"
            shift 2
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --dry-run|-n)
            DRY_RUN=true
            shift
            ;;
        --no-backup|-B)
            BACKUP_EXISTING=false
            shift
            ;;
        --no-restart|-R)
            RESTART_SERVICES=false
            shift
            ;;
        --force|-f)
            FORCE_DEPLOY=true
            shift
            ;;
        --help|--h)
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
Скрипт для деплоя системы мониторинга здоровья на удаленный сервер

Использование: $0 --host <hostname> [options]

Обязательные параметры:
    --host, -h        Адрес удаленного сервера

Опциональные параметры:
    --user, -u        Пользователь для подключения (по умолчанию: root)
    --port, -p        Порт SSH (по умолчанию: 22)
    --key, -k         Путь к приватному ключу SSH
    --verbose, -v     Подробный вывод
    --dry-run, -n     Показать что будет сделано без выполнения
    --no-backup, -B   Не создавать резервные копии
    --no-restart, -R  Не перезапускать сервисы
    --force, -f       Принудительный деплой без подтверждения
    --help, --h       Показать эту справку

Примеры:
    $0 --host 176.108.246.49
    $0 --host 176.108.246.49 --user aendy --key ~/.ssh/id_rsa
    $0 --host 176.108.246.49 --dry-run --verbose
EOF
}

# Проверка обязательных параметров
validate_args() {
    if [ -z "$REMOTE_HOST" ]; then
        error "Необходимо указать адрес удаленного сервера (--host)"
    fi
    
    if [ -n "$SSH_KEY" ] && [ ! -f "$SSH_KEY" ]; then
        error "Файл ключа SSH не найден: $SSH_KEY"
    fi
}

# Проверка подключения
test_connection() {
    info "Проверка подключения к $REMOTE_HOST..."
    
    local ssh_cmd="ssh"
    if [ -n "$SSH_KEY" ]; then
        ssh_cmd="$ssh_cmd -i $SSH_KEY"
    fi
    
    ssh_cmd="$ssh_cmd -p $REMOTE_PORT $REMOTE_USER@$REMOTE_HOST"
    
    if $ssh_cmd "echo 'Connection successful' > /dev/null 2>&1"; then
        success "Подключение установлено"
    else
        error "Не удалось подключиться к $REMOTE_HOST"
    fi
}

# Создание резервной копии
create_backup() {
    if [ "$BACKUP_EXISTING" = true ]; then
        info "Создание резервной копии..."
        
        local backup_dir="/opt/monitoring/backup/$(date +%Y%m%d_%H%M%S)"
        
        local ssh_cmd="ssh"
        if [ -n "$SSH_KEY" ]; then
            ssh_cmd="$ssh_cmd -i $SSH_KEY"
        fi
        
        ssh_cmd="$ssh_cmd -p $REMOTE_PORT $REMOTE_USER@$REMOTE_HOST"
        
        $ssh_cmd "mkdir -p $backup_dir" || true
        
        # Резервное копирование конфигурации
        $ssh_cmd "cp -r /etc/monitoring $backup_dir/ 2>/dev/null || true"
        $ssh_cmd "cp -r /opt/monitoring $backup_dir/ 2>/dev/null || true"
        $ssh_cmd "cp /etc/cron.d/monitoring-health $backup_dir/ 2>/dev/null || true"
        $ssh_cmd "cp /etc/systemd/system/monitoring-health.* $backup_dir/ 2>/dev/null || true"
        
        success "Резервная копия создана: $backup_dir"
    fi
}

# Копирование файлов
copy_files() {
    info "Копирование файлов на сервер..."
    
    local rsync_cmd="rsync -avz --progress"
    if [ -n "$SSH_KEY" ]; then
        rsync_cmd="$rsync_cmd -e \"ssh -i $SSH_KEY -p $REMOTE_PORT\""
    else
        rsync_cmd="$rsync_cmd -e \"ssh -p $REMOTE_PORT\""
    fi
    
    # Копирование скриптов
    $rsync_cmd "$SCRIPTS_DIR/health-check.sh" "$REMOTE_USER@$REMOTE_HOST:/tmp/health-check.sh"
    $rsync_cmd "$SCRIPTS_DIR/setup-health-monitoring.sh" "$REMOTE_USER@$REMOTE_HOST:/tmp/setup-health-monitoring.sh"
    
    # Копирование конфигурации
    $rsync_cmd "$CONFIG_DIR/health-check.json" "$REMOTE_USER@$REMOTE_HOST:/tmp/health-check.json"
    
    success "Файлы скопированы"
}

# Установка на сервере
install_on_server() {
    info "Установка на сервере..."
    
    local ssh_cmd="ssh"
    if [ -n "$SSH_KEY" ]; then
        ssh_cmd="$ssh_cmd -i $SSH_KEY"
    fi
    
    ssh_cmd="$ssh_cmd -p $REMOTE_PORT $REMOTE_USER@$REMOTE_HOST"
    
    # Перемещение файлов
    $ssh_cmd "sudo mkdir -p /opt/monitoring/scripts"
    $ssh_cmd "sudo mkdir -p /etc/monitoring"
    $ssh_cmd "sudo mv /tmp/health-check.sh /opt/monitoring/scripts/"
    $ssh_cmd "sudo mv /tmp/setup-health-monitoring.sh /opt/monitoring/scripts/"
    $ssh_cmd "sudo mv /tmp/health-check.json /etc/monitoring/"
    
    # Установка прав
    $ssh_cmd "sudo chmod +x /opt/monitoring/scripts/*.sh"
    $ssh_cmd "sudo chmod 644 /etc/monitoring/health-check.json"
    
    # Запуск установки
    $ssh_cmd "sudo /opt/monitoring/scripts/setup-health-monitoring.sh --verbose --cron --systemd"
    
    success "Установка на сервере завершена"
}

# Проверка статуса
check_status() {
    info "Проверка статуса..."
    
    local ssh_cmd="ssh"
    if [ -n "$SSH_KEY" ]; then
        ssh_cmd="$ssh_cmd -i $SSH_KEY"
    fi
    
    ssh_cmd="$ssh_cmd -p $REMOTE_PORT $REMOTE_USER@$REMOTE_HOST"
    
    # Проверка systemd
    $ssh_cmd "sudo systemctl status monitoring-health.timer --no-pager -l" || true
    
    # Проверка cron
    $ssh_cmd "sudo crontab -l | grep monitoring-health" || true
    
    # Проверка логов
    $ssh_cmd "sudo tail -n 10 /var/log/monitoring-health.log" || true
    
    success "Проверка статуса завершена"
}

# Тестирование после деплоя
test_deployment() {
    info "Тестирование после деплоя..."
    
    local ssh_cmd="ssh"
    if [ -n "$SSH_KEY" ]; then
        ssh_cmd="$ssh_cmd -i $SSH_KEY"
    fi
    
    ssh_cmd="$ssh_cmd -p $REMOTE_PORT $REMOTE_USER@$REMOTE_HOST"
    
    # Тестовый запуск
    $ssh_cmd "sudo /opt/monitoring/scripts/health-check.sh --config /etc/monitoring/health-check.json --verbose"
    
    success "Тестирование завершено"
}

# Откат изменений
rollback() {
    warning "Откат изменений..."
    
    local ssh_cmd="ssh"
    if [ -n "$SSH_KEY" ]; then
        ssh_cmd="$ssh_cmd -i $SSH_KEY"
    fi
    
    ssh_cmd="$ssh_cmd -p $REMOTE_PORT $REMOTE_USER@$REMOTE_HOST"
    
    # Остановка сервисов
    $ssh_cmd "sudo systemctl stop monitoring-health.timer 2>/dev/null || true"
    $ssh_cmd "sudo systemctl disable monitoring-health.timer 2>/dev/null || true"
    
    # Удаление cron
    $ssh_cmd "sudo rm -f /etc/cron.d/monitoring-health"
    
    # Восстановление из резервной копии
    local backup_dir=$($ssh_cmd "ls -t /opt/monitoring/backup/ | head -1")
    if [ -n "$backup_dir" ]; then
        $ssh_cmd "sudo cp -r /opt/monitoring/backup/$backup_dir/* / 2>/dev/null || true"
        success "Откат выполнен из резервной копии: $backup_dir"
    else
        warning "Резервная копия не найдена"
    fi
}

# Подтверждение деплоя
confirm_deployment() {
    if [ "$FORCE_DEPLOY" = false ]; then
        echo
        echo "=== Подтверждение деплоя ==="
        echo "Сервер: $REMOTE_HOST"
        echo "Пользователь: $REMOTE_USER"
        echo "Порт: $REMOTE_PORT"
        echo
        
        if [ "$DRY_RUN" = true ]; then
            echo "Режим dry-run - только показать что будет сделано"
        else
            echo "Будут выполнены следующие действия:"
            echo "1. Создание резервной копии (если включено)"
            echo "2. Копирование файлов на сервер"
            echo "3. Установка и настройка мониторинга"
            echo "4. Перезапуск сервисов"
            echo
            read -p "Продолжить? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                info "Деплой отменен"
                exit 0
            fi
        fi
    fi
}

# Основная функция деплоя
deploy() {
    info "Запуск деплоя системы мониторинга здоровья..."
    
    validate_args
    confirm_deployment
    
    if [ "$DRY_RUN" = true ]; then
        info "=== Режим dry-run ==="
        info "Будут выполнены следующие действия:"
        info "1. Проверка подключения к $REMOTE_HOST"
        info "2. Создание резервной копии"
        info "3. Копирование файлов"
        info "4. Установка на сервере"
        info "5. Проверка статуса"
        info "6. Тестирование"
        return 0
    fi
    
    test_connection
    create_backup
    copy_files
    install_on_server
    check_status
    test_deployment
    
    success "Деплой завершен успешно!"
    
    echo
    echo "=== Дальнейшие шаги ==="
    echo "1. Проверьте логи: ssh $REMOTE_USER@$REMOTE_HOST 'sudo tail -f /var/log/monitoring-health.log'"
    echo "2. Проверьте статус: ssh $REMOTE_USER@$REMOTE_HOST 'sudo systemctl status monitoring-health.timer'"
    echo "3. Настройте webhook для уведомлений"
    echo "4. Проверьте доступность сервисов"
}

# Обработка ошибок
trap 'error "Ошибка на строке $LINENO"' ERR

# Запуск деплоя
deploy "$@"