#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MONITORING_COMPOSE_FILE="$PROJECT_ROOT/docker-compose.monitoring.yml"

# Functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" >&2
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

stop_monitoring() {
    log "Stopping monitoring stack..."
    
    cd "$PROJECT_ROOT"
    
    if [ -f "$MONITORING_COMPOSE_FILE" ]; then
        docker-compose -f "$MONITORING_COMPOSE_FILE" down
        
        # Optional: Remove volumes (uncomment if you want to clean data)
        # docker-compose -f "$MONITORING_COMPOSE_FILE" down -v
        
        log "Monitoring stack stopped successfully"
    else
        warning "Monitoring compose file not found: $MONITORING_COMPOSE_FILE"
    fi
}

remove_containers() {
    log "Removing monitoring containers..."
    
    local containers=("prometheus" "grafana" "loki" "alertmanager" "promtail" "node-exporter" "postgres-exporter" "redis-exporter" "cadvisor")
    
    for container in "${containers[@]}"; do
        if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
            docker rm -f "$container" 2>/dev/null || true
            log "Removed container: $container"
        fi
    done
}

cleanup_networks() {
    log "Cleaning up networks..."
    
    # Remove monitoring network if it exists
    if docker network ls | grep -q "monitoring"; then
        docker network rm monitoring 2>/dev/null || true
        log "Removed monitoring network"
    fi
}

show_status() {
    log "Current container status:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

# Main execution
main() {
    log "Stopping monitoring stack..."
    
    stop_monitoring
    remove_containers
    cleanup_networks
    show_status
    
    log "Monitoring stack cleanup completed!"
}

# Execute main function
main "$@"