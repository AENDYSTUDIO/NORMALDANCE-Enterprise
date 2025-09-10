#!/bin/bash

# Скрипт для создания бэкапа мониторинговой системы
# Использование: ./backup-monitoring.sh [options]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR)"
BACKUP_DIR="/opt/backups/monitoring"
BACKUP_TYPE="full"
RETENTION_DAYS=30
COMPRESS=true
ENCRYPT=false
S3_BUCKET=""
REMOTE_DEST=""
NOTIFY_EMAIL=""
SLACK_WEBHOOK=""
EXCLUDE_DATA=false
EXCLUDE_IMAGES=false
EXCLUDE_CONFIG=false

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Парсинг аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        --type|-t)
            BACKUP_TYPE="$2"
            shift 2
            ;;
        --retention|-r)
            RETENTION_DAYS="$2"
            shift 2
            ;;
        --compress|-c)
            COMPRESS=true
            shift
            ;;
        --no-compress)
            COMPRESS=false
            shift
            ;;
        --encrypt|-e)
            ENCRYPT=true
            shift
            ;;
        --s3-bucket|-s)
            S3_BUCKET="$2"
            shift 2
            ;;
        --remote|-R)
            REMOTE_DEST="$2"
            shift 2
            ;;
        --email|-m)
            NOTIFY_EMAIL="$2"
            shift 2
            ;;
        --slack|-w)
            SLACK_WEBHOOK="$2"
            shift 2
            ;;
        --exclude-data)
            EXCLUDE_DATA=true
            shift
            ;;
        --exclude-images)
            EXCLUDE_IMAGES=true
            shift
            ;;
        --exclude-config)
            EXCLUDE_CONFIG=true
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
Скрипт для создания бэкапа мониторинговой системы

Использование: $0 [options]

Параметры:
    --type, -t        Тип бэкапа: full, config, data, images (по умолчанию: full)
    --retention, -r   Количество дней хранения бэкапов (по умолчанию: 30)
    --compress, -c    Сжатие бэкапа (по умолчанию: включено)
    --no-compress     Отключить сжатие
    --encrypt, -e     Шифрование бэкапа
    --s3-bucket, -s   S3 bucket для хранения бэкапов
    --remote, -R      Удаленный сервер для хранения (user@host:/path)
    --email, -m       Email для уведомлений
    --slack, -w       Slack webhook для уведомлений
    --exclude-data    Исключить данные Prometheus/Grafana
    --exclude-images  Исключить Docker образы
    --exclude-config  Исключить конфигурационные файлы
    --help, -h        Показать эту справку

Примеры:
    $0 --type config --s3-bucket my-backups
    $0 --type data --remote user@backup-server:/backups/monitoring
    $0 --encrypt --email admin@example.com
EOF
}

# Проверка зависимостей
check_dependencies() {
    local deps=("docker" "docker-compose" "tar" "gzip" "jq")
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
        error "AWS CLI требуется для S3 бэкапов"
        exit 1
    fi
}

# Создание директории для бэкапов
create_backup_dir() {
    local dir="$BACKUP_DIR/$BACKUP_TYPE"
    
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        log "Создана директория для бэкапов: $dir"
    fi
    
    echo "$dir"
}

# Генерация имени файла бэкапа
generate_backup_filename() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local filename="backup_${timestamp}"
    
    case "$BACKUP_TYPE" in
        "full")
            filename="${filename}_full"
            ;;
        "config")
            filename="${filename}_config"
            ;;
        "data")
            filename="${filename}_data"
            ;;
        "images")
            filename="${filename}_images"
            ;;
    esac
    
    if [ "$COMPRESS" = true ]; then
        filename="${filename}.tar.gz"
    else
        filename="${filename}.tar"
    fi
    
    echo "$filename"
}

# Создание метаданных бэкапа
create_metadata() {
    local backup_dir=$1
    local backup_file=$2
    
    local metadata_file="$backup_dir/metadata.json"
    
    cat > "$metadata_file" <<EOF
{
    "backup_type": "$BACKUP_TYPE",
    "date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "hostname": "$(hostname)",
    "backup_file": "$(basename "$backup_file")",
    "compressed": $COMPRESS,
    "encrypted": $ENCRYPT,
    "exclude_data": $EXCLUDE_DATA,
    "exclude_images": $EXCLUDE_IMAGES,
    "exclude_config": $EXCLUDE_CONFIG,
    "docker_images": $(docker images --format '{{json .}}' | jq -s '.'),
    "container_status": $(docker ps --format '{{json .}}' | jq -s '.'),
    "backup_size": $(stat -c%s "$backup_file" 2>/dev/null || echo 0)
}
EOF
    
    log "Созданы метаданные бэкапа"
}

