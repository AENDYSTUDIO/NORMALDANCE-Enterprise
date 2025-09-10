#!/bin/bash
set -euo pipefail

# Audio Streaming Monitoring Setup Script
# This script sets up comprehensive monitoring infrastructure

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_DIR="$PROJECT_ROOT/config"
MONITORING_CONFIG_DIR="$CONFIG_DIR/monitoring"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

# Check if running as root for Docker operations
check_permissions() {
    if [[ $EUID -eq 0 ]]; then
        warn "Running as root. Some Docker operations may have permission issues."
    fi
}

# Create necessary directories
create_directories() {
    log "Creating monitoring directories..."
    
    mkdir -p "$PROJECT_ROOT/data/prometheus"
    mkdir -p "$PROJECT_ROOT/data/grafana"
    mkdir -p "$PROJECT_ROOT/data/loki"
    mkdir -p "$PROJECT_ROOT/data/alertmanager"
    mkdir -p "$PROJECT_ROOT/logs/monitoring"
    
    # Set proper permissions
    chmod 755 "$PROJECT_ROOT/data"/*
    chmod 755 "$PROJECT_ROOT/logs/monitoring"
}

# Validate configuration files
validate_configs() {
    log "Validating monitoring configuration files..."
    
    local config_files=(
        "$CONFIG_DIR/prometheus/prometheus.yml"
        "$CONFIG_DIR/prometheus/rules/audio-streaming.yml"
        "$CONFIG_DIR/grafana/provisioning/datasources/datasource.yml"
        "$CONFIG_DIR/grafana/provisioning/dashboards/dashboard.yml"
        "$CONFIG_DIR/loki/loki-config.yml"
        "$CONFIG_DIR/promtail/promtail-config.yml"
        "$CONFIG_DIR/alertmanager/alertmanager.yml"
    )
    
    for file in "${config_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            error "Configuration file missing: $file"
            exit 1
        fi
        
        # Basic YAML syntax check
        if command -v yq >/dev/null 2>&1; then
            if ! yq eval '.' "$file" >/dev/null 2>&1; then
                error "Invalid YAML syntax in: $file"
                exit 1
            fi
        fi
    done
    
    log "All configuration files are valid"
}

# Setup environment variables
setup_environment() {
    log "Setting up monitoring environment variables..."
    
    local env_file="$PROJECT_ROOT/.env"
    
    if [[ ! -f "$env_file" ]]; then
        warn ".env file not found, creating from template..."
        cp "$PROJECT_ROOT/.env.example" "$env_file"
    fi
    
    # Ensure required monitoring variables are set
    local required_vars=(
        "GRAFANA_ADMIN_PASSWORD"
        "POSTGRES_PASSWORD"
        "REDIS_PASSWORD"
        "ALERT_EMAIL_TO"
        "SMTP_HOST"
        "SMTP_USERNAME"
        "SMTP_PASSWORD"
    )
    
    for var in "${required_vars[@]}"; do
        if ! grep -q "^$var=" "$env_file"; then
            warn "Missing environment variable: $var"
            read -p "Enter value for $var: " value
            echo "$var=$value" >> "$env_file"
        fi
    done
    
    log "Environment variables configured"
}

# Create Docker networks
create_networks() {
    log "Creating Docker networks..."
    
    # Create app network if it doesn't exist
    if ! docker network ls | grep -q "app-network"; then
        docker network create app-network
        log "Created app-network"
    fi
    
    # Create monitoring network
    if ! docker network ls | grep -q "monitoring"; then
        docker network create monitoring
        log "Created monitoring network"
    fi
}

# Pull required Docker images
pull_images() {
    log "Pulling monitoring Docker images..."
    
    local images=(
        "prom/prometheus:latest"
        "grafana/grafana:latest"
        "grafana/loki:latest"
        "grafana/promtail:latest"
        "prom/alertmanager:latest"
        "prom/node-exporter:latest"
        "gcr.io/cadvisor/cadvisor:latest"
        "prometheuscommunity/postgres-exporter:latest"
        "oliver006/redis_exporter:latest"
        "nginx/nginx-prometheus-exporter:latest"
    )
    
    for image in "${images[@]}"; do
        log "Pulling $image..."
        docker pull "$image"
    done
}

# Setup log rotation
setup_log_rotation() {
    log "Setting up log rotation..."
    
    cat > "$PROJECT_ROOT/config/logrotate/monitoring" <<EOF
$PROJECT_ROOT/logs/monitoring/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
    postrotate
        docker-compose -f $PROJECT_ROOT/docker-compose.monitoring.yml kill -s USR1 promtail || true
    endscript
}
EOF
    
    # Install logrotate configuration
    if [[ -d "/etc/logrotate.d" ]]; then
        sudo cp "$PROJECT_ROOT/config/logrotate/monitoring" "/etc/logrotate.d/audio-streaming-monitoring"
        log "Log rotation configured"
    else
        warn "Could not install logrotate configuration (not running as root)"
    fi
}

# Create systemd service for monitoring
create_systemd_service() {
    log "Creating systemd service for monitoring..."
    
    cat > "$PROJECT_ROOT/config/systemd/audio-streaming-monitoring.service" <<EOF
[Unit]
Description=Audio Streaming Monitoring Stack
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$PROJECT_ROOT
ExecStart=/usr/bin/docker-compose -f docker-compose.monitoring.yml up -d
ExecStop=/usr/bin/docker-compose -f docker-compose.monitoring.yml down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF
    
    # Install systemd service
    if [[ -d "/etc/systemd/system" ]]; then
        sudo cp "$PROJECT_ROOT/config/systemd/audio-streaming-monitoring.service" "/etc/systemd/system/"
        sudo systemctl daemon-reload
        sudo systemctl enable audio-streaming-monitoring
        log "Systemd service created and enabled"
    else
        warn "Could not install systemd service (not running as root)"
    fi
}

# Test monitoring stack
test_monitoring() {
    log "Testing monitoring stack..."
    
    # Start monitoring services
    cd "$PROJECT_ROOT"
    docker-compose -f docker-compose.monitoring.yml up -d
    
    # Wait for services to start
    log "Waiting for services to start..."
    sleep 30
    
    # Test Prometheus
    if curl -s http://localhost:9090/-/healthy >/dev/null; then
        log "✓ Prometheus is healthy"
    else
        error "✗ Prometheus health check failed"
    fi
    
    # Test Grafana
    if curl -s http://localhost:3000/api/health >/dev/null; then
        log "✓ Grafana is healthy"
    else
        error "✗ Grafana health check failed"
    fi
    
    # Test Loki
    if curl -s http://localhost:3100/ready >/dev/null; then
        log "✓ Loki is healthy"
    else
        error "✗ Loki health check failed"
    fi
    
    # Test Alertmanager
    if curl -s http://localhost:9093/-/healthy >/dev/null; then
        log "✓ Alertmanager is healthy"
    else
        error "✗ Alertmanager health check failed"
    fi
    
    log "Monitoring stack test completed"
}

# Main execution
main() {
    log "Starting Audio Streaming Monitoring Setup..."
    
    check_permissions
    create_directories
    validate_configs
    setup_environment
    create_networks
    pull_images
    setup_log_rotation
    create_systemd_service
    
    log "Monitoring setup completed successfully!"
    log "To start monitoring: docker-compose -f docker-compose.monitoring.yml up -d"
    log "Access Grafana at: http://localhost:3000 (admin/admin)"
    log "Access Prometheus at: http://localhost:9090"
    log "Access Alertmanager at: http://localhost:9093"
}

# Execute main function
main "$@"