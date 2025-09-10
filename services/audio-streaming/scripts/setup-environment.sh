#!/bin/bash

# Скрипт настройки окружения для audio-streaming сервиса
# Автоматически создает .env файл и настраивает все необходимые параметры

set -e

# Конфигурация
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_DIR/.env"
CONFIG_FILE="$PROJECT_DIR/config/deploy-config.json"
BACKUP_DIR="$PROJECT_DIR/backups"

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

success() {
    log "INFO" "$@"
}

info() {
    log "INFO" "$@"
}

debug() {
    log "DEBUG" "$@"
}

# Проверка требований
check_requirements() {
    info "Проверка требований..."
    
    local required_tools=("openssl" "jq" "uuidgen")
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            error "Необходимый инструмент не найден: $tool"
        fi
    done
    
    info "Все требования удовлетворены"
}

# Генерация случайных паролей
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Генерация JWT секрета
generate_jwt_secret() {
    openssl rand -hex 64
}

# Генерация UUID
generate_uuid() {
    uuidgen
}

# Проверка существующего .env файла
check_existing_env() {
    if [ -f "$ENV_FILE" ]; then
        info "Найден существующий .env файл"
        read -p "Перезаписать существующий .env файл? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "Операция отменена"
            exit 0
        fi
        
        # Создание бэкапа
        local backup_file="${ENV_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$ENV_FILE" "$backup_file"
        info "Создан бэкап: $backup_file"
    fi
}

# Запрос параметров у пользователя
prompt_for_value() {
    local var_name=$1
    local default_value=$2
    local description=$3
    local is_password=$4
    
    local prompt_text="$description"
    if [ -n "$default_value" ]; then
        prompt_text="$prompt_text [$default_value]"
    fi
    prompt_text="$prompt_text: "
    
    local value
    if [ "$is_password" = "true" ]; then
        read -s -p "$prompt_text" value
        echo
    else
        read -p "$prompt_text" value
    fi
    
    if [ -z "$value" ]; then
        value="$default_value"
    fi
    
    echo "$value"
}

