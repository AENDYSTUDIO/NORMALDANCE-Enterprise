#!/bin/bash

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Проверка наличия необходимых переменных окружения
check_env_vars() {
    echo -e "${YELLOW}Проверка переменных окружения...${NC}"
    
    required_vars=(
        "POSTGRES_USER"
        "POSTGRES_PASSWORD"
        "REDIS_PASSWORD"
        "GRAFANA_PASSWORD"
        "SMTP_USERNAME"
        "SMTP_PASSWORD"
        "SLACK_WEBHOOK_URL"
    )
    
    missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -ne 0 ]; then
        echo -e "${RED}Отсутствуют обязательные переменные окружения:${NC}"
        printf '%s\n' "${missing_vars[@]}"
        exit 1
    fi
    
    echo -e "${GREEN}Все переменные окружения установлены${NC}"
}

# Создание сети для мониторинга
create_networks() {
    echo -e "${YELLOW}Создание сетей Docker...${NC}"
    
    # Создание сети audio-streaming если не существует
    if ! docker network ls | grep -q "audio-streaming"; then
        docker network create audio-streaming
        echo -e "${GREEN}Создана сеть audio-streaming${NC}"
    else
        echo -e "${GREEN}Сеть audio-streaming уже существует${NC}"
    fi
    
    echo -e "${GREEN}Сети Docker готовы${NC}"
}

# Проверка и создание директорий
create_directories() {
    echo -e "${YELLOW}Создание директорий для данных...${NC}"
    
    directories=(
        "config/prometheus/rules"
        "config/grafana/dashboards"
        "config/grafana/provisioning/dashboards"
        "config/grafana/provisioning/datasources"
    )
    
    for dir in "${directories[@]}"; do
        mkdir -p "$dir"
    done
    
    echo -e "${GREEN}Директории созданы${NC}"
}

# Запуск мониторинга
deploy_monitoring() {
    echo -e "${YELLOW}Запуск системы мониторинга...${NC}"
    
    # Остановка существующих контейнеров мониторинга
    docker-compose -f docker-compose.monitoring.yml down
    
    # Очистка старых данных (опционально)
    if [ "$1" == "--clean" ]; then
        echo -e "${YELLOW}Очистка старых данных...${NC}"
        docker volume rm audio-streaming_prometheus_data audio-streaming_grafana_data audio-streaming_loki_data audio-streaming_alertmanager_data 2>/dev/null || true
    fi
    
    # Запуск контейнеров
    docker-compose -f docker-compose.monitoring.yml up -d
    
    echo -e "${GREEN}Система мониторинга запущена${NC}"
}

# Проверка состояния сервисов
check_services() {
    echo -e "${YELLOW}Проверка состояния сервисов...${NC}"
    
    services=("prometheus" "grafana" "loki" "promtail" "alertmanager" "node-exporter" "cadvisor")
    
    for service in "${services[@]}"; do
        if docker ps | grep -q "$service"; then
            echo -e "${GREEN}✓ $service запущен${NC}"
        else
            echo -e "${RED}✗ $service не запущен${NC}"
        fi
    done
}

# Настройка Grafana
setup_grafana() {
    echo -e "${YELLOW}Настройка Grafana...${NC}"
    
    # Ожидание запуска Grafana
    echo -e "${YELLOW}Ожидание запуска Grafana...${NC}"
    sleep 30
    
    # Импорт дашбордов (если есть)
    if [ -d "config/grafana/dashboards" ]; then
        echo -e "${GREEN}Дашборды Grafana готовы к импорту${NC}"
    fi
    
    echo -e "${GREEN}Grafana доступна по адресу: http://localhost:3000${NC}"
    echo -e "${GREEN}Логин: admin${NC}"
    echo -e "${GREEN}Пароль: ${GRAFANA_PASSWORD}${NC}"
}

# Проверка алертов
check_alerts() {
    echo -e "${YELLOW}Проверка алертов...${NC}"
    
    # Проверка доступности Alertmanager
    if curl -s http://localhost:9093/api/v1/status | grep -q "success"; then
        echo -e "${GREEN}Alertmanager доступен${NC}"
    else
        echo -e "${RED}Alertmanager недоступен${NC}"
    fi
    
    # Проверка правил алертов в Prometheus
    if curl -s http://localhost:9090/api/v1/rules | grep -q "audio-streaming"; then
        echo -e "${GREEN}Правила алертов загружены${NC}"
    else
        echo -e "${RED}Правила алертов не загружены${NC}"
    fi
}

# Главная функция
main() {
    echo -e "${GREEN}=== Развертывание системы мониторинга Audio Streaming ===${NC}"
    
    # Переход в директорию с проектом
    cd "$(dirname "$0")/.."
    
    # Загрузка переменных окружения
    if [ -f .env ]; then
        source .env
    fi
    
    check_env_vars
    create_networks
    create_directories
    deploy_monitoring "$1"
    
    echo -e "${YELLOW}Ожидание запуска сервисов...${NC}"
    sleep 10
    
    check_services
    setup_grafana
    check_alerts
    
    echo -e "${GREEN}=== Система мониторинга успешно развернута ===${NC}"
    echo -e "${GREEN}Ссылки:${NC}"
    echo -e "${GREEN}  Grafana: http://localhost:3000${NC}"
    echo -e "${GREEN}  Prometheus: http://localhost:9090${NC}"
    echo -e "${GREEN}  Alertmanager: http://localhost:9093${NC}"
}

# Обработка аргументов
case "$1" in
    --clean)
        main --clean
        ;;
    *)
        main
        ;;
esac