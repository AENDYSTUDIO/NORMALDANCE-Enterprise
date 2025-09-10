#!/bin/bash

# Скрипт для восстановления мониторинговой системы из бэкапа
# Использование: ./restore-monitoring.sh [options]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="/opt/backups/monitoring"
RESTORE_TYPE="full"
BACKUP_FILE=""
DRY_RUN=false
FORCE=false
BACKUP_DATE=""
REMOTE_SOURCE=""
S3_BUCKET=""
ENCRYPTED=false

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Парсинг аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        --file|-f)
            BACKUP_FILE="$2"
            shift 2
            ;;
        --type|-t)
            RESTORE_TYPE="$2"
            shift 2
            ;;
        --date|-d)
            BACKUP_DATE="$2"
            shift 2
            ;;
        --remote|-R)
            REMOTE_SOURCE="$2"
            shift 2
            ;;
        --s3-bucket|-s)
            S3_BUCKET="$2"
            shift 2
            ;;
        --dry-run|-n)
            DRY_RUN=true
            shift
            ;;
        --force|-F)
            FORCE=true
            shift
            ;;
        --encrypted|-e)
            ENCRYPTED=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            error "Неизвестный аргумент: $1"
            exit 1
            ;;
    esac
done

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Показать справку
show_help() {
    cat <<EOF
Скрипт для восстановления мониторинговой системы из бэкапа

Использование: $0 [options]

Параметры:
    --file, -f        Путь к файлу бэкапа
    --type, -t        Тип восстановления: full, config, data, images (по умолчанию: full)
    --date, -d        Дата бэкапа для автоматического выбора (формат: YYYYMMDD)
    --remote, -R      Удаленный сервер для получения бэкапа (user@host:/path)
    --s3-bucket, -s   S3 bucket для получения бэкапа
    --dry-run, -n     Показать что будет восстановлено без фактического восстановления
    --force, -F       Принудительное восстановление без подтверждения
    --encrypted, -e   Бэкап зашифрован
    --help, -h        Показать эту справку

Примеры:
    $0 --date 20241201
    $0 --file /opt/backups/monitoring/full/backup_20241201_120000.tar.gz
    $0 --type config --remote user@backup-server:/backups/monitoring
EOF
}

# Проверка зависимостей
check_dependencies() {
    local deps=("docker" "docker-compose" "curl" "jq" "tar" "openssl")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        error "Отсутствуют зависимости: ${missing_deps[*]}"
        exit 1
    fi
    
    # Проверка AWS CLI для S3
    if [ -n "$S3_BUCKET" ] && ! command -v aws &> /dev/null; then
        error "AWS CLI требуется для S3 восстановления"
        exit 1
    fi
}

# Поиск бэкапа по дате
find_backup_by_date() {
    local date=$1
    
    if [ -z "$date" ]; then
        # Найти последний бэкап
        find "$BACKUP_DIR" -name "backup_*_${RESTORE_TYPE}.tar*" -type f | sort -r | head -1
    else
        # Найти бэкап за конкретную дату
        find "$BACKUP_DIR" -name "backup_${date}*_${RESTORE_TYPE}.tar*" -type f | sort -r | head -1
    fi
}

# Скачивание с удаленного сервера
download_from_remote() {
    local remote_path=$1
    
    log "Скачивание с удаленного сервера: $remote_path"
    
    local temp_file=$(mktemp)
    
    if [[ "$remote_path" == *"@"* ]]; then
        # SCP
        scp "$remote_path" "$temp_file"
    else
        # Rsync
        rsync -avz "$remote_path" "$temp_file"
    fi
    
    if [ $? -eq 0 ]; then
        log "Бэкап скачан успешно"
        echo "$temp_file"
    else
        error "Ошибка скачивания с удаленного сервера"
        exit 1
    fi
}