# Настройка базовых параметров
setup_basic_config() {
    local env=$1
    
    info "Настройка базовых параметров для окружения: $env"
    
    # Получение конфигурации из JSON
    local domain=$(jq -r ".environments.$env.domain" "$CONFIG_FILE")
    local api_port=$(jq -r ".environments.$env.services.api.port" "$CONFIG_FILE")
    local streaming_port=$(jq -r ".environments.$env.services.streaming.port" "$CONFIG_FILE")
    local postgres_port=$(jq -r ".environments.$env.services.postgres.port" "$CONFIG_FILE")
    local redis_port=$(jq -r ".environments.$env.services.redis.port" "$CONFIG_FILE")
    
    cat > "$ENV_FILE" << EOF
# Audio Streaming Service Environment Configuration
# Generated on $(date)
# Environment: $env

# Application Settings
NODE_ENV=$env
APP_DOMAIN=$domain
APP_PORT=3000

# Database Configuration
POSTGRES_DB=$(prompt_for_value "POSTGRES_DB" "audio_streaming" "PostgreSQL database name")
POSTGRES_USER=$(prompt_for_value "POSTGRES_USER" "postgres" "PostgreSQL username")
POSTGRES_PASSWORD=$(prompt_for_value "POSTGRES_PASSWORD" "$(generate_password)" "PostgreSQL password" true)
POSTGRES_HOST=postgres
POSTGRES_PORT=$postgres_port
DATABASE_URL=postgresql://\${POSTGRES_USER}:\${POSTGRES_PASSWORD}@\${POSTGRES_HOST}:\${POSTGRES_PORT}/\${POSTGRES_DB}

# Redis Configuration
REDIS_URL=redis://redis:$redis_port
REDIS_HOST=redis
REDIS_PORT=$redis_port
REDIS_PASSWORD=$(prompt_for_value "REDIS_PASSWORD" "$(generate_password)" "Redis password" true)

# API Configuration
API_PORT=$api_port
API_HOST=0.0.0.0
API_BASE_URL=https://$domain/api

# Streaming Configuration
STREAMING_PORT=$streaming_port
STREAMING_HOST=0.0.0.0
MAX_CONCURRENT_STREAMS=$(prompt_for_value "MAX_CONCURRENT_STREAMS" "100" "Maximum concurrent streams")
STREAM_QUALITY=$(prompt_for_value "STREAM_QUALITY" "high" "Default stream quality (low/medium/high)")
BUFFER_SIZE=$(prompt_for_value "BUFFER_SIZE" "8192" "Buffer size for streaming")

# Security Configuration
JWT_SECRET=$(prompt_for_value "JWT_SECRET" "$(generate_jwt_secret)" "JWT secret key" true)
JWT_EXPIRES_IN=$(prompt_for_value "JWT_EXPIRES_IN" "7d" "JWT expiration time")
BCRYPT_ROUNDS=$(prompt_for_value "BCRYPT_ROUNDS" "12" "Bcrypt rounds for password hashing")

# CORS Configuration
CORS_ORIGIN=$(prompt_for_value "CORS_ORIGIN" "https://$domain" "CORS allowed origins")
CORS_CREDENTIALS=$(prompt_for_value "CORS_CREDENTIALS" "true" "Allow credentials in CORS")

# Rate Limiting
RATE_LIMIT_WINDOW_MS=$(prompt_for_value "RATE_LIMIT_WINDOW_MS" "900000" "Rate limit window in milliseconds")
RATE_LIMIT_MAX_REQUESTS=$(prompt_for_value "RATE_LIMIT_MAX_REQUESTS" "100" "Maximum requests per window")

# Logging Configuration
LOG_LEVEL=$(prompt_for_value "LOG_LEVEL" "info" "Log level (error/warn/info/debug)")
LOG_FILE_PATH=/app/logs/app.log
LOG_MAX_SIZE=$(prompt_for_value "LOG_MAX_SIZE" "10m" "Maximum log file size")
LOG_MAX_FILES=$(prompt_for_value "LOG_MAX_FILES" "5" "Maximum number of log files")

# Monitoring Configuration
METRICS_ENABLED=$(prompt_for_value "METRICS_ENABLED" "true" "Enable metrics collection")
HEALTH_CHECK_TIMEOUT=$(prompt_for_value "HEALTH_CHECK_TIMEOUT" "5000" "Health check timeout in milliseconds")
PROMETHEUS_PORT=$(prompt_for_value "PROMETHEUS_PORT" "9090" "Prometheus port")
GRAFANA_PORT=$(prompt_for_value "GRAFANA_PORT" "3001" "Grafana port")
NODE_EXPORTER_PORT=$(prompt_for_value "NODE_EXPORTER_PORT" "9100" "Node exporter port")

# Grafana Configuration
GRAFANA_ADMIN_USER=$(prompt_for_value "GRAFANA_ADMIN_USER" "admin" "Grafana admin username")
GRAFANA_ADMIN_PASSWORD=$(prompt_for_value "GRAFANA_ADMIN_PASSWORD" "$(generate_password)" "Grafana admin password" true)
GRAFANA_ALLOW_SIGN_UP=$(prompt_for_value "GRAFANA_ALLOW_SIGN_UP" "false" "Allow user sign-up in Grafana")

# Docker Configuration
DOCKER_REGISTRY=$(prompt_for_value "DOCKER_REGISTRY" "ghcr.io" "Docker registry")
IMAGE_PREFIX=$(prompt_for_value "IMAGE_PREFIX" "dnb1st/audio-streaming" "Docker image prefix")
IMAGE_TAG=$(prompt_for_value "IMAGE_TAG" "latest" "Docker image tag")

# Watchtower Configuration
WATCHTOWER_CLEANUP=$(prompt_for_value "WATCHTOWER_CLEANUP" "true" "Clean up old images with Watchtower")
WATCHTOWER_POLL_INTERVAL=$(prompt_for_value "WATCHTOWER_POLL_INTERVAL" "300" "Watchtower poll interval in seconds")
WATCHTOWER_INCLUDE_STOPPED=$(prompt_for_value "WATCHTOWER_INCLUDE_STOPPED" "false" "Watchtower include stopped containers")
WATCHTOWER_REVIVE_STOPPED=$(prompt_for_value "WATCHTOWER_REVIVE_STOPPED" "true" "Watchtower revive stopped containers")
WATCHTOWER_ROLLING_RESTART=$(prompt_for_value "WATCHTOWER_ROLLING_RESTART" "true" "Watchtower rolling restart")

# SSL Configuration
SSL_ENABLED=$(prompt_for_value "SSL_ENABLED" "true" "Enable SSL")
SSL_CERT_PATH=/etc/ssl/certs
SSL_KEY_PATH=/etc/ssl/private

# Backup Configuration
BACKUP_ENABLED=$(prompt_for_value "BACKUP_ENABLED" "true" "Enable automatic backups")
BACKUP_SCHEDULE=$(prompt_for_value "BACKUP_SCHEDULE" "0 4 * * *" "Backup schedule in cron format")
BACKUP_RETENTION_DAYS=$(prompt_for_value "BACKUP_RETENTION_DAYS" "30" "Backup retention days")
BACKUP_S3_BUCKET=$(prompt_for_value "BACKUP_S3_BUCKET" "" "S3 bucket for backups (optional)")
BACKUP_S3_REGION=$(prompt_for_value "BACKUP_S3_REGION" "" "S3 region (optional)")
BACKUP_S3_ACCESS_KEY=$(prompt_for_value "BACKUP_S3_ACCESS_KEY" "" "S3 access key (optional)" true)
BACKUP_S3_SECRET_KEY=$(prompt_for_value "BACKUP_S3_SECRET_KEY" "" "S3 secret key (optional)" true)

# Email Configuration (for notifications)
SMTP_HOST=$(prompt_for_value "SMTP_HOST" "" "SMTP host (optional)")
SMTP_PORT=$(prompt_for_value "SMTP_PORT" "587" "SMTP port")
SMTP_USER=$(prompt_for_value "SMTP_USER" "" "SMTP username (optional)")
SMTP_PASSWORD=$(prompt_for_value "SMTP_PASSWORD" "" "SMTP password (optional)" true)
SMTP_FROM=$(prompt_for_value "SMTP_FROM" "" "SMTP from address (optional)")

# Slack Webhook (for notifications)
SLACK_WEBHOOK_URL=$(prompt_for_value "SLACK_WEBHOOK_URL" "" "Slack webhook URL (optional)" true)

# Application-specific Configuration
APP_NAME=$(prompt_for_value "APP_NAME" "Audio Streaming Service" "Application name")
APP_VERSION=$(prompt_for_value "APP_VERSION" "1.0.0" "Application version")
APP_DESCRIPTION=$(prompt_for_value "APP_DESCRIPTION" "High-performance audio streaming service" "Application description")

# Feature Flags
FEATURE_USER_REGISTRATION=$(prompt_for_value "FEATURE_USER_REGISTRATION" "true" "Enable user registration")
FEATURE_UPLOAD=$(prompt_for_value "FEATURE_UPLOAD" "true" "Enable audio upload")
FEATURE_DOWNLOAD=$(prompt_for_value "FEATURE_DOWNLOAD" "true" "Enable audio download")
FEATURE_PLAYLISTS=$(prompt_for_value "FEATURE_PLAYLISTS" "true" "Enable playlists")
FEATURE_FAVORITES=$(prompt_for_value "FEATURE_FAVORITES" "true" "Enable favorites")
EOF

    info "Базовая конфигурация создана"
}

