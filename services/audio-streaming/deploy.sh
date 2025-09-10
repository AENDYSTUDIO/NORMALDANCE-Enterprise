#!/bin/bash

# Скрипт деплоя аудио-стриминг сервиса
# Использование: ./deploy.sh [environment] [action]

set -e

# Конфигурация
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENVIRONMENT=${1:-production}
ACTION=${2:-deploy}
REMOTE_HOST="176.108.246.49"
REMOTE_USER="aendy"
PROJECT_NAME="audio-streaming"
PROJECT_DIR="/home/${REMOTE_USER}/${PROJECT_NAME}"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Логирование
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

# Проверка зависимостей
check_dependencies() {
    log "Проверка зависимостей..."
    
    if ! command -v ssh &> /dev/null; then
        error "SSH не установлен"
        exit 1
    fi
    
    if ! command -v rsync &> /dev/null; then
        error "rsync не установлен"
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        error "Docker не установлен"
        exit 1
    fi
    
    log "Все зависимости проверены"
}

# Проверка подключения к серверу
check_connection() {
    log "Проверка подключения к серверу..."
    
    if ! ssh -o ConnectTimeout=10 ${REMOTE_USER}@${REMOTE_HOST} "echo 'Connection successful'"; then
        error "Не удалось подключиться к серверу ${REMOTE_HOST}"
        exit 1
    fi
    
    log "Подключение к серверу установлено"
}

# Создание структуры директорий
create_directories() {
    log "Создание структуры директорий..."
    
    ssh ${REMOTE_USER}@${REMOTE_HOST} "
        mkdir -p ${PROJECT_DIR}/{logs,streams/{temp,segments,cache},config,nginx/{sites-available,ssl},prometheus,grafana/provisioning}
    "
    
    log "Структура директорий создана"
}

# Копирование файлов проекта
copy_files() {
    log "Копирование файлов проекта..."
    
    # Исключаем ненужные файлы
    rsync -avz --delete \
        --exclude='.git' \
        --exclude='node_modules' \
        --exclude='logs' \
        --exclude='streams' \
        --exclude='.env' \
        --exclude='*.log' \
        --exclude='coverage' \
        --exclude='.DS_Store' \
        ${SCRIPT_DIR}/ ${REMOTE_USER}@${REMOTE_HOST}:${PROJECT_DIR}/
    
    log "Файлы проекта скопированы"
}

# Установка SSL сертификатов
setup_ssl() {
    log "Настройка SSL сертификатов..."
    
    # Проверяем наличие сертификатов
    if [ -f "${SCRIPT_DIR}/nginx/ssl/dnb1st.ru.crt" ] && [ -f "${SCRIPT_DIR}/nginx/ssl/dnb1st.ru.key" ]; then
        log "SSL сертификаты уже существуют"
    else
        warning "SSL сертификаты не найдены. Создаем самоподписанные сертификаты..."
        
        ssh ${REMOTE_USER}@${REMOTE_HOST} "
            cd ${PROJECT_DIR}/nginx/ssl
            openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
                -keyout dnb1st.ru.key \
                -out dnb1st.ru.crt \
                -subj '/C=RU/ST=Moscow/L=Moscow/O=DNB1ST/CN=dnb1st.ru'
        "
    fi
    
    log "SSL сертификаты настроены"
}

# Настройка окружения
setup_environment() {
    log "Настройка окружения..."
    
    # Копируем .env.example в .env если не существует
    ssh ${REMOTE_USER}@${REMOTE_HOST} "
        cd ${PROJECT_DIR}
        if [ ! -f .env ]; then
            cp .env.example .env
            echo 'Файл .env создан из .env.example'
        fi
    "
    
    log "Окружение настроено"
}

# Запуск сервисов
start_services() {
    log "Запуск сервисов..."
    
    ssh ${REMOTE_USER}@${REMOTE_HOST} "
        cd ${PROJECT_DIR}
        
        # Останавливаем старые контейнеры
        docker-compose down
        
        # Пересобираем образы
        docker-compose build --no-cache
        
        # Запускаем сервисы
        docker-compose up -d
        
        # Ждем запуска
        sleep 10
        
        # Проверяем статус
        docker-compose ps
        
        # Проверяем логи
        docker-compose logs --tail=50
    "
    
    log "Сервисы запущены"
}

# Проверка деплоя
verify_deployment() {
    log "Проверка деплоя..."
    
    # Проверяем health check
    if curl -f -s "https://${REMOTE_HOST}/health" > /dev/null; then
        log "Health check пройден успешно"
    else
        error "Health check не пройден"
        exit 1
    fi
    
    # Проверяем WebSocket
    if curl -f -s "https://${REMOTE_HOST}/socket.io/" > /dev/null; then
        log "WebSocket доступен"
    else
        warning "WebSocket может быть недоступен"
    fi
    
    log "Деплой успешно завершен"
}

# Остановка сервисов
stop_services() {
    log "Остановка сервисов..."
    
    ssh ${REMOTE_USER}@${REMOTE_HOST} "
        cd ${PROJECT_DIR}
        docker-compose down
    "
    
    log "Сервисы остановлены"
}

# Перезапуск сервисов
restart_services() {
    log "Перезапуск сервисов..."
    
    ssh ${REMOTE_USER}@${REMOTE_HOST} "
        cd ${PROJECT_DIR}
        docker-compose restart
    "
    
    log "Сервисы перезапущены"
}

# Просмотр логов
show_logs() {
    log "Просмотр логов..."
    
    ssh ${REMOTE_USER}@${REMOTE_HOST} "
        cd ${PROJECT_DIR}
        docker-compose logs -f --tail=100
    "
}

# Главная функция
main() {
    log "Начало деплоя ${PROJECT_NAME} в окружение ${ENVIRONMENT}"
    
    case ${ACTION} in
        "deploy")
            check_dependencies
            check_connection
            create_directories
            copy_files
            setup_ssl
            setup_environment
            start_services
            verify_deployment
            ;;
        "stop")
            stop_services
            ;;
        "restart")
            restart_services
            ;;
        "logs")
            show_logs
            ;;
        "verify")
            verify_deployment
            ;;
        *)
            echo "Использование: $0 [environment] [action]"
            echo "Actions: deploy, stop, restart, logs, verify"
            echo "Environments: production, staging, development"
            exit 1
            ;;
    esac
    
    log "Операция ${ACTION} завершена успешно"
}

# Запуск
main "$@"