#!/bin/bash

# Скрипт для проверки здоровья мониторинговой системы
# Использование: ./monitoring-health-check.sh [--verbose]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR)"
VERBOSE=false
TIMEOUT=30
MAX_RETRIES=3

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
        --timeout|-t)
            TIMEOUT="$2"
            shift 2
            ;;
        *)
            echo "Неизвестный аргумент: $1"
            exit 1
            ;;
    esac
done

log() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
    fi
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

# Проверка доступности сервиса
check_service() {
    local name=$1
    local url=$2
    local expected_status=${3:-200}
    
    log "Проверка $name ($url)..."
    
    local attempt=0
    while [ $attempt -lt $MAX_RETRIES ]; do
        local response=$(curl -s -o /dev/null -w "%{http_code}" --max-time $TIMEOUT "$url" 2>/dev/null || echo "000")
        
        if [ "$response" = "$expected_status" ]; then
            success "$name доступен"
            return 0
        fi
        
        attempt=$((attempt + 1))
        if [ $attempt -lt $MAX_RETRIES ]; then
            log "Повторная попытка $attempt/$MAX_RETRIES для $name..."
            sleep 5
        fi
    done
    
    error "$name недоступен (ответ: $response)"
    return 1
}

# Проверка Docker контейнеров
check_containers() {
    log "Проверка Docker контейнеров..."
    
    local containers=(
        "prometheus"
        "grafana"
        "node-exporter"
        "nginx-exporter"
        "redis-exporter"
        "cadvisor"
        "alertmanager"
    )
    
    local failed_containers=()
    
    for container in "${containers[@]}"; do
        if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            local status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "unknown")
            local health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "no health check")
            
            if [ "$status" = "running" ]; then
                if [ "$health" = "healthy" ] || [ "$health" = "no health check" ]; then
                    success "Контейнер $container работает"
                else
                    warning "Контейнер $container работает, но нездоров ($health)"
                    failed_containers+=("$container")
                fi
            else
                error "Контейнер $container не работает ($status)"
                failed_containers+=("$container")
            fi
        else
            error "Контейнер $container не найден"
            failed_containers+=("$container")
        fi
    done
    
    if [ ${#failed_containers[@]} -gt 0 ]; then
        error "Неисправные контейнеры: ${failed_containers[*]}"
        return 1
    fi
    
    return 0
}

# Проверка метрик Prometheus
check_prometheus_metrics() {
    log "Проверка метрик Prometheus..."
    
    local prometheus_url="http://localhost:9090"
    
    # Проверка доступности Prometheus
    if ! check_service "Prometheus" "$prometheus_url/api/v1/query?query=up" 200; then
        return 1
    fi
    
    # Проверка наличия базовых метрик
    local metrics=(
        "up"
        "prometheus_build_info"
        "node_cpu_seconds_total"
        "node_memory_MemTotal_bytes"
        "container_cpu_usage_seconds_total"
        "redis_connected_clients"
        "nginx_up"
    )
    
    local failed_metrics=()
    
    for metric in "${metrics[@]}"; do
        local response=$(curl -s --max-time $TIMEOUT "$prometheus_url/api/v1/query?query=$metric" | jq -r '.data.result | length' 2>/dev/null || echo "0")
        
        if [ "$response" -gt 0 ]; then
            success "Метрика $metric доступна"
        else
            warning "Метрика $metric не найдена"
            failed_metrics+=("$metric")
        fi
    done
    
    if [ ${#failed_metrics[@]} -gt 0 ]; then
        warning "Некоторые метрики отсутствуют: ${failed_metrics[*]}"
    fi
    
    return 0
}

# Проверка Grafana
check_grafana() {
    log "Проверка Grafana..."
    
    local grafana_url="http://localhost:3000"
    
    # Проверка доступности Grafana
    if ! check_service "Grafana" "$grafana_url/api/health" 200; then
        return 1
    fi
    
    # Проверка наличия дашбордов
    local dashboards=$(curl -s --max-time $TIMEOUT -u admin:admin123 "$grafana_url/api/search" | jq -r '.[].title' 2>/dev/null || echo "")
    
    if [ -n "$dashboards" ]; then
        success "Grafana дашборды доступны"
        if [ "$VERBOSE" = true ]; then
            echo "Дашборды:"
            echo "$dashboards" | while read -r dashboard; do
                echo "  - $dashboard"
            done
        fi
    else
        warning "Дашборды не найдены"
    fi
    
    return 0
}

# Проверка Alertmanager
check_alertmanager() {
    log "Проверка Alertmanager..."
    
    local alertmanager_url="http://localhost:9093"
    
    # Проверка доступности Alertmanager
    if ! check_service "Alertmanager" "$alertmanager_url/api/v1/status" 200; then
        return 1
    fi
    
    # Проверка статуса алертов
    local alerts=$(curl -s --max-time $TIMEOUT "$alertmanager_url/api/v1/alerts" | jq -r '.data | length' 2>/dev/null || echo "0")
    
    if [ "$alerts" -gt 0 ]; then
        warning "Активные алерты: $alerts"
        if [ "$VERBOSE" = true ]; then
            curl -s "$alertmanager_url/api/v1/alerts" | jq -r '.data[] | "\(.labels.alertname): \(.state)"'
        fi
    else
        success "Активных алертов нет"
    fi
    
    return 0
}

# Проверка использования ресурсов
check_resource_usage() {
    log "Проверка использования ресурсов..."
    
    # Проверка CPU и памяти
    local resource_usage=$(docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | grep -E "(prometheus|grafana|exporter|cadvisor|alertmanager)")
    
    if [ -n "$resource_usage" ]; then
        success "Использование ресурсов:"
        echo "$resource_usage"
    else
        warning "Нет данных об использовании ресурсов"
    fi
    
    # Проверка дискового пространства
    local disk_usage=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
    
    if [ "$disk_usage" -gt 80 ]; then
        warning "Использование диска: ${disk_usage}%"
    else
        success "Использование диска: ${disk_usage}%"
    fi
    
    return 0
}

# Проверка сетевой связности
check_network_connectivity() {
    log "Проверка сетевой связности..."
    
    local services=(
        "localhost:9090:Prometheus"
        "localhost:3000:Grafana"
        "localhost:9093:Alertmanager"
        "localhost:9100:Node Exporter"
        "localhost:9113:Nginx Exporter"
        "localhost:9121:Redis Exporter"
        "localhost:8080:Cadvisor"
    )
    
    local failed_services=()
    
    for service in "${services[@]}"; do
        IFS=':' read -r host port name <<< "$service"
        
        if nc -z -w $TIMEOUT "$host" "$port" 2>/dev/null; then
            success "$name доступен на $host:$port"
        else
            error "$name недоступен на $host:$port"
            failed_services+=("$name")
        fi
    done
    
    if [ ${#failed_services[@]} -gt 0 ]; then
        error "Недоступные сервисы: ${failed_services[*]}"
        return 1
    fi
    
    return 0
}

# Проверка логов
check_logs() {
    log "Проверка логов..."
    
    local containers=("prometheus" "grafana" "alertmanager")
    local errors_found=false
    
    for container in "${containers[@]}"; do
        local error_count=$(docker logs --since 1h "$container" 2>&1 | grep -i error | wc -l || echo "0")
        
        if [ "$error_count" -gt 0 ]; then
            warning "В логах $container найдено ошибок: $error_count"
            if [ "$VERBOSE" = true ]; then
                docker logs --since 1h "$container" 2>&1 | grep -i error | tail -5
            fi
            errors_found=true
        else
            success "В логах $container ошибок не найдено"
        fi
    done
    
    if [ "$errors_found" = true ]; then
        return 1
    fi
    
    return 0
}

# Генерация отчета о здоровье
generate_health_report() {
    log "Генерация отчета о здоровье..."
    
    local report_file="/tmp/monitoring-health-report-$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "Отчет о здоровье мониторинговой системы"
        echo "========================================"
        echo "Дата: $(date)"
        echo ""
        
        echo "Статус контейнеров:"
        docker-compose -f "$PROJECT_DIR/docker-compose.monitoring.yml" ps
        
        echo ""
        echo "Использование ресурсов:"
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | grep -E "(prometheus|grafana|exporter|cadvisor|alertmanager)"
        
        echo ""
        echo "Статус сервисов:"
        check_service "Prometheus" "http://localhost:9090/api/v1/query?query=up" 200
        check_service "Grafana" "http://localhost:3000/api/health" 200
        check_service "Alertmanager" "http://localhost:9093/api/v1/status" 200
        
        echo ""
        echo "Активные алерты:"
        curl -s http://localhost:9093/api/v1/alerts | jq -r '.data[] | "\(.labels.alertname): \(.state)"' 2>/dev/null || echo "Нет активных алертов"
        
    } > "$report_file"
    
    echo -e "${GREEN}Отчет сохранен в: $report_file${NC}"
}

# Основная функция проверки
main() {
    log "Запуск проверки здоровья мониторинговой системы..."
    
    local exit_code=0
    
    # Выполнение всех проверок
    check_containers || exit_code=1
    check_network_connectivity || exit_code=1
    check_prometheus_metrics || exit_code=1
    check_grafana || exit_code=1
    check_alertmanager || exit_code=1
    check_resource_usage || exit_code=1
    check_logs || exit_code=1
    
    if [ $exit_code -eq 0 ]; then
        success "Все проверки пройдены успешно"
    else
        error "Некоторые проверки не пройдены"
    fi
    
    # Генерация отчета
    generate_health_report
    
    exit $exit_code
}

# Запуск
main "$@"