#!/bin/bash

# Скрипт для проверки здоровья мониторинговой системы
# Использование: ./health-check.sh [options]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_DIR/config/health-check.json"
LOG_FILE="/var/log/monitoring-health.log"
VERBOSE=false
JSON_OUTPUT=false
ALERT_THRESHOLD=80
CHECK_INTERVAL=30
MAX_RETRIES=3
TIMEOUT=10

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Состояние проверок
declare -A CHECK_RESULTS
declare -A CHECK_DETAILS

# Парсинг аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        --config|-c)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --json|-j)
            JSON_OUTPUT=true
            shift
            ;;
        --threshold|-t)
            ALERT_THRESHOLD="$2"
            shift 2
            ;;
        --interval|-i)
            CHECK_INTERVAL="$2"
            shift 2
            ;;
        --timeout|-T)
            TIMEOUT="$2"
            shift 2
            ;;
        --log|-l)
            LOG_FILE="$2"
            shift 2
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
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    
    if [ "$VERBOSE" = true ] || [ "$level" = "ERROR" ]; then
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
    fi
    
    # Логирование в файл
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

error() {
    log "ERROR" "$@"
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
Скрипт для проверки здоровья мониторинговой системы

Использование: $0 [options]

Параметры:
    --config, -c      Путь к файлу конфигурации
    --verbose, -v     Подробный вывод
    --json, -j        Вывод в формате JSON
    --threshold, -t   Порог предупреждений (по умолчанию: 80)
    --interval, -i    Интервал между проверками в секундах
    --timeout, -T     Таймаут для проверок в секундах
    --log, -l         Путь к файлу логов
    --help, -h        Показать эту справку

Примеры:
    $0 --verbose
    $0 --json --threshold 90
    $0 --interval 60 --timeout 5
EOF
}

# Загрузка конфигурации
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        debug "Загрузка конфигурации из $CONFIG_FILE"
        # Здесь можно добавить парсинг JSON конфигурации
    else
        debug "Файл конфигурации не найден, используются значения по умолчанию"
    fi
}

# Проверка доступности сервиса
check_service_health() {
    local service=$1
    local url=$2
    local expected_status=${3:-200}
    
    debug "Проверка $service: $url"
    
    local response
    local http_code
    local response_time
    
    response=$(curl -s -w "\n%{http_code}\n%{time_total}" --max-time "$TIMEOUT" "$url" 2>/dev/null || echo -e "\n000\n999")
    
    http_code=$(echo "$response" | tail -2 | head -1)
    response_time=$(echo "$response" | tail -1)
    
    if [ "$http_code" = "$expected_status" ]; then
        CHECK_RESULTS[$service]="OK"
        CHECK_DETAILS[$service]="HTTP $http_code (${response_time}s)"
        return 0
    else
        CHECK_RESULTS[$service]="FAIL"
        CHECK_DETAILS[$service]="HTTP $http_code (${response_time}s)"
        return 1
    fi
}

# Проверка Docker контейнеров
check_docker_containers() {
    local containers=("prometheus" "grafana" "alertmanager" "redis" "nginx")
    
    debug "Проверка Docker контейнеров"
    
    for container in "${containers[@]}"; do
        local container_name="monitoring_${container}_1"
        
        if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
            local status=$(docker inspect --format='{{.State.Status}}' "$container_name")
            local health=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "no_health")
            
            if [ "$status" = "running" ]; then
                CHECK_RESULTS[$container]="OK"
                CHECK_DETAILS[$container]="Running (${health})"
            else
                CHECK_RESULTS[$container]="FAIL"
                CHECK_DETAILS[$container]="Status: $status"
            fi
        else
            CHECK_RESULTS[$container]="FAIL"
            CHECK_DETAILS[$container]="Container not found"
        fi
    done
}

