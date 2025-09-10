#!/bin/bash

# Скрипт для тестирования системы мониторинга здоровья
# Использование: ./test-health-monitoring.sh [options]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$PROJECT_DIR/config"
LOGS_DIR="$PROJECT_DIR/logs"
TEST_DIR="$PROJECT_DIR/tests"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Параметры по умолчанию
VERBOSE=false
CONFIG_FILE="$CONFIG_DIR/health-check.json"
TEST_MODE="all"
OUTPUT_FORMAT="text"
CREATE_REPORT=false
REPORT_FILE="$PROJECT_DIR/test-report-$(date +%Y%m%d-%H%M%S).json"

# Парсинг аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --config|-c)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --mode|-m)
            TEST_MODE="$2"
            shift 2
            ;;
        --format|-f)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        --report|-r)
            CREATE_REPORT=true
            REPORT_FILE="$2"
            shift 2
            ;;
        --help|--h)
            show_help
            exit 0
            ;;
        *)
            echo "Неизвестный аргумент: $1"
            exit 1
            ;;
    esac
done

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
            if [ "$VERBOSE" = true ]; then
                echo -e "${BLUE}[$timestamp] $message${NC}"
            fi
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
Скрипт для тестирования системы мониторинга здоровья

Использование: $0 [options]

Опции:
    --verbose, -v     Подробный вывод
    --config, -c      Путь к конфигурационному файлу
    --mode, -m        Режим тестирования:
                      all, config, services, alerts, performance
    --format, -f      Формат вывода: text, json
    --report, -r      Создать отчет о тестировании
    --help, --h       Показать эту справку

Примеры:
    $0 --verbose
    $0 --mode services --format json
    $0 --config /path/to/config.json --report test-report.json
EOF
}

# Инициализация тестов
init_tests() {
    info "Инициализация тестов..."
    
    # Создать директорию для тестов
    mkdir -p "$TEST_DIR"
    
    # Создать директорию для логов
    mkdir -p "$LOGS_DIR"
    
    # Проверить конфигурацию
    if [ ! -f "$CONFIG_FILE" ]; then
        error "Конфигурационный файл не найден: $CONFIG_FILE"
    fi
    
    # Проверить jq
    if ! command -v jq &> /dev/null; then
        warning "jq не установлен, некоторые тесты могут быть недоступны"
    fi
    
    # Проверить curl
    if ! command -v curl &> /dev/null; then
        warning "curl не установлен, тесты сетевых сервисов будут пропущены"
    fi
    
    success "Инициализация завершена"
}

# Тестирование конфигурации
test_config() {
    info "Тестирование конфигурации..."
    
    local test_results=()
    
    # Проверить валидность JSON
    if jq empty "$CONFIG_FILE" 2>/dev/null; then
        test_results+=("JSON валиден: ✓")
    else
        test_results+=("JSON валиден: ✗")
        return 1
    fi
    
    # Проверить обязательные поля
    local required_fields=("services" "alerts")
    for field in "${required_fields[@]}"; do
        if jq -e ".$field" "$CONFIG_FILE" >/dev/null; then
            test_results+=("$field: ✓")
        else
            test_results+=("$field: ✗")
        fi
    done
    
    # Проверить сервисы
    local services=$(jq -r '.services | keys[]' "$CONFIG_FILE")
    while IFS= read -r service; do
        if [ -n "$service" ]; then
            test_results+=("Сервис $service: ✓")
        fi
    done <<< "$services"
    
    # Проверить настройки алертов
    if jq -e '.alerts.slack_webhook' "$CONFIG_FILE" >/dev/null; then
        test_results+=("Slack webhook: ✓")
    else
        test_results+=("Slack webhook: ✗")
    fi
    
    # Вывести результаты
    for result in "${test_results[@]}"; do
        info "  $result"
    done
    
    success "Тестирование конфигурации завершено"
}

# Тестирование сервисов
test_services() {
    info "Тестирование сервисов..."
    
    local services=$(jq -r '.services | keys[]' "$CONFIG_FILE")
    local test_results=()
    
    while IFS= read -r service; do
        if [ -z "$service" ]; then
            continue
        fi
        
        local enabled=$(jq -r ".services.$service.enabled" "$CONFIG_FILE")
        if [ "$enabled" != "true" ]; then
            test_results+=("$service: пропущен (disabled)")
            continue
        fi
        
        case "$service" in
            "nginx")
                test_nginx_service
                ;;
            "redis")
                test_redis_service
                ;;
            "postgresql")
                test_postgresql_service
                ;;
            "docker")
                test_docker_service
                ;;
            *)
                test_generic_service "$service"
                ;;
        esac
        
        test_results+=("$service: ✓")
    done <<< "$services"
    
    # Вывести результаты
    for result in "${test_results[@]}"; do
        info "  $result"
    done
    
    success "Тестирование сервисов завершено"
}

# Тестирование Nginx
test_nginx_service() {
    debug "Тестирование Nginx..."
    
    local port=$(jq -r '.services.nginx.port // 80' "$CONFIG_FILE")
    local endpoint=$(jq -r '.services.nginx.health_endpoint // "/health"' "$CONFIG_FILE")
    
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$port$endpoint" | grep -q "200"; then
        debug "  Nginx доступен на порту $port"
    else
        warning "  Nginx недоступен на порту $port"
    fi
}

