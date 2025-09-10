#!/bin/bash

# Скрипт установки зависимостей для audio-streaming стека
# Поддерживает Ubuntu/Debian и CentOS/RHEL

set -e

# Конфигурация
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$PROJECT_DIR/logs/setup-dependencies.log"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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
    esac
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

error() {
    log "ERROR" "$@"
    exit 1
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

# Определение ОС
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VERSION=$VERSION_ID
        ID=$ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
        VERSION=$(lsb_release -sr)
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        OS=$DISTRIB_ID
        VERSION=$DISTRIB_RELEASE
    elif [ -f /etc/debian_version ]; then
        OS="Debian"
        VERSION=$(cat /etc/debian_version)
    elif [ -f /etc/redhat-release ]; then
        OS="RedHat"
        VERSION=$(cat /etc/redhat-release)
    else
        error "Не удалось определить операционную систему"
    fi
    
    log "INFO" "ОС: $OS $VERSION"
}

# Обновление системы
update_system() {
    log "INFO" "Обновление системы..."
    
    case "$ID" in
        ubuntu|debian)
            sudo apt update && sudo apt upgrade -y
            ;;
        centos|rhel|fedora)
            if command -v dnf &> /dev/null; then
                sudo dnf update -y
            else
                sudo yum update -y
            fi
            ;;
        *)
            error "Неподдерживаемая ОС: $ID"
            ;;
    esac
    
    log "INFO" "Система обновлена"
}

# Установка базовых утилит
install_base_utils() {
    log "INFO" "Установка базовых утилит..."
    
    case "$ID" in
        ubuntu|debian)
            sudo apt install -y \
                curl \
                wget \
                git \
                unzip \
                tar \
                jq \
                htop \
                vim \
                nano \
                net-tools \
                lsof \
                tree \
                rsync \
                cron \
                logrotate
            ;;
        centos|rhel|fedora)
            if command -v dnf &> /dev/null; then
                sudo dnf install -y \
                    curl \
                    wget \
                    git \
                    unzip \
                    tar \
                    jq \
                    htop \
                    vim \
                    nano \
                    net-tools \
                    lsof \
                    tree \
                    rsync \
                    cronie \
                    logrotate
            else
                sudo yum install -y \
                    curl \
                    wget \
                    git \
                    unzip \
                    tar \
                    jq \
                    htop \
                    vim \
                    nano \
                    net-tools \
                    lsof \
                    tree \
                    rsync \
                    cronie \
                    logrotate
            fi
            ;;
    esac
    
    log "INFO" "Базовые утилиты установлены"
}

# Установка Docker
install_docker() {
    log "INFO" "Установка Docker..."
    
    if command -v docker &> /dev/null; then
        log "INFO" "Docker уже установлен"
        docker --version
        return
    fi
    
    case "$ID" in
        ubuntu|debian)
            # Удаление старых версий
            sudo apt remove -y docker docker-engine docker.io containerd runc || true
            
            # Установка зависимостей
            sudo apt install -y \
                ca-certificates \
                gnupg \
                lsb-release
            
            # Добавление репозитория Docker
            sudo mkdir -p /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/$ID/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            
            echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$ID \
                $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            sudo apt update
            sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
        centos|rhel|fedora)
            if command -v dnf &> /dev/null; then
                sudo dnf install -y dnf-plugins-core
                sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
                sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            else
                sudo yum install -y yum-utils
                sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
                sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            fi
            ;;
    esac
    
    # Запуск Docker
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Добавление пользователя в группу docker
    sudo usermod -aG docker $USER
    
    log "INFO" "Docker установлен успешно"
}