# Проверка ресурсов
check_resources() {
    debug "Проверка использования ресурсов"
    
    # CPU использование
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//' || echo "0")
    cpu_usage=${cpu_usage%.*}
    
    if [ "$cpu_usage" -lt "$ALERT_THRESHOLD" ]; then
        CHECK_RESULTS["cpu"]="OK"
    else
        CHECK_RESULTS["cpu"]="WARN"
    fi
    CHECK_DETAILS["cpu"]="${cpu_usage}%"
    
    # Память
    local mem_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
    
    if [ "$mem_usage" -lt "$ALERT_THRESHOLD" ]; then
        CHECK_RESULTS["memory"]="OK"
    else
        CHECK_RESULTS["memory"]="WARN"
    fi
    CHECK_DETAILS["memory"]="${mem_usage}%"
    
    # Диск
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    
    if [ "$disk_usage" -lt "$ALERT_THRESHOLD" ]; then
        CHECK_RESULTS["disk"]="OK"
    else
        CHECK_RESULTS["disk"]="WARN"
    fi
    CHECK_DETAILS["disk"]="${disk_usage}%"
}

# Проверка Prometheus
check_prometheus() {
    local prometheus_url="http://localhost:9090"
    
    debug "Проверка Prometheus"
    
    # Проверка health endpoint
    check_service_health "prometheus_health" "${prometheus_url}/-/healthy" "200"
    
    # Проверка метрик
    local metrics_response=$(curl -s --max-time "$TIMEOUT" "${prometheus_url}/api/v1/query?query=up" 2>/dev/null || echo "")
    
    if [ -n "$metrics_response" ]; then
        local active_targets=$(echo "$metrics_response" | jq -r '.data.result | length' 2>/dev/null || echo "0")
        
        if [ "$active_targets" -gt 0 ]; then
            CHECK_RESULTS["prometheus_metrics"]="OK"
            CHECK_DETAILS["prometheus_metrics"]="$active_targets targets"
        else
            CHECK_RESULTS["prometheus_metrics"]="WARN"
            CHECK_DETAILS["prometheus_metrics"]="No active targets"
        fi
    else
        CHECK_RESULTS["prometheus_metrics"]="FAIL"
        CHECK_DETAILS["prometheus_metrics"]="Cannot query metrics"
    fi
}

# Проверка Grafana
check_grafana() {
    local grafana_url="http://localhost:3000"
    
    debug "Проверка Grafana"
    
    # Проверка health endpoint
    check_service_health "grafana_health" "${grafana_url}/api/health" "200"
    
    # Проверка дашбордов
    local dashboards_response=$(curl -s --max-time "$TIMEOUT" "${grafana_url}/api/search?type=dash-db" 2>/dev/null || echo "")
    
    if [ -n "$dashboards_response" ]; then
        local dashboard_count=$(echo "$dashboards_response" | jq -r 'length' 2>/dev/null || echo "0")
        
        if [ "$dashboard_count" -gt 0 ]; then
            CHECK_RESULTS["grafana_dashboards"]="OK"
            CHECK_DETAILS["grafana_dashboards"]="$dashboard_count dashboards"
        else
            CHECK_RESULTS["grafana_dashboards"]="WARN"
            CHECK_DETAILS["grafana_dashboards"]="No dashboards found"
        fi
    else
        CHECK_RESULTS["grafana_dashboards"]="FAIL"
        CHECK_DETAILS["grafana_dashboards"]="Cannot query dashboards"
    fi
}

# Проверка Alertmanager
check_alertmanager() {
    local alertmanager_url="http://localhost:9093"
    
    debug "Проверка Alertmanager"
    
    # Проверка status endpoint
    check_service_health "alertmanager_health" "${alertmanager_url}/api/v1/status" "200"
    
    # Проверка активных алертов
    local alerts_response=$(curl -s --max-time "$TIMEOUT" "${alertmanager_url}/api/v1/alerts" 2>/dev/null || echo "")
    
    if [ -n "$alerts_response" ]; then
        local active_alerts=$(echo "$alerts_response" | jq -r '[.data[] | select(.state == "active")] | length' 2>/dev/null || echo "0")
        
        if [ "$active_alerts" -eq 0 ]; then
            CHECK_RESULTS["alertmanager_alerts"]="OK"
            CHECK_DETAILS["alertmanager_alerts"]="No active alerts"
        else
            CHECK_RESULTS["alertmanager_alerts"]="WARN"
            CHECK_DETAILS["alertmanager_alerts"]="$active_alerts active alerts"
        fi
    else
        CHECK_RESULTS["alertmanager_alerts"]="FAIL"
        CHECK_DETAILS["alertmanager_alerts"]="Cannot query alerts"
    fi
}

