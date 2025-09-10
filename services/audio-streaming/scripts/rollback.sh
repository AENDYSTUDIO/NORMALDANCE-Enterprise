#!/bin/bash

# Скрипт для отката деплоя audio-streaming сервиса
# Поддерживает локальный и удаленный откат

set -e

# Конфигурация
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ROLLBACK_TYPE=${1:-local}
BACKUP_DIR=${2:-""}
ENVIRONMENT=${3:-production}

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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
Скрипт отката деплоя для audio-streaming сервиса

Использование: $0 <rollback_type> [backup_dir] [environment] [options]

Типы отката:
    local       Локальный откат на текущей машине
    remote      Удаленный откат на сервере 176.108.246.49

Параметры:
    backup_dir  Директория с резервной копией (опционально)
    environment Окружение для отката (production, staging, development)

Опции:
    --help, -h  Показать эту справку

Примеры:
    $0 local                                    # Локальный откат к последней резервной копии
    $0 remote /opt/backups/20250904-120000      # Удаленный откат к указанной резервной копии
    $0 local "" staging                         # Локальный откат staging окружения
    $0 --help                                   # Показать справку

EOF
}

# Получить последнюю резервную копию
get_latest_backup() {
    local backup_path="/opt/backups"
    
    if [ "$ROLLBACK_TYPE" == "remote" ]; then
        ssh aendy@176.108.246.49 "ls -t $backup_path/pre-deployment-* | head -1"
    else
        ls -t "$backup_path"/pre-deployment-* 2>/dev/null | head -1
    fi
}

# Проверка наличия резервной копии
validate_backup() {
    local backup_dir=$1
    
    if [ -z "$backup_dir" ]; then
        info "Поиск последней резервной копии..."
        backup_dir=$(get_latest_backup)
        
        if [ -z "$backup_dir" ]; then
            error "Резервные копии не найдены"
        fi
    fi
    
    if [ "$ROLLBACK_TYPE" == "remote" ]; then
        if ! ssh aendy@176.108.246.49 "test -d $backup_dir"; then
            error "Резервная копия не найдена: $backup_dir"
        fi
    else
        if [ ! -d "$backup_dir" ]; then
            error "Резервная копия не найдена: $backup_dir"
        fi
    fi
    
    info "Используется резервная копия: $backup_dir"
    BACKUP_DIR="$backup_dir"
}

# Локальный откат
rollback_local() {
    info "Запуск локального отката..."
    
    validate_backup "$BACKUP_DIR"
    
    # Остановка текущих сервисов
    info "Остановка текущих сервисов..."
    docker-compose down
    
    # Восстановление из резервной копии
    info "Восстановление из резервной копии..."
    
    # Восстановление конфигурационных файлов
    if [ -f "$BACKUP_DIR/.env" ]; then
        cp "$BACKUP_DIR/.env" "$PROJECT_DIR/.env"
        info "Восстановлен .env файл"
    fi
    
    if [ -f "$BACKUP_DIR/docker-compose.yml" ]; then
        cp "$BACKUP_DIR/docker-compose.yml" "$PROJECT_DIR/docker-compose.yml"
        info "Восстановлен docker-compose.yml"
    fi
    
    # Восстановление данных
    if [ -d "$BACKUP_DIR/data" ]; then
        if [ -d "$PROJECT_DIR/data" ]; then
            rm -rf "$PROJECT_DIR/data"
        fi
        cp -r "$BACKUP_DIR/data" "$PROJECT_DIR/"
        info "Восстановлены данные"
    fi
    
    # Восстановление SSL сертификатов
    if [ -d "$BACKUP_DIR/ssl" ]; then
        if [ -d "$PROJECT_DIR/ssl" ]; then
            rm -rf "$PROJECT_DIR/ssl"
        fi
        cp -r "$BACKUP_DIR/ssl" "$PROJECT_DIR/"
        info "Восстановлены SSL сертификаты"
    fi
    
    # Перезапуск сервисов
    info "Перезапуск сервисов..."
    docker-compose up -d
    
    # Проверка статуса
    sleep 10
    docker-compose ps
    
    success "Локальный откат завершен"
}

