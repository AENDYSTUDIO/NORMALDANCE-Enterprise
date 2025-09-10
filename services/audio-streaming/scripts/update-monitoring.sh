#!/bin/bash

# Скрипт для обновления мониторинговой системы
# Использование: ./update-monitoring.sh [--force] [--rollback]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR)"
FORCE_UPDATE=false
ROLLBACK=false
BACKUP_BEFORE_UPDATE=true

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Парсинг аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        --force|-f)
            FORCE_UPDATE=true
            shift
            ;;
        --rollback|-r)
            ROLLBACK=true
            shift
            ;;
        --no-backup)
            BACKUP_BEFORE_UPDATE=false
            shift
            ;;
        *)
            echo "Неизвестный аргумент: $1"
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

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Проверка зависимостей
check_dependencies() {
    log "Проверка зависимостей..."
    
    local deps=("docker" "docker-compose" "git" "curl" "jq")
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
    
    log "Все зависимости установлены"
}

# Создание бэкапа перед обновлением
create_backup() {
    if [ "$BACKUP_BEFORE_UPDATE" = true ]; then
        log "Создание бэкапа перед обновлением..."
        "$SCRIPT_DIR/backup-monitoring.sh" full
    fi
}

# Проверка обновлений
check_for_updates() {
    log "Проверка обновлений..."
    
    cd "$PROJECT_DIR"
    
    # Проверка обновлений Docker образов
    local images=(
        "prom/prometheus:latest"
        "grafana/grafana:latest"
        "prom/node-exporter:latest"
        "prometheus/nginx-exporter:latest"
        "prometheus/redis-exporter:latest"
        "google/cadvisor:latest"
        "prom/alertmanager:latest"
    )
    
    for image in "${images[@]}"; do
        local current_digest=$(docker images --digests "$image" --format "{{.Digest}}" | head -1)
        local latest_digest=$(docker pull "$image" 2>/dev/null | grep "Digest:" | awk '{print $2}' || echo "")
        
        if [ -n "$latest_digest" ] && [ "$current_digest" != "$latest_digest" ]; then
            info "Доступно обновление для $image"
            info "Текущий: $current_digest"
            info "Новый: $latest_digest"
        fi
    done
}

# Обновление Docker образов
update_images() {
    log "Обновление Docker образов..."
    
    cd "$PROJECT_DIR"
    
    # Pull новых образов
    docker-compose -f docker-compose.monitoring.yml pull
    
    # Пересоздание контейнеров с новыми образами
    docker-compose -f docker-compose.monitoring.yml up -d --force-recreate
    
    log "Docker образы обновлены"
}

# Обновление конфигурации
update_configuration() {
    log "Обновление конфигурации..."
    
    cd "$PROJECT_DIR"
    
    # Проверка изменений в конфигурации
    local config_files=(
        "prometheus/prometheus.yml"
        "prometheus/rules/audio-streaming.yml"
        "grafana/provisioning/datasources/prometheus.yml"
        "grafana/provisioning/dashboards/dashboard.yml"
        "grafana/dashboards/audio-streaming.json"
        "docker-compose.monitoring.yml"
    )
    
    local has_changes=false
    
    for file in "${config_files[@]}"; do
        if [ -f "$file" ]; then
            # Проверка синтаксиса Prometheus конфигурации
            if [[ "$file" == *"prometheus.yml" ]]; then
                if ! docker run --rm -v "$PROJECT_DIR/prometheus:/prometheus" prom/prometheus:latest check config /prometheus/prometheus.yml; then
                    error "Ошибка в конфигурации Prometheus: $file"
                    if [ "$FORCE_UPDATE" != true ]; then
                        exit 1
                    fi
                fi
            fi
            
            # Проверка синтаксиса Grafana дашбордов
            if [[ "$file" == *".json" ]]; then
                if ! jq empty "$file" 2>/dev/null; then
                    error "Ошибка в JSON файле: $file"
                    if [ "$FORCE_UPDATE" != true ]; then
                        exit 1
                    fi
                fi
            fi
        fi
    done
    
    # Перезапуск контейнеров для применения новой конфигурации
    log "Применение новой конфигурации..."
    docker-compose -f docker-compose.monitoring.yml restart
    
    log "Конфигурация обновлена"
}

