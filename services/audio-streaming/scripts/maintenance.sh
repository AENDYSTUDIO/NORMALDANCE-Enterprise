#!/bin/bash

# Скрипт обслуживания для audio-streaming сервиса
# Включает очистку логов, обновление образов, перезапуск сервисов

set -e

# Конфигурация
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
MAINTENANCE_TYPE=${1:-full}
ENVIRONMENT=${2:-production}
FORCE=${3:-false}

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Логирование
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
            echo -e "${BLUE}[$timestamp] $message${NC}"
            ;;
        "MAINT")
            echo -e "${PURPLE}[$timestamp] $message${NC}"
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

maint() {
    log "MAINT" "$@"
}

# Показать справку
show_help() {
    cat <<EOF
Скрипт обслуживания для audio-streaming сервиса

Использование: $0 <maintenance_type> [environment] [force] [options]

Типы обслуживания:
    full        Полное обслуживание (очистка, обновление, перезапуск)
    cleanup     Очистка логов и временных файлов
    update      Обновление Docker образов
    restart     Перезапуск сервисов
    backup      Создание резервной копии перед обслуживанием
    health      Проверка здоровья после обслуживания

Параметры:
    environment Окружение для обслуживания (production, staging, development)
    force       Принудительное выполнение без подтверждения (true/false)

Опции:
    --help, -h  Показать эту справку

Примеры:
    $0 full                                    # Полное обслуживание
    $0 cleanup                                 # Только очистка
    $0 update production true                  # Обновление без подтверждения
    $0 --help                                  # Показать справку

EOF
}

# Подтверждение действия
confirm_action() {
    local action=$1
    
    if [ "$FORCE" == "true" ]; then
        return 0
    fi
    
    echo -e "${YELLOW}Вы уверены, что хотите выполнить: $action?${NC}"
    read -p "Введите 'yes' для подтверждения: " -r
    
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        info "Действие отменено пользователем"
        exit 0
    fi
}

# Создание резервной копии перед обслуживанием
create_backup() {
    maint "Создание резервной копии перед обслуживанием..."
    
    local backup_script="$SCRIPT_DIR/backup-monitoring.sh"
    if [ -f "$backup_script" ]; then
        "$backup_script" create "maintenance-backup"
        success "Резервная копия создана"
    else
        warning "Скрипт резервного копирования не найден"
    fi
}

# Очистка логов и временных файлов
cleanup_logs() {
    maint "Очистка логов и временных файлов..."
    
    # Очистка Docker логов
    docker system prune -f --volumes
    
    # Очистка логов контейнеров
    docker-compose logs --no-color > /dev/null 2>&1 || true
    
    # Очистка временных файлов
    find /tmp -name "audio-streaming-*" -type f -mtime +7 -delete 2>/dev/null || true
    
    # Очистка старых логов nginx
    if [ -d "nginx/logs" ]; then
        find nginx/logs -name "*.log" -type f -mtime +7 -exec truncate -s 0 {} \; 2>/dev/null || true
    fi
    
    success "Очистка завершена"
}

# Обновление Docker образов
update_images() {
    maint "Обновление Docker образов..."
    
    # Остановка сервисов
    docker-compose down
    
    # Обновление образов
    docker-compose pull
    
    # Перезапуск сервисов
    docker-compose up -d
    
    success "Обновление образов завершено"
}

# Перезапуск сервисов
restart_services() {
    maint "Перезапуск сервисов..."
    
    # Graceful restart
    docker-compose restart
    
    # Ожидание запуска
    sleep 10
    
    # Проверка статуса
    docker-compose ps
    
    success "Перезапуск завершен"
}

# Проверка здоровья после обслуживания
health_check() {
    maint "Проверка здоровья после обслуживания..."
    
    local health_script="$SCRIPT_DIR/health-check.sh"
    if [ -f "$health_script" ]; then
        "$health_script" local
        success "Проверка здоровья завершена"
    else
        warning "Скрипт проверки здоровья не найден"
    fi
}

# Удаленное обслуживание
remote_maintenance() {
    maint "Запуск удаленного обслуживания..."
    
    # Проверка SSH доступа
    if ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no aendy@176.108.246.49 "echo 'SSH connection successful'" &>/dev/null; then
        error "Не удалось подключиться по SSH к 176.108.246.49"
    fi
    
    # Создание резервной копии
    ssh aendy@176.108.246.49 << 'ENDSSH'
        cd /opt/audio-streaming
        ./scripts/maintenance.sh backup production true
ENDSSH
    
    # Выполнение обслуживания
    case "$MAINTENANCE_TYPE" in
        full)
            ssh aendy@176.108.246.49 << 'ENDSSH'
                cd /opt/audio-streaming
                ./scripts/maintenance.sh cleanup production true
                ./scripts/maintenance.sh update production true
                ./scripts/maintenance.sh restart production true
                ./scripts/maintenance.sh health production true
ENDSSH
            ;;
        cleanup)
            ssh aendy@176.108.246.49 << 'ENDSSH'
                cd /opt/audio-streaming
                ./scripts/maintenance.sh cleanup production true
ENDSSH
            ;;
        update)
            ssh aendy@176.108.246.49 << 'ENDSSH'
                cd /opt/audio-streaming
                ./scripts/maintenance.sh update production true
ENDSSH
            ;;
        restart)
            ssh aendy@176.108.246.49 << 'ENDSSH'
                cd /opt/audio-streaming
                ./scripts/maintenance.sh restart production true
ENDSSH
            ;;
    esac
    
    success "Удаленное обслуживание завершено"
}

# Локальное обслуживание
local_maintenance() {
    maint "Запуск локального обслуживания..."
    
    case "$MAINTENANCE_TYPE" in
        full)
            confirm_action "полное обслуживание"
            create_backup
            cleanup_logs
            update_images
            restart_services
            health_check
            ;;
        cleanup)
            confirm_action "очистку логов"
            cleanup_logs
            ;;
        update)
            confirm_action "обновление образов"
            update_images
            health_check
            ;;
        restart)
            confirm_action "перезапуск сервисов"
            restart_services
            health_check
            ;;
        backup)
            create_backup
            ;;
        health)
            health_check
            ;;
        *)
            error "Неизвестный тип обслуживания: $MAINTENANCE_TYPE"
            ;;
    esac
    
    success "Локальное обслуживание завершено"
}

# Главная функция
main() {
    info "Скрипт обслуживания"
    info "Тип: $MAINTENANCE_TYPE"
    info "Окружение: $ENVIRONMENT"
    
    # Проверка зависимостей
    if ! command -v docker &> /dev/null; then
        error "Docker не установлен"
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose не установлен"
    fi
    
    # Определение типа обслуживания
    case "$MAINTENANCE_TYPE" in
        local)
            local_maintenance
            ;;
        remote)
            remote_maintenance
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            # Проверка, если это локальное или удаленное обслуживание
            if [[ "$MAINTENANCE_TYPE" == "local"* ]] || [[ "$MAINTENANCE_TYPE" == "remote"* ]]; then
                local actual_type=$(echo "$MAINTENANCE_TYPE" | cut -d'-' -f2)
                if [[ "$MAINTENANCE_TYPE" == local* ]]; then
                    MAINTENANCE_TYPE="$actual_type"
                    local_maintenance
                else
                    MAINTENANCE_TYPE="$actual_type"
                    remote_maintenance
                fi
            else
                local_maintenance
            fi
            ;;
    esac
    
    success "Обслуживание успешно завершено!"
}

# Обработка аргументов
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    show_help
    exit 0
fi

# Запуск главной функции
main "$@"