# Установка Docker Compose
install_docker_compose() {
    log "INFO" "Установка Docker Compose..."
    
    if command -v docker-compose &> /dev/null; then
        log "INFO" "Docker Compose уже установлен"
        docker-compose --version
        return
    fi
    
    # Установка через pip (альтернативный способ)
    if ! command -v pip3 &> /dev/null; then
        log "INFO" "Установка Python3 и pip..."
        case "$ID" in
            ubuntu|debian)
                sudo apt install -y python3 python3-pip
                ;;
            centos|rhel|fedora)
                if command -v dnf &> /dev/null; then
                    sudo dnf install -y python3 python3-pip
                else
                    sudo yum install -y python3 python3-pip
                fi
                ;;
        esac
    fi
    
    sudo pip3 install docker-compose
    
    log "INFO" "Docker Compose установлен"
}

# Установка Node.js
install_nodejs() {
    log "INFO" "Установка Node.js..."
    
    if command -v node &> /dev/null; then
        log "INFO" "Node.js уже установлен"
        node --version
        return
    fi
    
    # Использование NodeSource репозитория
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    
    case "$ID" in
        ubuntu|debian)
            sudo apt install -y nodejs
            ;;
        centos|rhel|fedora)
            if command -v dnf &> /dev/null; then
                sudo dnf install -y nodejs npm
            else
                sudo yum install -y nodejs npm
            fi
            ;;
    esac
    
    log "INFO" "Node.js установлен"
}

# Установка Nginx
install_nginx() {
    log "INFO" "Установка Nginx..."
    
    if command -v nginx &> /dev/null; then
        log "INFO" "Nginx уже установлен"
        nginx -v
        return
    fi
    
    case "$ID" in
        ubuntu|debian)
            sudo apt install -y nginx
            ;;
        centos|rhel|fedora)
            if command -v dnf &> /dev/null; then
                sudo dnf install -y nginx
            else
                sudo yum install -y nginx
            fi
            ;;
    esac
    
    # Настройка Nginx
    sudo systemctl start nginx
    sudo systemctl enable nginx
    
    # Открытие портов
    case "$ID" in
        ubuntu|debian)
            if command -v ufw &> /dev/null; then
                sudo ufw allow 'Nginx Full'
            fi
            ;;
        centos|rhel|fedora)
            if command -v firewall-cmd &> /dev/null; then
                sudo firewall-cmd --permanent --add-service=http
                sudo firewall-cmd --permanent --add-service=https
                sudo firewall-cmd --reload
            fi
            ;;
    esac
    
    log "INFO" "Nginx установлен"
}

# Установка Certbot
install_certbot() {
    log "INFO" "Установка Certbot..."
    
    if command -v certbot &> /dev/null; then
        log "INFO" "Certbot уже установлен"
        return
    fi
    
    case "$ID" in
        ubuntu|debian)
            sudo apt install -y certbot python3-certbot-nginx
            ;;
        centos|rhel|fedora)
            if command -v dnf &> /dev/null; then
                sudo dnf install -y certbot python3-certbot-nginx
            else
                sudo yum install -y certbot python3-certbot-nginx
            fi
            ;;
    esac
    
    log "INFO" "Certbot установлен"
}