# Обновление дашбордов Grafana
update_dashboards() {
    log "Обновление дашбордов Grafana..."
    
    # Ожидание запуска Grafana
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s http://localhost:3000/api/health > /dev/null; then
            break
        fi
        attempt=$((attempt + 1))
        sleep 10
    done
    
    if [ $attempt -eq $max_attempts ]; then
        error "Grafana не запустилась после обновления"
        exit 1
    fi
    
    # Обновление дашбордов через API
    local grafana_api="http://localhost:3000/api"
    local auth="admin:admin123"
    
    # Импорт дашбордов
    for dashboard_file in "$PROJECT_DIR/grafana/dashboards"/*.json; do
        if [ -f "$dashboard_file" ]; then
            local dashboard_name=$(basename "$dashboard_file" .json)
            log "Обновление дашборда: $dashboard_name"
            
            curl -s -X POST \
                -u "$auth" \
                -H "Content-Type: application/json" \
                -d "{\"dashboard\": $(cat $dashboard_file), \"overwrite\": true}" \
                "$grafana_api/dashboards/db" > /dev/null
        fi
    done
    
    log "Дашборды обновлены"
}

# Проверка после обновления
post_update_check() {
    log "Проверка после обновления..."
    
    # Запуск health check
    if ! "$SCRIPT_DIR/monitoring-health-check.sh"; then
        error "Проверка здоровья не пройдена"
        
        if [ "$FORCE_UPDATE" != true ]; then
            warning "Откат обновления..."
            rollback_update
            exit 1
        fi
    fi
    
    log "Обновление успешно завершено"
}

# Откат обновления
rollback_update() {
    log "Откат обновления..."
    
    # Найти последний бэкап
    local last_backup=$(find /opt/backups/monitoring/full -maxdepth 1 -type d -name "backup_*" | sort -r | head -1)
    
    if [ -n "$last_backup" ]; then
        "$SCRIPT_DIR/backup-monitoring.sh" restore "$last_backup"
        log "Откат завершен из: $last_backup"
    else
        error "Бэкап для отката не найден"
        exit 1
    fi
}

# Обновление правил алертов
update_alerts() {
    log "Обновление правил алертов..."
    
    cd "$PROJECT_DIR"
    
    # Проверка синтаксиса правил алертов
    if ! docker run --rm -v "$PROJECT_DIR/prometheus:/prometheus" prom/prometheus:latest check rules /prometheus/rules/audio-streaming.yml; then
        error "Ошибка в правилах алертов"
        if [ "$FORCE_UPDATE" != true ]; then
            exit 1
        fi
    fi
    
    # Перезапуск Prometheus для применения новых правил
    docker-compose -f docker-compose.monitoring.yml restart prometheus
    
    log "Правила алертов обновлены"
}

# Обновление SSL сертификатов
update_ssl_certificates() {
    log "Обновление SSL сертификатов..."
    
    # Проверка наличия certbot
    if command -v certbot &> /dev/null; then
        certbot renew --quiet
        
        # Перезапуск nginx если используется
        if docker ps --format '{{.Names}}' | grep -q "nginx"; then
            docker-compose -f docker-compose.monitoring.yml restart nginx
        fi
        
        log "SSL сертификаты обновлены"
    else
        warning "Certbot не установлен, пропуск обновления SSL"
    fi
}

# Генерация отчета об обновлении
generate_update_report() {
    log "Генерация отчета об обновлении..."
    
    local report_file="/tmp/monitoring-update-report-$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "Отчет об обновлении мониторинговой системы"
        echo "========================================="
        echo "Дата: $(date)"
        echo "Тип обновления: $BACKUP_TYPE"
        echo ""
        
        echo "Версии образов:"
        docker images | grep -E "(prometheus|grafana|exporter|cadvisor|alertmanager)" | awk '{print $1":"$2" ("$3")"}'
        
        echo ""
        echo "Статус контейнеров:"
        docker-compose -f docker-compose.monitoring.yml ps
        
        echo ""
        echo "Использование ресурсов:"
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | grep -E "(prometheus|grafana|exporter|cadvisor|alertmanager)"
        
    } > "$report_file"
    
    echo -e "${GREEN}Отчет сохранен в: $report_file${NC}"
}

# Основная функция
main() {
    log "Запуск обновления мониторинговой системы..."
    
    if [ "$ROLLBACK" = true ]; then
        rollback_update
        exit 0
    fi
    
    check_dependencies
    
    if [ "$FORCE_UPDATE" != true ]; then
        check_for_updates
    fi
    
    create_backup
    
    update_images
    update_configuration
    update_alerts
    update_dashboards
    update_ssl_certificates
    
    post_update_check
    
    generate_update_report
    
    log "Обновление успешно завершено!"
}

# Запуск
main "$@"