# Бэкап конфигурации
backup_configuration() {
    local backup_dir=$1
    
    log "Создание бэкапа конфигурации..."
    
    # Prometheus конфигурация
    if [ -d "$PROJECT_DIR/prometheus" ]; then
        cp -r "$PROJECT_DIR/prometheus" "$backup_dir/"
    fi
    
    # Grafana конфигурация
    if [ -d "$PROJECT_DIR/grafana" ]; then
        cp -r "$PROJECT_DIR/grafana" "$backup_dir/"
    fi
    
    # Docker Compose
    if [ -f "$PROJECT_DIR/docker-compose.monitoring.yml" ]; then
        cp "$PROJECT_DIR/docker-compose.monitoring.yml" "$backup_dir/docker-compose.yml"
    fi
    
    # Environment файлы
    if [ -f "$PROJECT_DIR/.env" ]; then
        cp "$PROJECT_DIR/.env" "$backup_dir/"
    fi
    
    # Nginx конфигурация
    if [ -d "$PROJECT_DIR/nginx" ]; then
        cp -r "$PROJECT_DIR/nginx" "$backup_dir/"
    fi
    
    # Alertmanager конфигурация
    if [ -d "$PROJECT_DIR/alertmanager" ]; then
        cp -r "$PROJECT_DIR/alertmanager" "$backup_dir/"
    fi
}