# Проверка Redis
check_redis() {
    local redis_url="redis://localhost:6379"
    
    debug "Проверка Redis"
    
    # Проверка через redis-cli
    local redis_response=$(redis-cli ping 2>/dev/null || echo "")
    
    if [ "$redis_response" = "PONG" ]; then
        CHECK_RESULTS["redis"]="OK"
        CHECK_DETAILS["redis"]="Connected"
    else
        CHECK_RESULTS["redis"]="FAIL"
        CHECK_DETAILS["redis"]="Connection failed"
    fi
}

# Проверка Nginx
check_nginx() {
    local nginx_url="http://localhost:80"
    
    debug "Проверка Nginx"
    
    check_service_health "nginx" "$nginx_url" "200"
}

# Проверка SSL сертификатов
check_ssl_certificates() {
    local domains=("dnb1st.ru" "monitoring.dnb1st.ru")
    
    debug "Проверка SSL сертификатов"
    
    for domain in "${domains[@]}"; do
        local cert_info=$(echo | openssl s_client -servername "$domain" -connect "${domain}:443" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null || echo "")
        
        if [ -n "$cert_info" ]; then
            local expiry_date=$(echo "$cert_info" | grep "notAfter" | cut -d= -f2)
            local expiry_epoch=$(date -d "$expiry_date" +%s)
            local current_epoch=$(date +%s)
            local days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))
            
            if [ "$days_until_expiry" -gt 30 ]; then
                CHECK_RESULTS["ssl_${domain}"]="OK"
            elif [ "$days_until_expiry" -gt 7 ]; then
                CHECK_RESULTS["ssl_${domain}"]="WARN"
            else
                CHECK_RESULTS["ssl_${domain}"]="FAIL"
            fi
            
            CHECK_DETAILS["ssl_${domain}"]="${days_until_expiry} days"
        else
            CHECK_RESULTS["ssl_${domain}"]="FAIL"
            CHECK_DETAILS["ssl_${domain}"]="Cannot retrieve certificate"
        fi
    done
}

# Проверка логов на ошибки
check_logs_for_errors() {
    debug "Проверка логов на ошибки"
    
    local log_files=(
        "/var/log/monitoring/prometheus.log"
        "/var/log/monitoring/grafana.log"
        "/var/log/monitoring/alertmanager.log"
    )
    
    for log_file in "${log_files[@]}"; do
        if [ -f "$log_file" ]; then
            local error_count=$(grep -i "error\|fatal\|panic" "$log_file" | wc -l)
            
            if [ "$error_count" -eq 0 ]; then
                CHECK_RESULTS["logs_$(basename "$log_file")"]="OK"
                CHECK_DETAILS["logs_$(basename "$log_file")"]="No errors"
            else
                CHECK_RESULTS["logs_$(basename "$log_file")"]="WARN"
                CHECK_DETAILS["logs_$(basename "$log_file")"]="$error_count errors"
            fi
        fi
    done
}

# Проверка сетевой связности
check_network_connectivity() {
    debug "Проверка сетевой связности"
    
    local endpoints=(
        "8.8.8.8"
        "1.1.1.1"
        "google.com"
    )
    
    for endpoint in "${endpoints[@]}"; do
        if ping -c 1 -W 3 "$endpoint" > /dev/null 2>&1; then
            CHECK_RESULTS["network_${endpoint}"]="OK"
            CHECK_DETAILS["network_${endpoint}"]="Reachable"
        else
            CHECK_RESULTS["network_${endpoint}"]="FAIL"
            CHECK_DETAILS["network_${endpoint}"]="Unreachable"
        fi
    done
}