# Скачивание из S3
download_from_s3() {
    local bucket=$1
    local date=$2
    
    log "Скачивание из S3: $bucket"
    
    local temp_file=$(mktemp)
    
    if [ -z "$date" ]; then
        # Найти последний бэкап
        local latest_backup=$(aws s3 ls "s3://$bucket/monitoring/" | sort -r | head -1 | awk '{print $4}')
        aws s3 cp "s3://$bucket/monitoring/$latest_backup" "$temp_file"
    else
        # Найти бэкап за конкретную дату
        local backup_file=$(aws s3 ls "s3://$bucket/monitoring/" | grep "$date" | head -1 | awk '{print $4}')
        aws s3 cp "s3://$bucket/monitoring/$backup_file" "$temp_file"
    fi
    
    if [ $? -eq 0 ]; then
        log "Бэкап скачан из S3 успешно"
        echo "$temp_file"
    else
        error "Ошибка скачивания из S3"
        exit 1
    fi
}

# Расшифровка бэкапа
decrypt_backup() {
    local backup_file=$1
    
    if [ "$ENCRYPTED" = false ]; then
        echo "$backup_file"
        return
    fi
    
    log "Расшифровка бэкапа..."
    
    read -s -p "Введите пароль для расшифровки: " password
    echo
    
    local temp_file=$(mktemp)
    
    openssl enc -aes-256-cbc -d -in "$backup_file" -out "$temp_file" -k "$password"
    
    if [ $? -eq 0 ]; then
        log "Бэкап расшифрован успешно"
        echo "$temp_file"
    else
        error "Ошибка расшифровки"
        exit 1
    fi
}

# Распаковка бэкапа
extract_backup() {
    local backup_file=$1
    
    log "Распаковка бэкапа..."
    
    local temp_dir=$(mktemp -d)
    
    if [[ "$backup_file" == *.tar.gz ]]; then
        tar -xzf "$backup_file" -C "$temp_dir"
    elif [[ "$backup_file" == *.tar ]]; then
        tar -xf "$backup_file" -C "$temp_dir"
    else
        error "Неизвестный формат архива"
        exit 1
    fi
    
    if [ $? -eq 0 ]; then
        log "Бэкап распакован успешно"
        echo "$temp_dir"
    else
        error "Ошибка распаковки"
        exit 1
    fi
}

# Проверка метаданных
validate_backup() {
    local extracted_dir=$1
    
    log "Проверка метаданных бэкапа..."
    
    if [ -f "$extracted_dir/metadata.json" ]; then
        local backup_type=$(jq -r '.backup_type' "$extracted_dir/metadata.json")
        local backup_date=$(jq -r '.date' "$extracted_dir/metadata.json")
        
        log "Тип бэкапа: $backup_type"
        log "Дата создания: $backup_date"
        
        if [ "$backup_type" != "$RESTORE_TYPE" ] && [ "$RESTORE_TYPE" != "full" ]; then
            warning "Тип бэкапа ($backup_type) не совпадает с запрошенным ($RESTORE_TYPE)"
        fi
    else
        warning "Файл метаданных не найден"
    fi
}

# Подтверждение восстановления
confirm_restore() {
    if [ "$FORCE" = true ]; then
        return
    fi
    
    echo
    warning "⚠️  Внимание: Восстановление перезапишет текущие данные!"
    echo
    echo "Тип восстановления: $RESTORE_TYPE"
    echo "Проект: $PROJECT_DIR"
    echo
    
    read -p "Продолжить восстановление? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Восстановление отменено"
        exit 0
    fi
}

# Остановка сервисов
stop_services() {
    log "Остановка сервисов..."
    
    cd "$PROJECT_DIR"
    
    if [ -f "docker-compose.monitoring.yml" ]; then
        docker-compose -f docker-compose.monitoring.yml down
    else
        docker-compose down
    fi
    
    log "Сервисы остановлены"
}

