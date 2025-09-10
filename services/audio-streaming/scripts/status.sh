#!/bin/bash

# Скрипт для проверки статуса audio-streaming сервиса
# Поддерживает локальный и удаленный мониторинг

set -e

# Конфигурация
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CHECK_TYPE=${1:-local}
VERBOSE=${2:-false}

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
        "STATUS")
            echo -e "${CYAN}[$timestamp] $message${NC}"
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

status() {
    log "STATUS" "$@"
}

# Показать справку
show_help() {
    cat <<EOF
Скрипт проверки статуса для audio-streaming сервиса

Использование: $0 <check_type> [verbose] [options]

Типы проверки:
    local       Локальная проверка на текущей машине
    remote      Удаленная проверка на сервере 176.108.246.49

Параметры:
    verbose     Подробный вывод (true/false)

Опции:
    --help, -h  Показать эту справку

Примеры:
    $0                    # Локальная проверка
    $0 remote             # Удаленная проверка
    $0 local true         # Локальная проверка с подробным выводом
    $0 --help             # Показать справку

EOF
}

# Форматирование вывода
format_output() {
    local label=$1
    local value=$2
    local status=$3
    
    case "$status" in
        "OK")
            echo -e "${GREEN}✓${NC} ${label}: ${value}"
            ;;
        "WARN")
            echo -e "${YELLOW}⚠${NC} ${label}: ${value}"
            ;;
        "ERROR")
            echo -e "${RED}✗${NC} ${label}: ${value}"
            ;;
        "INFO")
            echo -e "${BLUE}ℹ${NC} ${label}: ${value}"
            ;;
    esac
}

# Проверка Docker контейнеров
check_containers() {
    local host_type=$1
    
    status "=== Проверка Docker контейнеров ==="
    
    local containers
    if [ "$host_type" == "remote" ]; then
        containers=$(ssh aendy@176.108.246.49 "docker-compose ps --format json" 2>/dev/null || echo "[]")
    else
        containers=$(docker-compose ps --format json 2>/dev/null || echo "[]")
    fi
    
    if [ "$containers" == "[]" ] || [ -z "$containers" ]; then
        format_output "Контейнеры" "Не запущены" "ERROR"
        return 1
    fi
    
    local running_count=$(echo "$containers" | jq -r '. | select(.State == "running") | .Name' | wc -l)
    local total_count=$(echo "$containers" | jq -r '.Name' | wc -l)
    
    format_output "Контейнеры" "$running_count/$total_count запущены" "OK"
    
    if [ "$VERBOSE" == "true" ]; then
        echo "$containers" | jq -r '. | "\(.Name): \(.State) (\(.Status))"' | while read -r line; do
            if [[ "$line" == *"running"* ]]; then
                format_output "  - $line" "" "OK"
            else
                format_output "  - $line" "" "ERROR"
            fi
        done
    fi
}

# Проверка портов
check_ports() {
    local host_type=$1
    
    status "=== Проверка портов ==="
    
    local ports=(
        "80:HTTP"
        "443:HTTPS"
        "3003:Grafana"
        "9090:Prometheus"
    )
    
    local host="localhost"
    if [ "$host_type" == "remote" ]; then
        host="176.108.246.49"
    fi
    
    for port_info in "${ports[@]}"; do
        local port=$(echo "$port_info" | cut -d: -f1)
        local name=$(echo "$port_info" | cut -d: -f2)
        
        if nc -z "$host" "$port" 2>/dev/null; then
            format_output "$name" "Порт $port доступен" "OK"
        else
            format_output "$name" "Порт $port недоступен" "ERROR"
        fi
    done
}

# Проверка HTTP эндпоинтов
check_endpoints() {
    local host_type=$1
    
    status "=== Проверка HTTP эндпоинтов ==="
    
    local endpoints=(
        "/health:Главное приложение"
        "/api/health:API"
        "/metrics:Prometheus метрики"
    )
    
    local protocol="http"
    local host="localhost"
    if [ "$host_type" == "remote" ]; then
        host="176.108.246.49"
    fi
    
    for endpoint_info in "${endpoints[@]}"; do
        local endpoint=$(echo "$endpoint_info" | cut -d: -f1)
        local name=$(echo "$endpoint_info" | cut -d: -f2)
        local url="${protocol}://${host}${endpoint}"
        
        local response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
        
        if [ "$response" == "200" ]; then
            format_output "$name" "$url - OK" "OK"
        else
            format_output "$name" "$url - HTTP $response" "ERROR"
        fi
    done
}