# Бэкап данных
backup_data() {
    local backup_dir=$1
    
    log "Создание бэкапа данных..."
    
    # Prometheus данные
    local prometheus_volume=$(docker volume inspect monitoring_prometheus_data 2>/dev/null | jq -r '.[0].Mountpoint')
    if [ -n "$prometheus_volume" ] && [ "$prometheus_volume" != "null" ]; then
        mkdir -p "$backup_dir/prometheus_data"
        cp -r "$prometheus_volume"/* "$backup_dir/prometheus_data/" 2>/dev/null || true
    fi
    
    # Grafana данные
    local grafana_volume=$(docker volume inspect monitoring_grafana_data 2>/dev/null | jq -r '.[0].Mountpoint')
    if [ -n "$grafana_volume" ] && [ "$grafana_volume" != "null" ]; then
        mkdir -p "$backup_dir/grafana_data"
        cp -r "$grafana_volume"/* "$backup_dir/grafana_data/" 2>/dev/null || true
    fi
    
    # Redis данные
    local redis_volume=$(docker volume inspect monitoring_redis_data 2>/dev/null | jq -r '.[0].Mountpoint')
    if [ -n "$redis_volume" ] && [ "$redis_volume" != "null" ]; then
        mkdir -p "$backup_dir/redis_data"
        cp -r "$redis_volume"/* "$backup_dir/redis_data/" 2>/dev/null || true
    fi
}

# Бэкап Docker образов
backup_docker_images() {
    local backup_dir=$1
    
    log "Создание бэкапа Docker образов..."
    
    # Получение списка образов
    local images=$(docker images --format '{{.Repository}}:{{.Tag}}' | grep -E 'prometheus|grafana|alertmanager|redis|nginx')
    
    if [ -n "$images" ]; then
        docker save $images -o "$backup_dir/docker_images.tar"
        log "Сохранено $(echo "$images" | wc -l) Docker образов"
    else
        warning "Docker образы не найдены"
    fi
}

# Создание архива
create_archive() {
    local backup_dir=$1
    local backup_file=$2
    
    log "Создание архива..."
    
    local archive_name=$(basename "$backup_file" .tar.gz)
    archive_name=$(basename "$archive_name" .tar)
    
    cd "$backup_dir"
    
    if [ "$COMPRESS" = true ]; then
        tar -czf "$backup_file" --exclude="*.tar.gz" .
    else
        tar -cf "$backup_file" --exclude="*.tar" .
    fi
    
    log "Архив создан: $backup_file"
}

# Шифрование бэкапа
encrypt_backup() {
    local backup_file=$1
    
    if [ "$ENCRYPT" = false ]; then
        return
    fi
    
    log "Шифрование бэкапа..."
    
    read -s -p "Введите пароль для шифрования: " password
    echo
    
    openssl enc -aes-256-cbc -salt -in "$backup_file" -out "${backup_file}.enc" -k "$password"
    
    if [ $? -eq 0 ]; then
        rm "$backup_file"
        mv "${backup_file}.enc" "$backup_file"
        log "Бэкап зашифрован"
    else
        error "Ошибка шифрования"
        exit 1
    fi
}

# Отправка в S3
upload_to_s3() {
    local backup_file=$1
    
    if [ -z "$S3_BUCKET" ]; then
        return
    fi
    
    log "Отправка в S3..."
    
    aws s3 cp "$backup_file" "s3://$S3_BUCKET/monitoring/$(basename "$backup_file")"
    
    if [ $? -eq 0 ]; then
        log "Бэкап отправлен в S3"
    else
        error "Ошибка отправки в S3"
    fi
}

# Отправка на удаленный сервер
upload_to_remote() {
    local backup_file=$1
    
    if [ -z "$REMOTE_DEST" ]; then
        return
    fi
    
    log "Отправка на удаленный сервер..."
    
    if [[ "$REMOTE_DEST" == *"@"* ]]; then
        # SCP
        scp "$backup_file" "$REMOTE_DEST"
    else
        # Rsync
        rsync -avz "$backup_file" "$REMOTE_DEST"
    fi
    
    if [ $? -eq 0 ]; then
        log "Бэкап отправлен на удаленный сервер"
    else
        error "Ошибка отправки на удаленный сервер"
    fi
}

# Очистка старых бэкапов
cleanup_old_backups() {
    log "Очистка старых бэкапов..."
    
    find "$BACKUP_DIR" -name "backup_*.tar*" -type f -mtime +$RETENTION_DAYS -delete
    
    if [ -n "$S3_BUCKET" ]; then
        aws s3 ls "s3://$S3_BUCKET/monitoring/" | \
            awk '{print $4}' | \
            while read -r file; do
                local file_date=$(echo "$file" | grep -o '[0-9]\{8\}' | head -1)
                local file_age=$(( ($(date +%s) - $(date -d "$file_date" +%s)) / 86400 ))
                
                if [ $file_age -gt $RETENTION_DAYS ]; then
                    aws s3 rm "s3://$S3_BUCKET/monitoring/$file"
                fi
            done
    fi
    
    log "Очистка завершена"
}

# Отправка уведомлений
send_notifications() {
    local status=$1
    local message=$2
    local backup_file=$3
    
    local backup_size=$(stat -c%s "$backup_file" 2>/dev/null || echo 0)
    local backup_size_mb=$((backup_size / 1024 / 1024))
    
    # JSON payload
    local payload=$(cat <<EOF
{
    "text": "📊 Monitoring Backup $status",
    "attachments": [
        {
            "color": "$([ "$status" = "SUCCESS" ] && echo "good" || echo "danger")",
            "fields": [
                {
                    "title": "Status",
                    "value": "$status",
                    "short": true
                },
                {
                    "title": "Type",
                    "value": "$BACKUP_TYPE",
                    "short": true
                },
                {
                    "title": "Message",
                    "value": "$message",
                    "short": false
                },
                {
                    "title": "Size",
                    "value": "${backup_size_mb}MB",
                    "short": true
                },
                {
                    "title": "File",
                    "value": "$(basename "$backup_file")",
                    "short": true
                },
                {
                    "title": "Timestamp",
                    "value": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
                    "short": true
                }
            ]
        }
    ]
}
EOF
)
    
    # Отправка в Slack
    if [ -n "$SLACK_WEBHOOK" ]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "$payload" \
            "$SLACK_WEBHOOK" > /dev/null 2>&1 || true
    fi
    
    # Отправка email
    if [ -n "$NOTIFY_EMAIL" ]; then
        local subject="Monitoring Backup - $status"
        local body=$(cat <<EOF
Backup completed:
- Type: $BACKUP_TYPE
- Status: $status
- File: $(basename "$backup_file")
- Size: ${backup_size_mb}MB
- Timestamp: $(date)
- Message: $message
EOF
)
        
        echo "$body" | mail -s "$subject" "$NOTIFY_EMAIL" 2>/dev/null || true
    fi
}

# Основная функция создания бэкапа
create_backup() {
    local start_time=$(date +%s)
    
    log "Начало создания бэкапа..."
    
    # Проверка зависимостей
    check_dependencies
    
    # Создание директории
    local backup_dir=$(create_backup_dir)
    local backup_filename=$(generate_backup_filename)
    local backup_file="$backup_dir/$backup_filename"
    
    # Создание временной директории
    local temp_dir=$(mktemp -d)
    
    # Создание бэкапа в зависимости от типа
    case "$BACKUP_TYPE" in
        "config")
            backup_configuration "$temp_dir"
            ;;
        "data")
            backup_data "$temp_dir"
            ;;
        "images")
            backup_docker_images "$temp_dir"
            ;;
        "full")
            backup_configuration "$temp_dir"
            [ "$EXCLUDE_DATA" = false ] && backup_data "$temp_dir"
            [ "$EXCLUDE_IMAGES" = false ] && backup_docker_images "$temp_dir"
            ;;
        *)
            error "✗ Неизвестный тип бэкапа: $BACKUP_TYPE"
            exit 1
            ;;
    esac
    
    # Создание архива
    create_archive "$temp_dir" "$backup_file"
    
    # Шифрование
    encrypt_backup "$backup_file"
    
    # Создание метаданных
    create_metadata "$backup_dir" "$backup_file"
    
    # Отправка
    upload_to_s3 "$backup_file"
    upload_to_remote "$backup_file"
    
    # Очистка временной директории
    rm -rf "$temp_dir"
    
    # Очистка старых бэкапов
    cleanup_old_backups
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    success "Бэкап создан успешно: $backup_filename"
    log "Время выполнения: ${duration} секунд"
    
    # Отправка уведомлений
    send_notifications "SUCCESS" "Бэкап успешно создан" "$backup_file"
}

# Запуск
create_backup