# Запуск сервисов
start_services() {
    log "Запуск сервисов..."
    
    cd "$PROJECT_DIR"
    
    if [ -f "docker-compose.monitoring.yml" ]; then
        docker-compose -f docker-compose.monitoring.yml up -d
    else
        docker-compose up -d
    fi
    
    log "Сервисы запущены"
}

# Восстановление конфигурации
restore_configuration() {
    local extracted_dir=$1
    
    log "Восстановление конфигурации..."
    
    # Prometheus конфигурация
    if [ -d "$extracted_dir/prometheus" ]; then
        rm -rf "$PROJECT_DIR/prometheus"
        cp -r "$extracted_dir/prometheus" "$PROJECT_DIR/"
    fi
    
    # Grafana конфигурация
    if [ -d "$extracted_dir/grafana" ]; then
        rm -rf "$PROJECT_DIR/grafana"
        cp -r "$extracted_dir/grafana" "$PROJECT_DIR/"
    fi
    
    # Docker Compose
    if [ -f "$extracted_dir/docker-compose.yml" ]; then
        cp "$extracted_dir/docker-compose.yml" "$PROJECT_DIR/docker-compose.monitoring.yml"
    fi
    
    # Environment файлы
    if [ -f "$extracted_dir/.env" ]; then
        cp "$extracted_dir/.env" "$PROJECT_DIR/"
    fi
    
    # Nginx конфигурация
    if [ -d "$extracted_dir/nginx" ]; then
        rm -rf "$PROJECT_DIR/nginx"
        cp -r "$extracted_dir/nginx" "$PROJECT_DIR/"
    fi
    
    # Alertmanager конфигурация
    if [ -d "$extracted_dir/alertmanager" ]; then
        rm -rf "$PROJECT_DIR/alertmanager"
        cp -r "$extracted_dir/alertmanager" "$PROJECT_DIR/"
    fi
    
    log "Конфигурация восстановлена"
}

