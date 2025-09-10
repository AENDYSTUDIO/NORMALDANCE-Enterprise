#!/bin/bash

# Скрипт удаленного деплоя audio-streaming стека
# Автоматический деплой на удаленные серверы с поддержкой нескольких окружений

set -e

# Конфигурация
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_DIR/config/remote-deploy.json"
ENV_FILE="$PROJECT_DIR/.env"
LOG_FILE="$PROJECT_DIR/logs/remote-deploy.log"
DEPLOY_CONFIG="$PROJECT_DIR/config/deploy-config.json"

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
        "DEPLOY")
            echo -e "${PURPLE}[$timestamp] $message${NC}"
            ;;
    esac
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
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

deploy() {
    log "DEPLOY" "$@"
}

# Показать справку
show_help() {
    cat <<EOF
Скрипт удаленного деплоя audio-streaming стека

Использование: $0 [command] [environment] [options]

Команды:
    deploy          Деплой на указанное окружение
    status          Проверка статуса окружений
    logs            Просмотр логов с удаленных серверов
    backup          Создание резервной копии на удаленных серверах
    restore         Восстановление из резервной копии
    rollback        Откат на удаленных серверах
    cleanup         Очистка на удаленных серверах
    sync            Синхронизация конфигурации
    test            Запуск тестов на удаленных серверах
    help            Показать эту справку

Окружения:
    production      Продакшен окружение
    staging         Стаджинг окружение
    development     Разработка
    all             Все окружения

Опции:
    --server <host>     Указать конкретный сервер
    --user <user>       Имя пользователя для SSH
    --key <file>        SSH ключ
    --port <port>       SSH порт
    --dry-run          Показать что будет сделано
    --force            Принудительный деплой
    --skip-tests       Пропустить тесты
    --skip-backup      Пропустить резервное копирование
    --verbose, -v      Подробный вывод
    --quiet, -q        Тихий режим

Примеры:
    $0 deploy production                    # Деплой в продакшен
    $0 deploy staging --dry-run             # Показать что будет сделано для стаджинга
    $0 status all                           # Проверка статуса всех окружений
    $0 logs production --server prod-01     # Просмотр логов с конкретного сервера
    $0 backup production                    # Резервное копирование продакшена
    $0 rollback production --backup 2024-09-04_14-30-00

EOF
}

# Загрузка конфигурации
load_config() {
    local env=$1
    
    if [ ! -f "$DEPLOY_CONFIG" ]; then
        error "Файл конфигурации деплоя не найден: $DEPLOY_CONFIG"
    fi
    
    # Парсинг JSON конфигурации
    local servers=$(jq -r ".environments.$env.servers[]" "$DEPLOY_CONFIG")
    local user=$(jq -r ".environments.$env.user" "$DEPLOY_CONFIG")
    local key=$(jq -r ".environments.$env.key" "$DEPLOY_CONFIG")
    local port=$(jq -r ".environments.$env.port" "$DEPLOY_CONFIG")
    local path=$(jq -r ".environments.$env.path" "$DEPLOY_CONFIG")
    
    if [ -z "$servers" ]; then
        error "Окружение не найдено: $env"
    fi
    
    echo "$servers|$user|$key|$port|$path"
}

# Проверка SSH соединения
check_ssh_connection() {
    local server=$1
    local user=$2
    local key=$3
    local port=$4
    
    deploy "Проверка SSH соединения с $user@$server:$port..."
    
    if ! ssh -i "$key" -p "$port" -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$user@$server" "echo 'SSH connection OK'"; then
        error "Не удалось подключиться к $user@$server:$port"
    fi
    
    success "SSH соединение установлено: $user@$server:$port"
}

