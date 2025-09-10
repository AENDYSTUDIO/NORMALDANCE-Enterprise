#!/bin/bash

# Скрипт деплоя audio-streaming стека
# Поддерживает деплой на разные окружения с полной автоматизацией

set -e

# Конфигурация
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_DIR/config/deploy-config.json"
ENV_FILE="$PROJECT_DIR/.env"
LOG_FILE="$PROJECT_DIR/logs/deploy.log"

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
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

error() {
    log "ERROR" "$@"
    exit 1
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

# Проверка наличия необходимых утилит
check_requirements() {
    log "INFO" "Проверка требований..."
    
    local required_tools=("docker" "docker-compose" "jq" "openssl")
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            error "Необходимый инструмент не найден: $tool"
        fi
    done
    
    # Проверка работы Docker
    if ! docker info &> /dev/null; then
        error "Docker не работает. Убедитесь, что Docker запущен"
    fi
    
    log "INFO" "Все требования удовлетворены"
}

# Проверка конфигурации
check_config() {
    log "INFO" "Проверка конфигурации..."
    
    if [ ! -f "$CONFIG_FILE" ]; then
        error "Конфигурационный файл не найден: $CONFIG_FILE"
    fi
    
    if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
        error "Невалидный JSON в конфигурационном файле: $CONFIG_FILE"
    fi
    
    log "INFO" "Конфигурация проверена"
}

# Проверка .env файла
check_env_file() {
    local env=$1
    
    if [ ! -f "$ENV_FILE" ]; then
        log "WARN" ".env файл не найден. Запускаем setup-environment.sh..."
        "$SCRIPT_DIR/setup-environment.sh" "$env"
    fi
    
    # Проверка переменных окружения
    source "$ENV_FILE"
    
    if [ -z "$NODE_ENV" ] || [ -z "$APP_DOMAIN" ]; then
        error "Недостаточно переменных в .env файле"
    fi
    
    log "INFO" ".env файл проверен"
}

# Бэкап перед деплоем
create_backup() {
    local env=$1
    
    log "INFO" "Создание бэкапа перед деплоем..."
    
    local backup_enabled=$(jq -r ".environments.$env.backup.enabled" "$CONFIG_FILE")
    
    if [ "$backup_enabled" = "true" ]; then
        "$SCRIPT_DIR/backup.sh" "$env" "pre-deploy"
        log "INFO" "Бэкап создан"
    else
        log "INFO" "Бэкап отключен для окружения: $env"
    fi
}

# Проверка состояния сервисов
check_service_health() {
    local service=$1
    local max_attempts=30
    local attempt=1
    
    log "INFO" "Проверка состояния сервиса: $service"
    
    while [ $attempt -le $max_attempts ]; do
        if docker-compose ps "$service" | grep -q "Up"; then
            log "INFO" "Сервис $service запущен"
            return 0
        fi
        
        log "DEBUG" "Ожидание запуска $service... попытка $attempt/$max_attempts"
        sleep 10
        ((attempt++))
    done
    
    error "Сервис $service не запустился за отведенное время"
}

# Проверка health endpoints
check_health_endpoints() {
    local env=$1
    
    log "INFO" "Проверка health endpoints..."
    
    local domain=$(jq -r ".environments.$env.domain" "$CONFIG_FILE")
    local api_port=$(jq -r ".environments.$env.services.api.port" "$CONFIG_FILE")
    local streaming_port=$(jq -r ".environments.$env.services.streaming.port" "$CONFIG_FILE")
    
    local endpoints=(
        "http://localhost:$api_port/health"
        "http://localhost:$streaming_port/health"
    )
    
    for endpoint in "${endpoints[@]}"; do
        local max_attempts=30
        local attempt=1
        
        while [ $attempt -le $max_attempts ]; do
            if curl -f -s "$endpoint" > /dev/null; then
                log "INFO" "Health endpoint доступен: $endpoint"
                break
            fi
            
            log "DEBUG" "Ожидание доступности $endpoint... попытка $attempt/$max_attempts"
            sleep 10
            ((attempt++))
        done
        
        if [ $attempt -gt $max_attempts ]; then
            error "Health endpoint недоступен: $endpoint"
        fi
    done
    
    log "INFO" "Все health endpoints проверены"
}

# Деплой сервисов
deploy_services() {
    local env=$1
    
    log "INFO" "Начало деплоя сервисов..."
    
    # Остановка текущих сервисов
    log "INFO" "Остановка текущих сервисов..."
    docker-compose down --remove-orphans
    
    # Очистка старых образов (опционально)
    local cleanup_images=$(jq -r ".environments.$env.cleanup_images // false" "$CONFIG_FILE")
    if [ "$cleanup_images" = "true" ]; then
        log "INFO" "Очистка старых Docker образов..."
        docker system prune -f
    fi
    
    # Пулл новых образов
    log "INFO" "Загрузка новых образов..."
    docker-compose pull
    
    # Запуск сервисов
    log "INFO" "Запуск сервисов..."
    docker-compose up -d
    
    # Ожидание запуска
    log "INFO" "Ожидание запуска сервисов..."
    sleep 30
    
    # Проверка состояния сервисов
    local services=("postgres" "redis" "api" "streaming" "nginx")
    
    for service in "${services[@]}"; do
        check_service_health "$service"
    done
    
    log "INFO" "Все сервисы запущены"
}

# Настройка SSL сертификатов
setup_ssl() {
    local env=$1
    
    local ssl_enabled=$(jq -r ".environments.$env.ssl.enabled" "$CONFIG_FILE")
    
    if [ "$ssl_enabled" = "true" ]; then
        log "INFO" "Настройка SSL сертификатов..."
        
        local domain=$(jq -r ".environments.$env.domain" "$CONFIG_FILE")
        local ssl_provider=$(jq -r ".environments.$env.ssl.provider" "$CONFIG_FILE")
        
        case "$ssl_provider" in
            "letsencrypt")
                setup_letsencrypt "$domain" "$env"
                ;;
            "self-signed")
                setup_self_signed "$domain"
                ;;
            "custom")
                log "INFO" "Использование пользовательских сертификатов"
                ;;
            *)
                error "Неизвестный SSL провайдер: $ssl_provider"
                ;;
        esac
    else
        log "INFO" "SSL отключен для окружения: $env"
    fi
}