# Установка Prometheus
install_prometheus() {
    log "INFO" "Установка Prometheus..."
    
    local prometheus_version="2.45.0"
    local prometheus_dir="/opt/prometheus"
    
    if [ -d "$prometheus_dir" ]; then
        log "INFO" "Prometheus уже установлен"
        return
    fi
    
    # Создание пользователя
    sudo useradd --no-create-home --shell /bin/false prometheus
    
    # Создание директорий
    sudo mkdir -p "$prometheus_dir"
    sudo mkdir -p /etc/prometheus
    sudo mkdir -p /var/lib/prometheus
    
    # Загрузка и установка
    cd /tmp
    wget https://github.com/prometheus/prometheus/releases/download/v${prometheus_version}/prometheus-${prometheus_version}.linux-amd64.tar.gz
    tar xvf prometheus-${prometheus_version}.linux-amd64.tar.gz
    
    sudo cp prometheus-${prometheus_version}.linux-amd64/prometheus "$prometheus_dir/"
    sudo cp prometheus-${prometheus_version}.linux-amd64/promtool "$prometheus_dir/"
    sudo cp -r prometheus-${prometheus_version}.linux-amd64/consoles /etc/prometheus
    sudo cp -r prometheus-${prometheus_version}.linux-amd64/console_libraries /etc/prometheus
    
    # Настройка прав
    sudo chown -R prometheus:prometheus "$prometheus_dir"
    sudo chown -R prometheus:prometheus /etc/prometheus
    sudo chown -R prometheus:prometheus /var/lib/prometheus
    
    # Создание systemd сервиса
    sudo tee /etc/systemd/system/prometheus.service > /dev/null <<EOF
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=$prometheus_dir/prometheus \
    --config.file /etc/prometheus/prometheus.yml \
    --storage.tsdb.path /var/lib/prometheus/ \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
EOF
    
    # Очистка
    rm -rf prometheus-${prometheus_version}.linux-amd64*
    
    log "INFO" "Prometheus установлен"
}

# Установка Grafana
install_grafana() {
    log "INFO" "Установка Grafana..."
    
    if command -v grafana-server &> /dev/null; then
        log "INFO" "Grafana уже установлена"
        return
    fi
    
    case "$ID" in
        ubuntu|debian)
            sudo apt install -y software-properties-common
            wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
            echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list
            sudo apt update
            sudo apt install -y grafana
            ;;
        centos|rhel|fedora)
            if command -v dnf &> /dev/null; then
                sudo dnf install -y https://dl.grafana.com/oss/release/grafana-9.5.2-1.x86_64.rpm
            else
                sudo yum install -y https://dl.grafana.com/oss/release/grafana-9.5.2-1.x86_64.rpm
            fi
            ;;
    esac
    
    # Запуск Grafana
    sudo systemctl daemon-reload
    sudo systemctl start grafana-server
    sudo systemctl enable grafana-server
    
    log "INFO" "Grafana установлена"
}

# Установка всех зависимостей
install_all() {
    log "INFO" "Установка всех зависимостей..."
    
    detect_os
    update_system
    install_base_utils
    install_docker
    install_docker_compose
    install_nodejs
    install_nginx
    install_certbot
    install_prometheus
    install_grafana
    
    success "Все зависимости установлены"
}

# Показать справку
show_help() {
    cat <<EOF
Скрипт установки зависимостей для audio-streaming стека

Использование: $0 [options]

Опции:
    --all               Установить все зависимости
    --docker            Установить только Docker
    --docker-compose    Установить только Docker Compose
    --nodejs            Установить только Node.js
    --nginx             Установить только Nginx
    --certbot           Установить только Certbot
    --prometheus        Установить только Prometheus
    --grafana           Установить только Grafana
    --help              Показать эту справку

Примеры:
    $0 --all
    $0 --docker --nginx
    $0 --nodejs

EOF
}

# Главная функция
main() {
    # Создание директории для логов
    mkdir -p "$(dirname "$LOG_FILE")"
    
    log "INFO" "Запуск установки зависимостей..."
    
    if [ $# -eq 0 ]; then
        show_help
        exit 1
    fi
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --all)
                install_all
                exit 0
                ;;
            --docker)
                detect_os
                install_docker
                exit 0
                ;;
            --docker-compose)
                detect_os
                install_docker_compose
                exit 0
                ;;
            --nodejs)
                detect_os
                install_nodejs
                exit 0
                ;;
            --nginx)
                detect_os
                install_nginx
                exit 0
                ;;
            --certbot)
                detect_os
                install_certbot
                exit 0
                ;;
            --prometheus)
                install_prometheus
                exit 0
                ;;
            --grafana)
                detect_os
                install_grafana
                exit 0
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                show_help
                exit 1
                ;;
        esac
    done
}

# Запуск
main "$@"