#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

check_service_status() {
    log "Checking monitoring service status..."
    
    if [ ! -f "$MONITORING_COMPOSE_FILE" ]; then
        error "Monitoring compose file not found: $MONITORING_COMPOSE_FILE"
        return 1
    fi
    
    cd "$PROJECT_ROOT"
    
    echo ""
    echo "============================================="
    echo "    MONITORING STACK STATUS"
    echo "============================================="
    echo ""
    
    # Container status
    echo -e "${BLUE}Container Status:${NC}"
    docker-compose -f "$MONITORING_COMPOSE_FILE" ps
    
    echo ""
    echo -e "${BLUE}Service Health Checks:${NC}"
    
    # Check individual services
    check_service_health "prometheus" "http://localhost:9090/-/healthy" "Prometheus"
    check_service_health "grafana" "http://localhost:3000/api/health" "Grafana"
    check_service_health "loki" "http://localhost:3100/ready" "Loki"
    check_service_health "alertmanager" "http://localhost:9093/-/healthy" "Alertmanager"
    
    echo ""
    echo -e "${BLUE}Resource Usage:${NC}"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
    
    echo ""
    echo -e "${BLUE}Disk Usage:${NC}"
    df -h "$PROJECT_ROOT/data" 2>/dev/null || echo "Data directory not found"
    
    echo ""
    echo -e "${BLUE}Access URLs:${NC}"
    echo "  Grafana:      http://localhost:3000 (admin/admin)"
    echo "  Prometheus:   http://localhost:9090"
    echo "  Alertmanager: http://localhost:9093"
    echo ""
}

check_service_health() {
    local service_name=$1
    local health_url=$2
    local display_name=$3
    
    if curl -s --max-time 5 "$health_url" > /dev/null 2>&1; then
        echo -e "  ✓ ${GREEN}$display_name${NC} is healthy"
    else
        echo -e "  ✗ ${RED}$display_name${NC} is not responding"
    fi
}

check_logs() {
    log "Recent logs for monitoring services..."
    
    cd "$PROJECT_ROOT"
    
    echo ""
    echo -e "${BLUE}Recent service logs (last 10 lines):${NC}"
    
    local services=("prometheus" "grafana" "loki" "alertmanager")
    
    for service in "${services[@]}"; do
        echo ""
        echo -e "${YELLOW}--- $service ---${NC}"
        docker-compose -f "$MONITORING_COMPOSE_FILE" logs --tail=10 "$service" 2>/dev/null || echo "No logs available"
    done
}

check_alerts() {
    log "Checking active alerts..."
    
    local alerts=$(curl -s "http://localhost:9090/api/v1/alerts" | jq -r '.data.alerts[] | select(.state != "inactive") | "\(.labels.alertname): \(.state)"' 2>/dev/null)
    
    if [ -n "$alerts" ]; then
        echo ""
        echo -e "${YELLOW}Active Alerts:${NC}"
        echo "$alerts"
    else
        echo ""
        echo -e "${GREEN}No active alerts${NC}"
    fi
}

show_network_info() {
    log "Network information..."
    
    echo ""
    echo -e "${BLUE}Docker Networks:${NC}"
    docker network ls | grep -E "(monitoring|bridge|host)"
    
    echo ""
    echo -e "${BLUE}Port Bindings:${NC}"
    docker ps --format "table {{.Names}}\t{{.Ports}}" | grep -E "(prometheus|grafana|loki|alertmanager)"
}

# Main execution
main() {
    case "${1:-status}" in
        "logs")
            check_logs
            ;;
        "alerts")
            check_alerts
            ;;
        "network")
            show_network_info
            ;;
        "status"|*)
            check_service_status
            ;;
    esac
}

# Execute main function
main "$@"