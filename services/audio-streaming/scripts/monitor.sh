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
COMPOSE_FILE="$PROJECT_ROOT/docker-compose.monitoring.yml"

# Function to show usage
show_usage() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  status      - Show status of all monitoring services"
    echo "  logs        - Show logs for all services"
    echo "  restart     - Restart all monitoring services"
    echo "  stop        - Stop all monitoring services"
    echo "  start       - Start all monitoring services"
    echo "  update      - Update monitoring services"
    echo "  clean       - Clean up monitoring data (WARNING: This will delete all data)"
    echo ""
}

# Function to show service status
show_status() {
    echo -e "${GREEN}Monitoring Services Status:${NC}"
    echo "========================="
    
    if [ -f "$COMPOSE_FILE" ]; then
        docker-compose -f "$COMPOSE_FILE" ps
        
        echo ""
        echo -e "${GREEN}Service URLs:${NC}"
        echo "  Grafana: http://localhost:3000"
        echo "  Prometheus: http://localhost:9090"
        echo "  Alertmanager: http://localhost:9093"
        echo "  Node Exporter: http://localhost:9100/metrics"
        echo "  cAdvisor: http://localhost:8080/metrics"
    else
        echo -e "${RED}Docker Compose file not found: $COMPOSE_FILE${NC}"
    fi
}

# Function to show logs
show_logs() {
    local service=$1
    
    if [ -z "$service" ]; then
        echo -e "${GREEN}Showing logs for all services (follow mode):${NC}"
        docker-compose -f "$COMPOSE_FILE" logs -f
    else
        echo -e "${GREEN}Showing logs for service: $service${NC}"
        docker-compose -f "$COMPOSE_FILE" logs -f "$service"
    fi
}

# Function to restart services
restart_services() {
    echo -e "${YELLOW}Restarting monitoring services...${NC}"
    docker-compose -f "$COMPOSE_FILE" restart
    echo -e "${GREEN}Services restarted successfully${NC}"
}

# Function to stop services
stop_services() {
    echo -e "${YELLOW}Stopping monitoring services...${NC}"
    docker-compose -f "$COMPOSE_FILE" stop
    echo -e "${GREEN}Services stopped successfully${NC}"
}

# Function to start services
start_services() {
    echo -e "${YELLOW}Starting monitoring services...${NC}"
    docker-compose -f "$COMPOSE_FILE" start
    echo -e "${GREEN}Services started successfully${NC}"
}

# Function to update services
update_services() {
    echo -e "${YELLOW}Updating monitoring services...${NC}"
    docker-compose -f "$COMPOSE_FILE" pull
    docker-compose -f "$COMPOSE_FILE" up -d
    echo -e "${GREEN}Services updated successfully${NC}"
}

# Function to clean up data
clean_data() {
    echo -e "${RED}WARNING: This will delete all monitoring data!${NC}"
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Stopping services...${NC}"
        docker-compose -f "$COMPOSE_FILE" down
        
        echo -e "${YELLOW}Cleaning up data...${NC}"
        rm -rf "$PROJECT_ROOT/data"/*
        
        echo -e "${GREEN}Data cleaned successfully${NC}"
    else
        echo -e "${YELLOW}Cleanup cancelled${NC}"
    fi
}

# Main script logic
case "${1:-status}" in
    status)
        show_status
        ;;
    logs)
        show_logs "$2"
        ;;
    restart)
        restart_services
        ;;
    stop)
        stop_services
        ;;
    start)
        start_services
        ;;
    update)
        update_services
        ;;
    clean)
        clean_data
        ;;
    *)
        show_usage
        ;;
esac