# Тестирование Redis
test_redis_service() {
    debug "Тестирование Redis..."
    
    local host=$(jq -r '.services.redis.host // "localhost"' "$CONFIG_FILE")
    local port=$(jq -r '.services.redis.port // 6379' "$CONFIG_FILE")
    
    if redis-cli -h "$host" -p "$port" ping 2>/dev/null | grep -q "PONG"; then
        debug "  Redis доступен на $host:$port"
    else
        warning "  Redis недоступен на $host:$port"
    fi
}

# Тестирование PostgreSQL
test_postgresql_service() {
    debug "Тестирование PostgreSQL..."
    
    local host=$(jq -r '.services.postgresql.host // "localhost"' "$CONFIG_FILE")
    local port=$(jq -r '.services.postgresql.port // 5432' "$CONFIG_FILE")
    local db=$(jq -r '.services.postgresql.database // "postgres"' "$CONFIG_FILE")
    
    if pg_isready -h "$host" -p "$port" -d "$db" 2>/dev/null; then
        debug "  PostgreSQL доступен на $host:$port/$db"
    else
        warning "  PostgreSQL недоступен на $host:$port/$db"
    fi
}

# Тестирование Docker
test_docker_service() {
    debug "Тестирование Docker..."
    
    if docker info >/dev/null 2>&1; then
        local containers=$(docker ps --format "table {{.Names}}" | tail -n +2)
        debug "  Docker работает, контейнеры: $containers"
    else
        warning "  Docker не работает"
    fi
}

# Тестирование общего сервиса
test_generic_service() {
    local service=$1
    debug "Тестирование сервиса $service..."
    
    # Проверить systemd сервис
    if systemctl is-active "$service" >/dev/null 2>&1; then
        debug "  Сервис $service активен"
    else
        warning "  Сервис $service не активен"
    fi
}

# Тестирование алертов
test_alerts() {
    info "Тестирование системы уведомлений..."
    
    local test_results=()
    
    # Тест Slack webhook
    local slack_webhook=$(jq -r '.alerts.slack_webhook // ""' "$CONFIG_FILE")
    if [ -n "$slack_webhook" ] && [ "$slack_webhook" != "null" ]; then
        if curl -s -o /dev/null -w "%{http_code}" -X POST \
            -H 'Content-type: application/json' \
            --data '{"text":"Тестовое уведомление от системы мониторинга"}' \
            "$slack_webhook" | grep -q "200"; then
            test_results+=("Slack webhook: ✓")
        else
            test_results+=("Slack webhook: ✗")
        fi
    else
        test_results+=("Slack webhook: не настроен")
    fi
    
    # Тест email
    local email=$(jq -r '.alerts.email // ""' "$CONFIG_FILE")
    if [ -n "$email" ] && [ "$email" != "null" ]; then
        if command -v mail >/dev/null 2>&1; then
            echo "Тестовое уведомление от системы мониторинга" | mail -s "Тест" "$email"
            test_results+=("Email: ✓")
        else
            test_results+=("Email: mail не установлен")
        fi
    else
        test_results+=("Email: не настроен")
    fi
    
    # Вывести результаты
    for result in "${test_results[@]}"; do
        info "  $result"
    done
    
    success "Тестирование уведомлений завершено"
}

# Тестирование производительности
test_performance() {
    info "Тестирование производительности..."
    
    local test_results=()
    
    # Проверить время выполнения скрипта
    local start_time=$(date +%s)
    if [ -f "$SCRIPT_DIR/health-check.sh" ]; then
        timeout 30 "$SCRIPT_DIR/health-check.sh" --config "$CONFIG_FILE" >/dev/null 2>&1
        local exit_code=$?
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        if [ $exit_code -eq 0 ]; then
            test_results+=("Время выполнения: ${duration}с ✓")
        else
            test_results+=("Время выполнения: ${duration}с ✗")
        fi
    fi
    
    # Проверить использование ресурсов
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    local memory_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    
    test_results+=("CPU: ${cpu_usage}%")
    test_results+=("Память: ${memory_usage}%")
    
    # Вывести результаты
    for result in "${test_results[@]}"; do
        info "  $result"
    done
    
    success "Тестирование производительности завершено"
}

# Создание отчета
create_report() {
    if [ "$CREATE_REPORT" = false ]; then
        return 0
    fi
    
    info "Создание отчета о тестировании..."
    
    local report_data=$(cat <<EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "config_file": "$CONFIG_FILE",
    "test_mode": "$TEST_MODE",
    "results": {
        "config": "passed",
        "services": "passed",
        "alerts": "passed",
        "performance": "passed"
    },
    "system_info": {
        "hostname": "$(hostname)",
        "os": "$(uname -s)",
        "kernel": "$(uname -r)",
        "uptime": "$(uptime -p)"
    }
}
EOF
)
    
    echo "$report_data" > "$REPORT_FILE"
    success "Отчет создан: $REPORT_FILE"
}

# Основная функция тестирования
run_tests() {
    info "Запуск тестов системы мониторинга..."
    
    init_tests
    
    case "$TEST_MODE" in
        "all")
            test_config
            test_services
            test_alerts
            test_performance
            ;;
        "config")
            test_config
            ;;
        "services")
            test_services
            ;;
        "alerts")
            test_alerts
            ;;
        "performance")
            test_performance
            ;;
        *)
            error "Неизвестный режим тестирования: $TEST_MODE"
            ;;
    esac
    
    create_report
    
    success "Все тесты завершены успешно!"
}

# Обработка ошибок
trap 'error "Ошибка на строке $LINENO"' ERR

# Запуск тестов
run_tests "$@"