# Синхронизация файлов
sync_files() {
    local server=$1
    local user=$2
    local key=$3
    local port=$4
    local remote_path=$5
    
    deploy "Синхронизация файлов на $server..."
    
    # Исключения для rsync
    local exclude_list=(
        ".git"
        "node_modules"
        "logs"
        "data"
        "backups"
        "*.log"
        "*.tmp"
        ".DS_Store"
    )
    
    local exclude_args=""
    for item in "${exclude_list[@]}"; do
        exclude_args="$exclude_args --exclude=$item"
    done
    
    # Синхронизация
    rsync -avz --delete \
        -e "ssh -i $key -p $port -o StrictHostKeyChecking=no" \
        $exclude_args \
        "$PROJECT_DIR/" \
        "$user@$server:$remote_path/"
    
    success "Файлы синхронизированы на $server"
}

# Удаленное выполнение команд
remote_exec() {
    local server=$1
    local user=$2
    local key=$3
    local port=$4
    local command=$5
    
    deploy "Выполнение команды на $server: $command"
    
    ssh -i "$key" -p "$port" -o StrictHostKeyChecking=no "$user@$server" "cd $(dirname "$5") && $command"
}

# Деплой на сервер
deploy_server() {
    local server=$1
    local user=$2
    local key=$3
    local port=$4
    local remote_path=$5
    
    deploy "Деплой на сервер $server..."
    
    # Проверка соединения
    check_ssh_connection "$server" "$user" "$key" "$port"
    
    # Создание директории
    remote_exec "$server" "$user" "$key" "$port" "mkdir -p $remote_path"
    
    # Синхронизация файлов
    sync_files "$server" "$user" "$key" "$port" "$remote_path"
    
    # Установка зависимостей
    remote_exec "$server" "$user" "$key" "$port" "cd $remote_path && ./scripts/setup-dependencies.sh"
    
    # Резервное копирование
    if [ "$SKIP_BACKUP" != "true" ]; then
        remote_exec "$server" "$user" "$key" "$port" "cd $remote_path && ./scripts/backup-monitoring.sh"
    fi
    
    # Деплой
    remote_exec "$server" "$user" "$key" "$port" "cd $remote_path && ./scripts/deploy-full-stack.sh full --skip-tests=$SKIP_TESTS"
    
    # Проверка деплоя
    remote_exec "$server" "$user" "$key" "$port" "cd $remote_path && ./scripts/deploy-full-stack.sh verify"
    
    success "Деплой завершен на сервере $server"
}

# Проверка статуса сервера
check_server_status() {
    local server=$1
    local user=$2
    local key=$3
    local port=$4
    local remote_path=$5
    
    deploy "Проверка статуса сервера $server..."
    
    if check_ssh_connection "$server" "$user" "$key" "$port"; then
        remote_exec "$server" "$user" "$key" "$port" "cd $remote_path && ./scripts/status.sh"
    else
        warning "Сервер недоступен: $server"
    fi
}

# Просмотр логов
view_logs() {
    local server=$1
    local user=$2
    local key=$3
    local port=$4
    local remote_path=$5
    local service=$6
    
    deploy "Просмотр логов на $server..."
    
    if [ -n "$service" ]; then
        remote_exec "$server" "$user" "$key" "$port" "cd $remote_path && docker-compose logs --tail=100 -f $service"
    else
        remote_exec "$server" "$user" "$key" "$port" "cd $remote_path && ./scripts/logs.sh"
    fi
}

# Создание резервной копии
create_remote_backup() {
    local server=$1
    local user=$2
    local key=$3
    local port=$4
    local remote_path=$5
    
    deploy "Создание резервной копии на $server..."
    
    remote_exec "$server" "$user" "$key" "$port" "cd $remote_path && ./scripts/backup-monitoring.sh"
    success "Резервная копия создана на $server"
}