# Настройка дополнительных параметров
setup_advanced_config() {
    info "Настройка дополнительных параметров..."
    
    # Добавление дополнительных параметров в конец файла
    cat >> "$ENV_FILE" << EOF

# Advanced Configuration
# These settings are for advanced users only

# Database Connection Pool
DATABASE_POOL_MIN=$(prompt_for_value "DATABASE_POOL_MIN" "2" "Minimum database connections")
DATABASE_POOL_MAX=$(prompt_for_value "DATABASE_POOL_MAX" "10" "Maximum database connections")
DATABASE_ACQUIRE_TIMEOUT=$(prompt_for_value "DATABASE_ACQUIRE_TIMEOUT" "60000" "Database connection acquire timeout")
DATABASE_IDLE_TIMEOUT=$(prompt_for_value "DATABASE_IDLE_TIMEOUT" "10000" "Database connection idle timeout")

# Redis Configuration
REDIS_POOL_MIN=$(prompt_for_value "REDIS_POOL_MIN" "1" "Minimum Redis connections")
REDIS_POOL_MAX=$(prompt_for_value "REDIS_POOL_MAX" "10" "Maximum Redis connections")
REDIS_RETRY_DELAY=$(prompt_for_value "REDIS_RETRY_DELAY" "100" "Redis retry delay in milliseconds")
REDIS_MAX_RETRIES=$(prompt_for_value "REDIS_MAX_RETRIES" "3" "Redis maximum retries")

# Streaming Configuration
STREAM_SEGMENT_DURATION=$(prompt_for_value "STREAM_SEGMENT_DURATION" "10" "Stream segment duration in seconds")
STREAM_MAX_BITRATE=$(prompt_for_value "STREAM_MAX_BITRATE" "320" "Maximum stream bitrate in kbps")
STREAM_MIN_BITRATE=$(prompt_for_value "STREAM_MIN_BITRATE" "64" "Minimum stream bitrate in kbps")
STREAM_DEFAULT_BITRATE=$(prompt_for_value "STREAM_DEFAULT_BITRATE" "128" "Default stream bitrate in kbps")

# Cache Configuration
CACHE_TTL=$(prompt_for_value "CACHE_TTL" "3600" "Cache TTL in seconds")
CACHE_MAX_SIZE=$(prompt_for_value "CACHE_MAX_SIZE" "100" "Maximum cache size in MB")
CACHE_CLEANUP_INTERVAL=$(prompt_for_value "CACHE_CLEANUP_INTERVAL" "300" "Cache cleanup interval in seconds")

# Security Configuration
SESSION_SECRET=$(prompt_for_value "SESSION_SECRET" "$(generate_jwt_secret)" "Session secret" true)
CSRF_SECRET=$(prompt_for_value "CSRF_SECRET" "$(generate_jwt_secret)" "CSRF secret" true)
ENCRYPTION_KEY=$(prompt_for_value "ENCRYPTION_KEY" "$(generate_jwt_secret)" "Encryption key" true)

# Performance Configuration
CLUSTER_WORKERS=$(prompt_for_value "CLUSTER_WORKERS" "auto" "Number of cluster workers (auto or number)")
MAX_MEMORY_USAGE=$(prompt_for_value "MAX_MEMORY_USAGE" "512" "Maximum memory usage in MB")
GC_INTERVAL=$(prompt_for_value "GC_INTERVAL" "60000" "Garbage collection interval in milliseconds")

# Monitoring Configuration
METRICS_INTERVAL=$(prompt_for_value "METRICS_INTERVAL" "15000" "Metrics collection interval in milliseconds")
HEALTH_CHECK_INTERVAL=$(prompt_for_value "HEALTH_CHECK_INTERVAL" "30000" "Health check interval in milliseconds")
ALERT_THRESHOLD_CPU=$(prompt_for_value "ALERT_THRESHOLD_CPU" "80" "CPU usage alert threshold (%)")
ALERT_THRESHOLD_MEMORY=$(prompt_for_value "ALERT_THRESHOLD_MEMORY" "85" "Memory usage alert threshold (%)")
ALERT_THRESHOLD_DISK=$(prompt_for_value "ALERT_THRESHOLD_DISK" "90" "Disk usage alert threshold (%)")
EOF

    info "Дополнительная конфигурация добавлена"
}