# Удаленный откат
rollback_remote() {
    info "Запуск удаленного отката..."
    
    validate_backup "$BACKUP_DIR"
    
    ssh aendy@176.108.246.49 << ENDSSH
        set -e
        
        cd /opt/audio-streaming
        
        # Остановка текущих сервисов
        echo "Остановка текущих сервисов..."
        docker-compose down
        
        # Восстановление из резервной копии
        echo "Восстановление из резервной копии: $BACKUP_DIR"
        
        # Восстановление конфигурационных файлов
        if [ -f "$BACKUP_DIR/.env" ]; then
            cp "$BACKUP_DIR/.env" .env
            echo "Восстановлен .env файл"
        fi
        
        if [ -f "$BACKUP_DIR/docker-compose.yml" ]; then
            cp "$BACKUP_DIR/docker-compose.yml" docker-compose.yml
            echo "Восстановлен docker-compose.yml"
        fi
        
        # Восстановление данных
        if [ -d "$BACKUP_DIR/data" ]; then
            if [ -d "data" ]; then
                rm -rf data
            fi
            cp -r "$BACKUP_DIR/data" .
            echo "Восстановлены данные"
        fi
        
        # Восстановление SSL сертификатов
        if [ -d "$BACKUP_DIR/ssl" ]; then
            if [ -d "ssl" ]; then
                rm -rf ssl
            fi
            cp -r "$BACKUP_DIR/ssl" .
            echo "Восстановлены SSL сертификаты"
        fi
        
        # Восстановление конфигурации Nginx
        if [ -f "$BACKUP_DIR/nginx/dnb1st.ru" ]; then
            sudo cp "$BACKUP_DIR/nginx/dnb1st.ru" /etc/nginx/sites-available/
            sudo nginx -t
            echo "Восстановлена конфигурация Nginx"
        fi
        
        # Перезапуск сервисов
        echo "Перезапуск сервисов..."
        docker-compose up -d
        
        # Проверка статуса
        sleep 10
        docker-compose ps
        
        echo "Удаленный откат завершен"
ENDSSH
    
    success "Удаленный откат завершен"
}

# Создание точки восстановления перед откатом
create_rollback_point() {
    info "Создание точки восстановления перед откатом..."
    
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local rollback_point="/opt/backups/rollback-point-$timestamp"
    
    if [ "$ROLLBACK_TYPE" == "remote" ]; then
        ssh aendy@176.108.246.49 << ENDSSH
            mkdir -p $rollback_point
            cd /opt/audio-streaming
            
            # Сохранение текущего состояния
            cp .env $rollback_point/
            cp docker-compose.yml $rollback_point/
            cp -r ssl $rollback_point/ 2>/dev/null || true
            cp -r data $rollback_point/ 2>/dev/null || true
            
            echo "Точка восстановления создана: $rollback_point"
ENDSSH
    else
        mkdir -p "$rollback_point"
        
        # Сохранение текущего состояния
        cp "$PROJECT_DIR/.env" "$rollback_point/" 2>/dev/null || true
        cp "$PROJECT_DIR/docker-compose.yml" "$rollback_point/" 2>/dev/null || true
        cp -r "$PROJECT_DIR/ssl" "$rollback_point/" 2>/dev/null || true
        cp -r "$PROJECT_DIR/data" "$rollback_point/" 2>/dev/null || true
        
        info "Точка восстановления создана: $rollback_point"
    fi
}

# Проверка после отката
verify_rollback() {
    info "Проверка после отката..."
    
    local services=("http://localhost/health")
    
    if [ "$ROLLBACK_TYPE" == "remote" ]; then
        services=("http://176.108.246.49/health")
    fi
    
    for service in "${services[@]}"; do
        local max_attempts=10
        local attempt=1
        
        while [ $attempt -le $max_attempts ]; do
            if curl -s -o /dev/null -w "%{http_code}" "$service" | grep -q "200"; then
                success "Сервис доступен после отката: $service"
                break
            fi
            
            if [ $attempt -eq $max_attempts ]; then
                warning "Сервис недоступен после отката: $service"
            fi
            
            info "Ожидание... попытка $attempt/$max_attempts"
            sleep 10
            ((attempt++))
        done
    done
    
    success "Проверка отката завершена"
}

# Главная функция
main() {
    info "Скрипт отката деплоя"
    info "Тип: $ROLLBACK_TYPE"
    info "Окружение: $ENVIRONMENT"
    
    # Создание точки восстановления
    create_rollback_point
    
    # Выполнение отката
    case "$ROLLBACK_TYPE" in
        local)
            rollback_local
            ;;
        remote)
            rollback_remote
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            error "Неизвестный тип отката: $ROLLBACK_TYPE"
            ;;
    esac
    
    # Проверка после отката
    verify_rollback
    
    success "Откат успешно завершен!"
}

# Обработка аргументов
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    show_help
    exit 0
fi

# Запуск главной функции
main "$@"