# Восстановление из резервной копии
restore_remote_backup() {
    local server=$1
    local user=$2
    local key=$3
    local port=$4
    local remote_path=$5
    local backup_file=$6
    
    deploy "Восстановление из резервной копии на $server..."
    
    if [ -n "$backup_file" ]; then
        remote_exec "$server" "$user" "$key" "$port" "cd $remote_path && ./scripts/restore-monitoring.sh $backup_file"
    else
        remote_exec "$server" "$user" "$key" "$port" "cd $remote_path && ./scripts/restore-monitoring.sh"
    fi
    
    success "Восстановление завершено на $server"
}

# Откат на сервере
rollback_server() {
    local server=$1
    local user=$2
    local key=$3
    local port=$4
    local remote_path=$5
    local backup_file=$6
    
    deploy "Откат на сервере $server..."
    
    if [ -n "$backup_file" ]; then
        remote_exec "$server" "$user" "$key" "$port" "cd $remote_path && ./scripts/rollback.sh $backup_file"
    else
        remote_exec "$server" "$user" "$key" "$port" "cd $remote_path && ./scripts/rollback.sh"
    fi
    
    success "Откат завершен на $server"
}

# Очистка на сервере
cleanup_server() {
    local server=$1
    local user=$2
    local key=$3
    local port=$4
    local remote_path=$5
    
    deploy "Очистка на сервере $server..."
    
    remote_exec "$server" "$user" "$key" "$port" "cd $remote_path && ./scripts/deploy-full-stack.sh cleanup"
    success "Очистка завершена на $server"
}

# Запуск тестов
run_remote_tests() {
    local server=$1
    local user=$2
    local key=$3
    local port=$4
    local remote_path=$5
    
    deploy "Запуск тестов на $server..."
    
    remote_exec "$server" "$user" "$key" "$port" "cd $remote_path && ./scripts/test-health-monitoring.sh"
    success "Тесты завершены на $server"
}

# Деплой на окружение
deploy_environment() {
    local env=$1
    
    deploy "Деплой на окружение: $env"
    
    local config=$(load_config "$env")
    IFS='|' read -r servers user key port path <<< "$config"
    
    for server in $servers; do
        deploy "Обработка сервера: $server"
        
        if [ -n "$SPECIFIC_SERVER" ] && [ "$SPECIFIC_SERVER" != "$server" ]; then
            deploy "Пропуск сервера: $server"
            continue
        fi
        
        deploy_server "$server" "$user" "$key" "$port" "$path"
    done
    
    success "Деплой завершен для окружения: $env"
}

# Проверка статуса окружения
check_environment_status() {
    local env=$1
    
    deploy "Проверка статуса окружения: $env"
    
    local config=$(load_config "$env")
    IFS='|' read -r servers user key port path <<< "$config"
    
    for server in $servers; do
        if [ -n "$SPECIFIC_SERVER" ] && [ "$SPECIFIC_SERVER" != "$server" ]; then
            continue
        fi
        
        check_server_status "$server" "$user" "$key" "$port" "$path"
    done
}