# Валидация конфигурации
validate_config() {
    info "Валидация конфигурации..."
    
    # Проверка наличия всех обязательных переменных
    local required_vars=(
        "NODE_ENV"
        "APP_DOMAIN"
        "POSTGRES_DB"
        "POSTGRES_USER"
        "POSTGRES_PASSWORD"
        "JWT_SECRET"
    )
    
    source "$ENV_FILE"
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            error "Обязательная переменная не установлена: $var"
        fi
    done
    
    info "Конфигурация валидирована"
}

# Создание директорий
create_directories() {
    info "Создание необходимых директорий..."
    
    local directories=(
        "logs/api"
        "logs/streaming"
        "logs/nginx"
        "config/nginx/sites-available"
        "config/nginx/sites-enabled"
        "config/ssl"
        "config/prometheus"
        "config/grafana/provisioning"
        "config/grafana/dashboards"
        "config/postgres"
        "media"
        "backups"
    )
    
    for dir in "${directories[@]}"; do
        mkdir -p "$PROJECT_DIR/$dir"
    done
    
    info "Директории созданы"
}

# Главная функция
setup_environment() {
    local env=${1:-production}
    
    info "Настройка окружения для: $env"
    
    # Проверки
    check_requirements
    check_existing_env
    
    # Создание директорий
    create_directories
    
    # Настройка конфигурации
    setup_basic_config "$env"
    
    # Запрос на расширенную настройку
    read -p "Настроить расширенные параметры? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        setup_advanced_config
    fi
    
    # Валидация
    validate_config
    
    # Установка прав
    chmod 600 "$ENV_FILE"
    
    success "Окружение настроено успешно"
    info "Файл конфигурации создан: $ENV_FILE"
    info "Не забудьте обновить конфигурацию nginx и SSL сертификаты"
}

# Показать справку
show_help() {
    cat <<EOF
Скрипт настройки окружения для audio-streaming сервиса

Использование: $0 [environment] [options]

Аргументы:
    environment    Окружение для настройки (development, staging, production)
                   По умолчанию: production

Опции:
    --help, -h     Показать эту справку

Примеры:
    $0 development
    $0 staging
    $0 production
    $0

EOF
}

# Обработка аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
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
setup_environment "${ENVIRONMENT:-production}"