# Проверка дискового пространства
check_disk_space() {
    debug "Проверка дискового пространства"
    
    local mount_points=("/" "/var/lib/docker" "/opt")
    
    for mount_point in "${mount_points[@]}"; do
        if [ -d "$mount_point" ]; then
            local usage=$(df "$mount_point" | tail -1 | awk '{print $5}' | sed 's/%//')
            
            if [ "$usage" -lt 80 ]; then
                CHECK_RESULTS["disk_${mount_point}"]="OK"
            elif [ "$usage" -lt 90 ]; then
                CHECK_RESULTS["disk_${mount_point}"]="WARN"
            else
                CHECK_RESULTS["disk_${mount_point}"]="FAIL"
            fi
            
            CHECK_DETAILS["disk_${mount_point}"]="${usage}%"
        fi
    done
}

# Проверка процессов
check_processes() {
    debug "Проверка процессов"
    
    local processes=("dockerd" "prometheus" "grafana-server" "alertmanager")
    
    for process in "${processes[@]}"; do
        if pgrep -f "$process" > /dev/null; then
            CHECK_RESULTS["process_${process}"]="OK"
            CHECK_DETAILS["process_${process}"]="Running"
        else
            CHECK_RESULTS["process_${process}"]="FAIL"
            CHECK_DETAILS["process_${process}"]="Not running"
        fi
    done
}

# Выполнение всех проверок
run_all_checks() {
    debug "Запуск всех проверок"
    
    # Docker контейнеры
    check_docker_containers
    
    # Сервисы
    check_prometheus
    check_grafana
    check_alertmanager
    check_redis
    check_nginx
    
    # Ресурсы
    check_resources
    
    # SSL
    check_ssl_certificates
    
    # Логи
    check_logs_for_errors
    
    # Сеть
    check_network_connectivity
    
    # Диск
    check_disk_space
    
    # Процессы
    check_processes
}

# Форматирование вывода
format_output() {
    if [ "$JSON_OUTPUT" = true ]; then
        format_json_output
    else
        format_text_output
    fi
}

# Текстовый вывод
format_text_output() {
    echo
    echo "=== Отчет о здоровье мониторинговой системы ==="
    echo
    
    local total_checks=0
    local ok_checks=0
    local warn_checks=0
    local fail_checks=0
    
    for check in "${!CHECK_RESULTS[@]}"; do
        total_checks=$((total_checks + 1))
        
        case "${CHECK_RESULTS[$check]}" in
            "OK")
                ok_checks=$((ok_checks + 1))
                echo -e "✓ ${GREEN}$check${NC}: ${CHECK_DETAILS[$check]}"
                ;;
            "WARN")
                warn_checks=$((warn_checks + 1))
                echo -e "⚠ ${YELLOW}$check${NC}: ${CHECK_DETAILS[$check]}"
                ;;
            "FAIL")
                fail_checks=$((fail_checks + 1))
                echo -e "✗ ${RED}$check${NC}: ${CHECK_DETAILS[$check]}"
                ;;
        esac
    done
    
    echo
    echo "=== Сводка ==="
    echo "Всего проверок: $total_checks"
    echo -e "Успешно: ${GREEN}$ok_checks${NC}"
    echo -e "Предупреждений: ${YELLOW}$warn_checks${NC}"
    echo -e "Ошибок: ${RED}$fail_checks${NC}"
    
    if [ "$fail_checks" -gt 0 ]; then
        echo
        echo -e "${RED}⚠️  Обнаружены критические проблемы!${NC}"
        return 1
    elif [ "$warn_checks" -gt 0 ]; then
        echo
        echo -e "${YELLOW}⚠️  Обнаружены предупреждения${NC}"
        return 2
    else
        echo
        echo -e "${GREEN}✅ Все проверки пройдены успешно${NC}"
        return 0
    fi
}