# Настройка Let's Encrypt
setup_letsencrypt() {
    local domain=$1
    local env=$2
    
    log "INFO" "Настройка Let's Encrypt для домена: $domain"
    
    # Проверка наличия certbot
    if ! command -v certbot &> /dev/null; then
        log "WARN" "Certbot не найден. Установка..."
        sudo apt update && sudo apt install -y certbot
    fi
    
    # Проверка наличия nginx
    if ! docker-compose ps nginx | grep -q "Up"; then
        error "Nginx должен быть запущен для Let's Encrypt"
    fi
    
    # Получение сертификата
    local email=$(jq -r ".environments.$env.ssl.email" "$CONFIG_FILE")
    
    sudo certbot certonly --nginx \
        --non-interactive \
        --agree-tos \
        --email "$email" \
        -d "$domain"
    
    # Копирование сертификатов
    sudo cp "/etc/letsencrypt/live/$domain/fullchain.pem" "$PROJECT_DIR/config/ssl/$domain.crt"
    sudo cp "/etc/letsencrypt/live/$domain/privkey.pem" "$PROJECT_DIR/config/ssl/$domain.key"
    
    # Установка прав
    sudo chown $USER:$USER "$PROJECT_DIR/config/ssl"/*
    sudo chmod 600 "$PROJECT_DIR/config/ssl"/*
    
    # Перезапуск nginx
    docker-compose restart nginx
    
    log "INFO" "Let's Encrypt сертификаты настроены"
}

# Настройка самоподписанных сертификатов
setup_self_signed() {
    local domain=$1
    
    log "INFO" "Создание самоподписанных сертификатов для домена: $domain"
    
    local cert_path="$PROJECT_DIR/config/ssl/$domain.crt"
    local key_path="$PROJECT_DIR/config/ssl/$domain.key"
    
    if [ ! -f "$cert_path" ] || [ ! -f "$key_path" ]; then
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "$key_path" \
            -out "$cert_path" \
            -subj "/C=RU/ST=Moscow/L=Moscow/O=AudioStreaming/CN=$domain"
        
        log "INFO" "Самоподписанные сертификаты созданы"
    else
        log "INFO" "Самоподписанные сертификаты уже существуют"
    fi
}

# Настройка мониторинга
setup_monitoring() {
    local env=$1
    
    log "INFO" "Настройка мониторинга..."
    
    local monitoring_enabled=$(jq -r ".environments.$env.monitoring.enabled" "$CONFIG_FILE")
    
    if [ "$monitoring_enabled" = "true" ]; then
        "$SCRIPT_DIR/setup-monitoring.sh" "$env"
        log "INFO" "Мониторинг настроен"
    else
        log "INFO" "Мониторинг отключен для окружения: $env"
    fi
}

# Проверка после деплоя
post_deploy_check() {
    local env=$1
    
    log "INFO" "Проверка после деплоя..."
    
    # Проверка health endpoints
    check_health_endpoints "$env"
    
    # Проверка логов
    local log_errors=$(docker-compose logs --tail=100 | grep -i error | wc -l)
    if [ "$log_errors" -gt 0 ]; then
        log "WARN" "Найдено ошибок в логах: $log_errors"
        docker-compose logs --tail=50 | grep -i error
    fi
    
    # Проверка ресурсов
    local cpu_usage=$(docker stats --no-stream --format "table {{.CPUPerc}}" | tail -n +2 | awk '{sum+=$1} END {print sum}')
    local memory_usage=$(docker stats --no-stream --format "table {{.MemUsage}}" | tail -n +2 | awk '{sum+=$1} END {print sum}')
    
    log "INFO" "Использование ресурсов - CPU: ${cpu_usage}%, Memory: ${memory_usage}"
    
    log "INFO" "Проверка после деплоя завершена"
}

# Отправка уведомлений
send_notifications() {
    local env=$1
    local status=$2
    
    log "INFO" "Отправка уведомлений..."
    
    local webhook_url=$(jq -r ".environments.$env.notifications.webhook_url // empty" "$CONFIG_FILE")
    
    if [ -n "$webhook_url" ]; then
        local payload="{
            \"text\": \"Audio Streaming Service - Deployment $status\",
            \"environment\": \"$env\",
            \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
            \"domain\": \"$(jq -r ".environments.$env.domain" "$CONFIG_FILE")\"
        }"
        
        curl -X POST -H "Content-Type: application/json" \
            -d "$payload" "$webhook_url" || log "WARN" "Не удалось отправить уведомление"
    fi
    
    log "INFO" "Уведомления отправлены"
}

# Главная функция деплоя
deploy() {
    local env=${1:-production}
    local skip_backup=${2:-false}
    
    # Создание директории для логов
    mkdir -p "$(dirname "$LOG_FILE")"
    
    log "INFO" "Начало деплоя для окружения: $env"
    
    # Проверки
    check_requirements
    check_config
    check_env_file "$env"
    
    # Бэкап
    if [ "$skip_backup" != "true" ]; then
        create_backup "$env"
    fi
    
    # Деплой
    deploy_services "$env"
    
    # Настройка
    setup_ssl "$env"
    setup_monitoring "$env"
    
    # Проверка
    post_deploy_check "$env"
    
    # Уведомления
    send_notifications "$env" "success"
    
    success "Деплой завершен успешно для окружения: $env"
    
    # Вывод информации
    local domain=$(jq -r ".environments.$env.domain" "$CONFIG_FILE")
    local api_port=$(jq -r ".environments.$env.services.api.port" "$CONFIG_FILE")
    local streaming_port=$(jq -r ".environments.$env.services.streaming.port" "$CONFIG_FILE")
    
    info "Доступ к сервисам:"
    info "  API: https://$domain/api"
    info "  Streaming: https://$domain/stream"
    info "  Health: https://$domain/health"
    info "  Prometheus: https://$domain:9090"
    info "  Grafana: https://$domain:3001"
}

# Показать справку
show_help() {
    cat <<EOF
Скрипт деплоя audio-streaming стека

Использование: $0 [environment] [options]

Аргументы:
    environment    Окружение для деплоя (development, staging, production)
                   По умолчанию: production

Опции:
    --skip-backup  Пропустить создание бэкапа перед деплоем
    --help, -h     Показать эту справку

Примеры:
    $0 development
    $0 staging --skip-backup
    $0 production
    $0

EOF
}

# Обработка аргументов
SKIP_BACKUP=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-backup)
            SKIP_BACKUP=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        development|staging|production)
            ENVIRONMENT=$1
            shift
            ;;
        *)
            echo "Неизвестный аргумент: $1"
            show_help
            exit 1
            ;;
    esac
done

# Запуск
deploy "${ENVIRONMENT:-production}" "$SKIP_BACKUP"