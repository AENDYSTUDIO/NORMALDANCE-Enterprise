#!/bin/bash

# Скрипт полного деплоя audio-streaming сервиса
# Автоматически разворачивает все компоненты системы

set -e

# Конфигурация
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_DIR/.env"
CONFIG_FILE="$PROJECT_DIR/config/deploy-config.json"
BACKUP_DIR="$PROJECT_DIR/backups"
LOG_FILE="$PROJECT_DIR/logs/deploy.log"

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
    
    # Лог в файл
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

# Проверка требований
check_requirements() {
    info "Проверка требований..."
    
    local required_tools=("docker" "docker-compose" "jq" "curl" "openssl")
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            error "Необходимый инструмент не найден: $tool"
        fi
    done
    
    # Проверка Docker
    if ! docker info &> /dev/null; then
        error "Docker не запущен или недоступен"
    fi
    
    info "Все требования удовлетворены"
}

# Проверка .env файла
check_env_file() {
    if [ ! -f "$ENV_FILE" ]; then
        info "Файл .env не найден, запускаем настройку окружения..."
        chmod +x "$SCRIPT_DIR/setup-environment.sh"
        "$SCRIPT_DIR/setup-environment.sh" "$ENVIRONMENT"
    fi
    
    # Загрузка переменных окружения
    set -a
    source "$ENV_FILE"
    set +a
    
    info "Переменные окружения загружены"
}

# Создание директорий
create_directories() {
    info "Создание директорий..."
    
    local directories=(
        "logs/api"
        "logs/streaming"
        "logs/nginx"
        "config/nginx/sites-available"
        "config/nginx/sites-enabled"
        "config/ssl"
        "config/prometheus"
        "config/grafana/provisioning"
        "config/grafana/dashboards"
        "config/postgres"
        "media"
        "backups"
    )
    
    for dir in "${directories[@]}"; do
        mkdir -p "$PROJECT_DIR/$dir"
    done
    
    info "Директории созданы"
}