# Главная функция
main() {
    local command=${1:-deploy}
    local environment=${2:-production}
    local specific_server=""
    local ssh_user=""
    local ssh_key=""
    local ssh_port=22
    local dry_run=false
    local force=false
    local skip_tests=false
    local skip_backup=false
    local verbose=false
    local quiet=false
    
    # Обработка аргументов
    while [[ $# -gt 0 ]]; do
        case $1 in
            --server)
                specific_server="$2"
                shift 2
                ;;
            --user)
                ssh_user="$2"
                shift 2
                ;;
            --key)
                ssh_key="$2"
                shift 2
                ;;
            --port)
                ssh_port="$2"
                shift 2
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            --skip-tests)
                skip_tests=true
                shift
                ;;
            --skip-backup)
                skip_backup=true
                shift
                ;;
            --verbose|-v)
                verbose=true
                shift
                ;;
            --quiet|-q)
                quiet=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                shift
                ;;
        esac
    done
    
    # Экспорт переменных
    export SPECIFIC_SERVER="$specific_server"
    export SSH_USER="$ssh_user"
    export SSH_KEY="$ssh_key"
    export SSH_PORT="$ssh_port"
    export SKIP_TESTS="$skip_tests"
    export SKIP_BACKUP="$skip_backup"
    export VERBOSE="$verbose"
    export QUIET="$quiet"
    
    # Режим dry-run
    if [ "$dry_run" = true ]; then
        deploy "Режим dry-run - показать что будет сделано:"
        deploy "Команда: $command"
        deploy "Окружение: $environment"
        deploy "Сервер: ${specific_server:-все}"
        return 0
    fi
    
    # Выполнение команды
    case "$command" in
        deploy)
            deploy_environment "$environment"
            ;;
        status)
            check_environment_status "$environment"
            ;;
        logs)
            if [ -n "$specific_server" ]; then
                local config=$(load_config "$environment")
                IFS='|' read -r servers user key port path <<< "$config"
                view_logs "$specific_server" "$user" "$key" "$port" "$path" "$3"
            else
                deploy "Укажите сервер для просмотра логов: --server <host>"
            fi
            ;;
        backup)
            if [ "$environment" = "all" ]; then
                for env in production staging development; do
                    deploy "Создание резервной копии для $env"
                    local config=$(load_config "$env")
                    IFS='|' read -r servers user key port path <<< "$config"
                    for server in $servers; do
                        create_remote_backup "$server" "$user" "$key" "$port" "$path"
                    done
                done
            else
                local config=$(load_config "$environment")
                IFS='|' read -r servers user key port path <<< "$config"
                for server in $servers; do
                    create_remote_backup "$server" "$user" "$key" "$port" "$path"
                done
            fi
            ;;
        restore)
            if [ "$environment" = "all" ]; then
                error "Укажите конкретное окружение для восстановления"
            else
                local config=$(load_config "$environment")
                IFS='|' read -r servers user key port path <<< "$config"
                for server in $servers; do
                    restore_remote_backup "$server" "$user" "$key" "$port" "$path" "$3"
                done
            fi
            ;;
        rollback)
            if [ "$environment" = "all" ]; then
                error "Укажите конкретное окружение для отката"
            else
                local config=$(load_config "$environment")
                IFS='|' read -r servers user key port path <<< "$config"
                for server in $servers; do
                    rollback_server "$server" "$user" "$key" "$port" "$path" "$3"
                done
            fi
            ;;
        cleanup)
            if [ "$environment" = "all" ]; then
                for env in production staging development; do
                    deploy "Очистка для $env"
                    local config=$(load_config "$env")
                    IFS='|' read -r servers user key port path <<< "$config"
                    for server in $servers; do
                        cleanup_server "$server" "$user" "$key" "$port" "$path"
                    done
                done
            else
                local config=$(load_config "$environment")
                IFS='|' read -r servers user key port path <<< "$config"
                for server in $servers; do
                    cleanup_server "$server" "$user" "$key" "$port" "$path"
                done
            fi
            ;;
        test)
            if [ "$environment" = "all" ]; then
                error "Укажите конкретное окружение для тестов"
            else
                local config=$(load_config "$environment")
                IFS='|' read -r servers user key port path <<< "$config"
                for server in $servers; do
                    run_remote_tests "$server" "$user" "$key" "$port" "$path"
                done
            fi
            ;;
        sync)
            if [ "$environment" = "all" ]; then
                for env in production staging development; do
                    deploy "Синхронизация для $env"
                    local config=$(load_config "$env")
                    IFS='|' read -r servers user key port path <<< "$config"
                    for server in $servers; do
                        sync_files "$server" "$user" "$key" "$port" "$path"
                    done
                done
            else
                local config=$(load_config "$environment")
                IFS='|' read -r servers user key port path <<< "$config"
                for server in $servers; do
                    sync_files "$server" "$user" "$key" "$port" "$path"
                done
            fi
            ;;
        help)
            show_help
            ;;
        *)
            show_help
            ;;
    esac
}

# Запуск
main "$@"