# Проверка ресурсов
check_resources() {
    local host_type=$1
    
    status "=== Проверка ресурсов ==="
    
    local cpu_usage
    local memory_usage
    local disk_usage
    
    if [ "$host_type" == "remote" ]; then
        cpu_usage=$(ssh aendy@176.108.246.49 "top -bn1 | grep 'Cpu(s)' | awk '{print \\$2}' | cut -d'%' -f1" 2>/dev/null || echo "0")
        memory_usage=$(ssh aendy@176.108.246.49 "free | grep Mem | awk '{printf \"%.1f\", \\$3/\\$2 * 100.0}'" 2>/dev/null || echo "0")
        disk_usage=$(ssh aendy@176.108.246.49 "df -h / | tail -1 | awk '{print \\$5}' | sed 's/%//'" 2>/dev/null || echo "0")
    else
        cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 2>/dev/null || echo "0")
        memory_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}' 2>/dev/null || echo "0")
        disk_usage=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//' 2>/dev/null || echo "0")
    fi
    
    # Оценка состояния
    local cpu_status="OK"
    local memory_status="OK"
    local disk_status="OK"
    
    if (( $(echo "$cpu_usage > 80" | bc -l) )); then
        cpu_status="WARN"
    fi
    
    if (( $(echo "$memory_usage > 80" | bc -l) )); then
        memory_status="WARN"
    fi
    
    if (( disk_usage > 80 )); then
        disk_status="WARN"
    fi
    
    format_output "CPU" "${cpu_usage}% использовано" "$cpu_status"
    format_output "Память" "${memory_usage}% использовано" "$memory_status"
    format_output "Диск" "${disk_usage}% использовано" "$disk_status"
}

# Проверка логов
check_logs() {
    local host_type=$1
    
    status "=== Проверка логов ==="
    
    local error_patterns=(
        "ERROR"
        "FATAL"
        "panic"
        "exception"
    )
    
    local log_sources=(
        "app:docker-compose logs --tail=50 app"
        "nginx:docker-compose logs --tail=50 nginx"
        "grafana:docker-compose logs --tail=50 grafana"
    )
    
    local errors_found=0
    
    for log_source in "${log_sources[@]}"; do
        local name=$(echo "$log_source" | cut -d: -f1)
        local cmd=$(echo "$log_source" | cut -d: -f2-)
        
        local logs
        if [ "$host_type" == "remote" ]; then
            logs=$(ssh aendy@176.108.246.49 "cd /opt/audio-streaming && $cmd" 2>/dev/null || echo "")
        else
            logs=$($cmd 2>/dev/null || echo "")
        fi
        
        for pattern in "${error_patterns[@]}"; do
            if echo "$logs" | grep -i "$pattern" >/dev/null 2>&1; then
                format_output "Логи $name" "Найдены ошибки ($pattern)" "WARN"
                ((errors_found++))
                
                if [ "$VERBOSE" == "true" ]; then
                    echo "$logs" | grep -i "$pattern" | head -5 | sed 's/^/    /'
                fi
            fi
        done
    done
    
    if [ $errors_found -eq 0 ]; then
        format_output "Логи" "Ошибок не обнаружено" "OK"
    fi
}

# Проверка SSL сертификатов
check_ssl() {
    local host_type=$1
    
    status "=== Проверка SSL сертификатов ==="
    
    local domain="dnb1st.ru"
    if [ "$host_type" == "remote" ]; then
        domain="176.108.246.49"
    fi
    
    local cert_info=$(echo | openssl s_client -servername "$domain" -connect "$domain":443 2>/dev/null | openssl x509 -noout -dates 2>/dev/null || echo "")
    
    if [ -n "$cert_info" ]; then
        local not_after=$(echo "$cert_info" | grep "notAfter" | cut -d= -f2)
        local expiry_date=$(date -d "$not_after" +%s 2>/dev/null || echo "0")
        local current_date=$(date +%s)
        local days_until_expiry=$(( (expiry_date - current_date) / 86400 ))
        
        if [ $days_until_expiry -gt 30 ]; then
            format_output "SSL сертификат" "Действителен еще $days_until_expiry дней" "OK"
        elif [ $days_until_expiry -gt 7 ]; then
            format_output "SSL сертификат" "Истекает через $days_until_expiry дней" "WARN"
        else
            format_output "SSL сертификат" "Истекает через $days_until_expiry дней" "ERROR"
        fi
    else
        format_output "SSL сертификат" "Не удалось получить информацию" "ERROR"
    fi
}

# Сводный отчет
generate_summary() {
    local host_type=$1
    
    status "=== Сводный отчет ==="
    
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    format_output "Время проверки" "$timestamp" "INFO"
    format_output "Тип проверки" "$host_type" "INFO"
    
    echo ""
    echo "Для подробной информации используйте:"
    echo "  $0 $host_type true"
}

# Локальная проверка
check_local() {
    info "Запуск локальной проверки..."
    
    check_containers "local"
    check_ports "local"
    check_endpoints "local"
    check_resources "local"
    check_logs "local"
    check_ssl "local"
    
    generate_summary "local"
}

# Удаленная проверка
check_remote() {
    info "Запуск удаленной проверки..."
    
    # Проверка SSH доступа
    if ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no aendy@176.108.246.49 "echo 'SSH connection successful'" &>/dev/null; then
        error "Не удалось подключиться по SSH к 176.108.246.49"
    fi
    
    check_containers "remote"
    check_ports "remote"
    check_endpoints "remote"
    check_resources "remote"
    check_logs "remote"
    check_ssl "remote"
    
    generate_summary "remote"
}

# Главная функция
main() {
    info "Скрипт проверки статуса"
    info "Тип: $CHECK_TYPE"
    info "Подробный режим: $VERBOSE"
    
    case "$CHECK_TYPE" in
        local)
            check_local
            ;;
        remote)
            check_remote
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            error "Неизвестный тип проверки: $CHECK_TYPE"
            ;;
    esac
    
    success "Проверка завершена!"
}

# Обработка аргументов
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    show_help
    exit 0
fi

# Запуск главной функции
main "$@"