# Восстановление данных
restore_data() {
    local extracted_dir=$1
    
    log "Восстановление данных..."
    
    # Остановка контейнеров для восстановления данных
    local containers=("prometheus" "grafana" "redis")
    
    for container in "${containers[@]}"; do
        docker stop "monitoring_${container}_1" 2>/dev/null || true
    done
    
    # Prometheus данные
    if [ -d "$extracted_dir/prometheus_data" ]; then
        local prometheus_volume=$(docker volume inspect monitoring_prometheus_data 2>/dev/null | jq -r '.[0].Mountpoint')
        if [ -n "$prometheus_volume" ] && [ "$prometheus_volume" != "null" ]; then
            rm -rf "$prometheus_volume"/*
            cp -r "$extracted_dir/prometheus_data"/* "$prometheus_volume/"
        fi
    fi
    
    # Grafana данные
    if [ -d "$extracted_dir/grafana_data" ]; then
        local grafana_volume=$(docker volume inspect monitoring_grafana_data 2>/dev/null | jq -r '.[0].Mountpoint')
        if [ -n "$grafana_volume" ] && [ "$grafana_volume" != "null" ]; then
            rm -rf "$grafana_volume"/*
            cp -r "$extracted_dir/grafana_data"/* "$grafana_volume/"
        fi
    fi
    
    # Redis данные
    if [ -d "$extracted_dir/redis_data" ]; then
        local redis_volume=$(docker volume inspect monitoring_redis_data 2>/dev/null | jq -r '.[0].Mountpoint')
        if [ -n "$redis_volume" ] && [ "$redis_volume" != "null" ]; then
            rm -rf "$redis_volume"/*
            cp -r "$extracted_dir/redis_data"/* "$redis_volume/"
        fi
    fi
    
    log "Данные восстановлены"
}

# Восстановление Docker образов
restore_docker_images() {
    local extracted_dir=$1
    
    log "Восстановление Docker образов..."
    
    if [ -f "$extracted_dir/docker_images.tar" ]; then
        docker load -i "$extracted_dir/docker_images.tar"
        log "Docker образы восстановлены"
    else
        warning "Файл Docker образов не найден"
    fi
}

# Проверка восстановления
verify_restore() {
    log "Проверка восстановления..."
    
    # Ждем запуска сервисов
    sleep 10
    
    # Проверка контейнеров
    local containers=("prometheus" "grafana" "alertmanager" "redis")
    
    for container in "${containers[@]}"; do
        if docker ps | grep -q "monitoring_${container}_1"; then
            log "✓ Контейнер $container запущен"
        else
            warning "⚠ Контейнер $container не запущен"
        fi
    done
    
    # Проверка эндпоинтов
    local endpoints=(
        "http://localhost:9090/-/healthy"
        "http://localhost:3000/api/health"
        "http://localhost:9093/api/v1/status"
    )
    
    for endpoint in "${endpoints[@]}"; do
        if curl -s --max-time 10 "$endpoint" > /dev/null 2>&1; then
            log "✓ Эндпоинт доступен: $endpoint"
        else
            warning "⚠ Эндпоинт недоступен: $endpoint"
        fi
    done
    
    log "Проверка завершена"
}

# Основная функция восстановления
restore_monitoring() {
    local start_time=$(date +%s)
    
    log "Начало восстановления..."
    
    # Проверка зависимостей
    check_dependencies
    
    # Определение файла бэкапа
    local backup_file_to_use=""
    
    if [ -n "$REMOTE_SOURCE" ]; then
        backup_file_to_use=$(download_from_remote "$REMOTE_SOURCE")
    elif [ -n "$S3_BUCKET" ]; then
        backup_file_to_use=$(download_from_s3 "$S3_BUCKET" "$BACKUP_DATE")
    elif [ -n "$BACKUP_FILE" ]; then
        backup_file_to_use="$BACKUP_FILE"
    elif [ -n "$BACKUP_DATE" ]; then
        backup_file_to_use=$(find_backup_by_date "$BACKUP_DATE")
    else
        backup_file_to_use=$(find_backup_by_date "")
    fi
    
    if [ -z "$backup_file_to_use" ] || [ ! -f "$backup_file_to_use" ]; then
        error "✗ Файл бэкапа не найден"
        exit 1
    fi
    
    log "Используем бэкап: $backup_file_to_use"
    
    # Расшифровка если необходимо
    local decrypted_file=$(decrypt_backup "$backup_file_to_use")
    
    # Распаковка бэкапа
    local extracted_dir=$(extract_backup "$decrypted_file")
    
    # Проверка метаданных
    validate_backup "$extracted_dir"
    
    # Подтверждение восстановления
    confirm_restore
    
    if [ "$DRY_RUN" = true ]; then
        log "DRY RUN: Показано что будет восстановлено"
        return
    fi
    
    # Остановка сервисов
    stop_services
    
    # Восстановление в зависимости от типа
    case "$RESTORE_TYPE" in
        "config")
            restore_configuration "$extracted_dir"
            ;;
        "data")
            restore_data "$extracted_dir"
            ;;
        "images")
            restore_docker_images "$extracted_dir"
            ;;
        "full")
            restore_configuration "$extracted_dir"
            restore_data "$extracted_dir"
            restore_docker_images "$extracted_dir"
            ;;
        *)
            error "✗ Неизвестный тип восстановления: $RESTORE_TYPE"
            exit 1
            ;;
    esac
    
    # Запуск сервисов
    start_services
    
    # Проверка восстановления
    verify_restore
    
    # Очистка временных файлов
    if [[ "$decrypted_file" == /tmp/* ]]; then
        rm -f "$decrypted_file"
    fi
    
    if [[ "$extracted_dir" == /tmp/* ]]; then
        rm -rf "$extracted_dir"
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    success "Восстановление завершено успешно"
    log "Время выполнения: ${duration} секунд"
}

# Запуск
restore_monitoring