# JSON вывод
format_json_output() {
    local json="{"
    json+="\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
    json+="\"checks\":{"
    
    local first=true
    for check in "${!CHECK_RESULTS[@]}"; do
        if [ "$first" = true ]; then
            first=false
        else
            json+=","
        fi
        
        json+="\"$check\":{"
        json+="\"status\":\"${CHECK_RESULTS[$check]}\","
        json+="\"details\":\"${CHECK_DETAILS[$check]}\""
        json+="}"
    done
    
    json+="},"
    
    # Сводка
    local total_checks=0
    local ok_checks=0
    local warn_checks=0
    local fail_checks=0
    
    for check in "${!CHECK_RESULTS[@]}"; do
        total_checks=$((total_checks + 1))
        case "${CHECK_RESULTS[$check]}" in
            "OK") ok_checks=$((ok_checks + 1)) ;;
            "WARN") warn_checks=$((warn_checks + 1)) ;;
            "FAIL") fail_checks=$((fail_checks + 1)) ;;
        esac
    done
    
    json+="\"summary\":{"
    json+="\"total\":$total_checks,"
    json+="\"ok\":$ok_checks,"
    json+="\"warning\":$warn_checks,"
    json+="\"fail\":$fail_checks"
    json+="}"
    
    json+="}"
    
    echo "$json" | jq .
}

# Отправка алертов
send_alerts() {
    local fail_count=0
    local warn_count=0
    
    for check in "${!CHECK_RESULTS[@]}"; do
        case "${CHECK_RESULTS[$check]}" in
            "FAIL") fail_count=$((fail_count + 1)) ;;
            "WARN") warn_count=$((warn_count + 1)) ;;
        esac
    done
    
    if [ "$fail_count" -gt 0 ] || [ "$warn_count" -gt 0 ]; then
        # Отправка email
        if command -v mail > /dev/null 2>&1; then
            local subject="Monitoring Health Alert - $(hostname)"
            local body=$(cat <<EOF
Monitoring system health check detected issues:

Failed checks: $fail_count
Warning checks: $warn_count

Details:
$(for check in "${!CHECK_RESULTS[@]}"; do
    echo "- $check: ${CHECK_RESULTS[$check]} - ${CHECK_DETAILS[$check]}"
done)

Timestamp: $(date)
EOF
)
            echo "$body" | mail -s "$subject" "admin@dnb1st.ru" 2>/dev/null || true
        fi
        
        # Отправка в Slack
        if [ -n "$SLACK_WEBHOOK" ]; then
            local slack_payload=$(cat <<EOF
{
    "text": "Monitoring Health Alert",
    "attachments": [
        {
            "color": "danger",
            "fields": [
                {
                    "title": "Failed Checks",
                    "value": "$fail_count",
                    "short": true
                },
                {
                    "title": "Warning Checks",
                    "value": "$warn_count",
                    "short": true
                },
                {
                    "title": "Host",
                    "value": "$(hostname)",
                    "short": true
                }
            ]
        }
    ]
}
EOF
)
            curl -X POST -H 'Content-type: application/json' --data "$slack_payload" "$SLACK_WEBHOOK" 2>/dev/null || true
        fi
    fi
}

# Мониторинг в реальном времени
monitor_realtime() {
    info "Запуск мониторинга в реальном времени (интервал: ${CHECK_INTERVAL}s)"
    
    while true; do
        clear
        echo "=== Мониторинг в реальном времени ==="
        echo "Обновлено: $(date)"
        echo
        
        # Очистка предыдущих результатов
        unset CHECK_RESULTS
        unset CHECK_DETAILS
        declare -A CHECK_RESULTS
        declare -A CHECK_DETAILS
        
        # Выполнение проверок
        run_all_checks
        
        # Вывод результатов
        format_text_output
        
        sleep "$CHECK_INTERVAL"
    done
}

# Основная функция
main() {
    local start_time=$(date +%s)
    
    # Создание директории для логов
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Загрузка конфигурации
    load_config
    
    # Выполнение проверок
    run_all_checks
    
    # Отправка алертов
    send_alerts
    
    # Форматирование вывода
    format_output
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    debug "Проверка завершена за ${duration} секунд"
}

# Запуск скрипта
main "$@"