# Настройка SSL сертификатов
setup_ssl() {
    info "Настройка SSL сертификатов..."
    
    local ssl_dir="$PROJECT_DIR/config/ssl"
    local domain=$APP_DOMAIN
    
    # Создание директории для SSL
    mkdir -p "$ssl_dir"
    
    # Проверка существующих сертификатов
    if [ -f "$ssl_dir/fullchain.pem" ] && [ -f "$ssl_dir/privkey.pem" ]; then
        info "SSL сертификаты уже существуют"
        return 0
    fi
    
    # Проверка Let's Encrypt
    if command -v certbot &> /dev/null; then
        info "Используем Let's Encrypt для получения сертификатов..."
        
        # Остановка nginx если запущен
        if docker-compose ps | grep -q nginx; then
            docker-compose stop nginx
        fi
        
        # Получение сертификатов
        sudo certbot certonly --standalone \
            -d "$domain" \
            -d "www.$domain" \
            --email "admin@$domain" \
            --agree-tos \
            --non-interactive
        
        # Копирование сертификатов
        sudo cp "/etc/letsencrypt/live/$domain/fullchain.pem" "$ssl_dir/"
        sudo cp "/etc/letsencrypt/live/$domain/privkey.pem" "$ssl_dir/"
        sudo cp "/etc/letsencrypt/live/$domain/chain.pem" "$ssl_dir/"
        sudo cp "/etc/letsencrypt/live/$domain/cert.pem" "$ssl_dir/"
        
        # Установка прав
        sudo chown -R "$(whoami):$(whoami)" "$ssl_dir"
        chmod 600 "$ssl_dir"/*
        
        info "SSL сертификаты получены через Let's Encrypt"
    else
        info "Let's Encrypt не найден, создаем самоподписанные сертификаты..."
        
        # Создание самоподписанных сертификатов
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "$ssl_dir/privkey.pem" \
            -out "$ssl_dir/fullchain.pem" \
            -subj "/C=RU/ST=Moscow/L=Moscow/O=AudioStreaming/CN=$domain"
        
        info "Самоподписанные SSL сертификаты созданы"
    fi
}

# Настройка nginx
setup_nginx() {
    info "Настройка nginx..."
    
    local nginx_config="$PROJECT_DIR/config/nginx/sites-available/audio-streaming"
    
    cat > "$nginx_config" << EOF
# Audio Streaming Service Nginx Configuration
server {
    listen 80;
    server_name $APP_DOMAIN www.$APP_DOMAIN;
    
    # Redirect HTTP to HTTPS
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $APP_DOMAIN www.$APP_DOMAIN;
    
    # SSL Configuration
    ssl_certificate /etc/ssl/certs/fullchain.pem;
    ssl_certificate_key /etc/ssl/certs/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # Security Headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # Gzip Compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;
    
    # Rate Limiting
    limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone \$binary_remote_addr zone=streaming:10m rate=5r/s;
    
    # Client Configuration
    client_max_body_size 100M;
    client_body_timeout 60s;
    client_header_timeout 60s;
    
    # API Proxy
    location /api/ {
        limit_req zone=api burst=20 nodelay;
        
        proxy_pass http://api:3000/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_read_timeout 300s;
        proxy_connect_timeout 60s;
    }
    
    # Streaming Proxy
    location /stream/ {
        limit_req zone=streaming burst=10 nodelay;
        
        proxy_pass http://streaming:8080/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_read_timeout 300s;
        proxy_connect_timeout 60s;
        
        # Streaming-specific headers
        proxy_buffering off;
        proxy_request_buffering off;
    }
    
    # Health Check
    location /health {
        access_log off;
        return 200 "healthy\\n";
        add_header Content-Type text/plain;
    }
    
    # Static Files
    location /static/ {
        alias /app/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Root
    location / {
        proxy_pass http://api:3000/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF
    
    # Создание симлинка
    ln -sf "$nginx_config" "$PROJECT_DIR/config/nginx/sites-enabled/audio-streaming"
    
    info "Nginx настроен"
}

# Настройка Prometheus
setup_prometheus() {
    info "Настройка Prometheus..."
    
    local prometheus_config="$PROJECT_DIR/config/prometheus/prometheus.yml"
    
    cat > "$prometheus_config" << EOF
# Prometheus Configuration
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    monitor: 'audio-streaming'

rule_files:
  - "rules/*.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'api'
    static_configs:
      - targets: ['api:3000']
    metrics_path: '/metrics'
    scrape_interval: 30s

  - job_name: 'streaming'
    static_configs:
      - targets: ['streaming:8080']
    metrics_path: '/metrics'
    scrape_interval: 30s

  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres:5432']
    metrics_path: '/metrics'
    scrape_interval: 30s

  - job_name: 'redis'
    static_configs:
      - targets: ['redis:6379']
    metrics_path: '/metrics'
    scrape_interval: 30s

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
    scrape_interval: 30s

  - job_name: 'nginx'
    static_configs:
      - targets: ['nginx:80']
    metrics_path: '/metrics'
    scrape_interval: 30s

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093
EOF
    
    # Создание правил алертов
    local alerts_config="$PROJECT_DIR/config/prometheus/rules/audio-streaming.yml"
    
    cat > "$alerts_config" << EOF
groups:
  - name: audio-streaming
    rules:
      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage detected"
          description: "CPU usage is above 80% for more than 5 minutes"

      - alert: HighMemoryUsage
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage detected"
          description: "Memory usage is above 85% for more than 5 minutes"

      - alert: HighDiskUsage
        expr: (node_filesystem_size_bytes{fstype!="tmpfs"} - node_filesystem_free_bytes{fstype!="tmpfs"}) / node_filesystem_size_bytes{fstype!="tmpfs"} * 100 > 90
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High disk usage detected"
          description: "Disk usage is above 90% for more than 5 minutes"

      - alert: ServiceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Service is down"
          description: "{{ \$labels.instance }} of job {{ \$labels.job }} has been down for more than 1 minute"

      - alert: APIHighResponseTime
        expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{job="api"}[5m])) > 1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "API high response time"
          description: "95th percentile response time is above 1 second for more than 5 minutes"

      - alert: StreamingHighConnections
        expr: streaming_active_connections > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High streaming connections"
          description: "Active streaming connections are above 80 for more than 5 minutes"
EOF
    
    info "Prometheus настроен"
}

# Настройка Grafana
setup_grafana() {
    info "Настройка Grafana..."
    
    local grafana_dir="$PROJECT_DIR/config/grafana"
    
    # Создание директорий
    mkdir -p "$grafana_dir/provisioning/datasources"
    mkdir -p "$grafana_dir/provisioning/dashboards"
    mkdir -p "$grafana_dir/dashboards"
    
    # Настройка datasource
    cat > "$grafana_dir/provisioning/datasources/prometheus.yml" << EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
EOF
    
    # Настройка dashboards
    cat > "$grafana_dir/provisioning/dashboards/dashboard.yml" << EOF
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
EOF
    
    # Создание базового dashboard
    cat > "$grafana_dir/dashboards/audio-streaming.json" << EOF
{
  "dashboard": {
    "id": null,
    "title": "Audio Streaming Service",
    "tags": ["audio", "streaming"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "CPU Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "100 - (avg by(instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
            "legendFormat": "CPU Usage %"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "Memory Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100",
            "legendFormat": "Memory Usage %"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
      },
      {
        "id": 3,
        "title": "Disk Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "(node_filesystem_size_bytes{fstype!=\"tmpfs\"} - node_filesystem_free_bytes{fstype!=\"tmpfs\"}) / node_filesystem_size_bytes{fstype!=\"tmpfs\"} * 100",
            "legendFormat": "Disk Usage %"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8}
      },
      {
        "id": 4,
        "title": "Active Connections",
        "type": "graph",
        "targets": [
          {
            "expr": "streaming_active_connections",
            "legendFormat": "Active Connections"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8}
      }
    ],
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "refresh": "5s"
  }
}
EOF
    
    info "Grafana настроена"
}

# Создание бэкапа перед деплоем
create_backup() {
    info "Создание бэкапа перед деплоем..."
    
    local backup_name="pre-deploy-$(date +%Y%m%d_%H%M%S)"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    mkdir -p "$backup_path"
    
    # Бэкап базы данных
    if docker-compose ps | grep -q postgres; then
        docker-compose exec -T postgres pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" > "$backup_path/database.sql"
        info "База данных сохранена"
    fi
    
    # Бэкап конфигурации
    cp -r "$PROJECT_DIR/config" "$backup_path/"
    cp "$ENV_FILE" "$backup_path/"
    
    # Создание архива
    tar -czf "$backup_path.tar.gz" -C "$BACKUP_DIR" "$backup_name"
    rm -rf "$backup_path"
    
    info "Бэкап создан: $backup_path.tar.gz"
}

# Проверка состояния сервисов
check_services() {
    info "Проверка состояния сервисов..."
    
    local services=("postgres" "redis" "api" "streaming")
    local all_healthy=true
    
    for service in "${services[@]}"; do
        if ! docker-compose ps | grep -q "$service"; then
            info "Сервис $service не запущен"
            all_healthy=false
        fi
    done
    
    if [ "$all_healthy" = true ]; then
        info "Все сервисы запущены"
    else
        info "Некоторые сервисы не запущены, продолжаем деплой..."
    fi
}

# Деплой сервисов
deploy_services() {
    info "Деплой сервисов..."
    
    # Pull последних образов
    info "Загрузка последних образов..."
    docker-compose pull
    
    # Сборка образов если необходимо
    if [ -f "$PROJECT_DIR/Dockerfile" ]; then
        info "Сборка образов..."
        docker-compose build --no-cache
    fi
    
    # Запуск сервисов
    info "Запуск сервисов..."
    docker-compose up -d
    
    # Ожидание запуска
    info "Ожидание запуска сервисов..."
    sleep 30
    
    # Проверка состояния
    check_services
    
    info "Сервисы развернуты"
}

# Настройка автоматического перезапуска
setup_auto_restart() {
    info "Настройка автоматического перезапуска..."
    
    # Создание systemd service
    local service_file="/etc/systemd/system/audio-streaming.service"
    
    if [ -w "/etc/systemd/system" ]; then
        sudo tee "$service_file" > /dev/null << EOF
[Unit]
Description=Audio Streaming Service
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$PROJECT_DIR
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF
        
        sudo systemctl daemon-reload
        sudo systemctl enable audio-streaming
        
        info "Systemd service создан"
    else
        info "Нет прав для создания systemd service, пропускаем..."
    fi
}

# Настройка cron для бэкапов
setup_cron() {
    info "Настройка cron для автоматических бэкапов..."
    
    local cron_job="$BACKUP_SCHEDULE cd $PROJECT_DIR && ./scripts/backup-monitoring.sh"
    
    # Проверка существующих cron jobs
    if crontab -l 2>/dev/null | grep -q "backup-monitoring.sh"; then
        info "Cron job уже существует"
    else
        (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
        info "Cron job добавлен"
    fi
}

# Проверка деплоя
verify_deployment() {
    info "Проверка деплоя..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        info "Попытка $attempt из $max_attempts..."
        
        # Проверка API
        if curl -f -s "http://localhost:$API_PORT/health" > /dev/null; then
            info "API доступен"
            break
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            error "API недоступен после $max_attempts попыток"
        fi
        
        sleep 10
        ((attempt++))
    done
    
    # Проверка streaming
    if curl -f -s "http://localhost:$STREAMING_PORT/health" > /dev/null; then
        info "Streaming service доступен"
    else
        error "Streaming service недоступен"
    fi
    
    # Проверка nginx
    if curl -f -s "http://localhost/health" > /dev/null; then
        info "Nginx доступен"
    else
        error "Nginx недоступен"
    fi
    
    info "Деплой успешно завершен"
}

# Показать статус
show_status() {
    info "Статус сервисов:"
    docker-compose ps
    
    info "URL сервисов:"
    echo "  API: https://$APP_DOMAIN/api"
    echo "  Streaming: https://$APP_DOMAIN/stream"
    echo "  Grafana: https://$APP_DOMAIN:3001"
    echo "  Prometheus: https://$APP_DOMAIN:9090"
}

# Главная функция
deploy_full_stack() {
    local env=${1:-production}
    
    info "Начало полного деплоя audio-streaming сервиса"
    info "Окружение: $env"
    
    # Создание лог файла
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    
    # Проверки
    check_requirements
    check_env_file
    
    # Создание директорий
    create_directories
    
    # Создание бэкапа
    create_backup
    
    # Настройка компонентов
    setup_ssl
    setup_nginx
    setup_prometheus
    setup_grafana
    
    # Деплой
    deploy_services
    
    # Настройка автоматизации
    setup_auto_restart
    setup_cron
    
    # Проверка
    verify_deployment
    
    # Статус
    show_status
    
    success "Полный деплой завершен успешно!"
    info "Логи деплоя: $LOG_FILE"
}

# Показать справку
show_help() {
    cat <<EOF
Скрипт полного деплоя audio-streaming сервиса

Использование: $0 [environment] [options]

Аргументы:
    environment    Окружение для деплоя (development, staging, production)
                   По умолчанию: production

Опции:
    --help, -h     Показать эту справку
    --skip-backup  Пропустить создание бэкапа
    --skip-ssl     Пропустить настройку SSL

Примеры:
    $0 development
    $0 staging
    $0 production
    $0 --skip-backup
    $0 --skip-ssl

EOF
}

# Обработка аргументов
SKIP_BACKUP=false
SKIP_SSL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            exit 0
            ;;
        --skip-backup)
            SKIP_BACKUP=true
            shift
            ;;
        --skip-ssl)
            SKIP_SSL=true
            shift
            ;;
        development|staging|production)
            ENVIRONMENT=$1
            shift
            ;;
        *)
            echo "Неизвестный аргумент: $1"
            show_help
            exit 1
            ;;
    esac
done

# Запуск
deploy_full_stack "${ENVIRONMENT:-production}"
