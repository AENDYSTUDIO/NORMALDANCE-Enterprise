#!/bin/bash

# NORMALDANCE Enterprise Setup Script
# This script sets up the complete enterprise environment

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🏢 NORMALDANCE Enterprise Setup${NC}"
echo "=================================="

# Function to print status
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if running on Windows (Git Bash/WSL)
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    print_warning "Detected Windows environment. Some commands may need adjustment."
fi

# 1. Setup GitHub Secrets
setup_github_secrets() {
    echo ""
    echo "🔐 Setting up GitHub Secrets..."
    
    # Generate secure secrets
    NEXTAUTH_SECRET=$(openssl rand -base64 32 2>/dev/null || echo "CHANGE_ME_$(date +%s)")
    
    echo "Required GitHub Secrets:"
    echo "========================"
    echo "NEXTAUTH_SECRET: $NEXTAUTH_SECRET"
    echo "DATABASE_URL: postgresql://user:pass@host:5432/normaldance"
    echo "REDIS_URL: redis://host:6379"
    echo "PINATA_JWT: your-pinata-jwt"
    echo "SONAR_TOKEN: your-sonarcloud-token"
    echo "VERCEL_TOKEN: your-vercel-token"
    echo ""
    echo "Add these to: https://github.com/AENDYSTUDIO/NORMALDANCE-Enterprise/settings/secrets/actions"
    
    print_status "GitHub Secrets guide generated"
}

# 2. Setup SonarCloud
setup_sonarcloud() {
    echo ""
    echo "🔍 Setting up SonarCloud..."
    
    # Run SonarCloud setup script
    if [ -f "scripts/setup-sonarcloud.sh" ]; then
        chmod +x scripts/setup-sonarcloud.sh
        ./scripts/setup-sonarcloud.sh
    else
        print_warning "SonarCloud setup script not found"
    fi
    
    print_status "SonarCloud configuration ready"
}

# 3. Setup Monitoring
setup_monitoring() {
    echo ""
    echo "📊 Setting up Monitoring Stack..."
    
    # Create monitoring directories
    mkdir -p monitoring/{prometheus,grafana,alertmanager,loki,promtail}
    mkdir -p monitoring/grafana/{dashboards,provisioning}
    
    # Create Grafana provisioning
    cat > monitoring/grafana/provisioning/datasources.yml << 'EOF'
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
EOF

    # Create AlertManager config
    cat > monitoring/alertmanager/alertmanager.yml << 'EOF'
global:
  smtp_smarthost: 'localhost:587'
  smtp_from: 'alerts@normaldance.com'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'web.hook'

receivers:
  - name: 'web.hook'
    webhook_configs:
      - url: 'http://localhost:5001/'
EOF

    # Create Loki config
    cat > monitoring/loki/loki-config.yml << 'EOF'
auth_enabled: false

server:
  http_listen_port: 3100

ingester:
  lifecycler:
    address: 127.0.0.1
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
    final_sleep: 0s

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 168h

storage_config:
  boltdb:
    directory: /loki/index
  filesystem:
    directory: /loki/chunks

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h
EOF

    print_status "Monitoring stack configured"
}

# 4. Setup Production Deployment
setup_production_deployment() {
    echo ""
    echo "🚀 Setting up Production Deployment..."
    
    # Make deployment script executable
    chmod +x scripts/deploy-cloud.sh
    
    # Create production environment file
    cat > .env.production.example << 'EOF'
# Production Environment Variables
NODE_ENV=production
NEXTAUTH_URL=https://normaldance.com
NEXTAUTH_SECRET=your-nextauth-secret

# Database
DATABASE_URL=postgresql://user:pass@host:5432/normaldance

# Redis
REDIS_URL=redis://host:6379

# External Services
PINATA_JWT=your-pinata-jwt
SOLANA_RPC_URL=https://api.mainnet-beta.solana.com
UPSTASH_REDIS_REST_URL=your-upstash-url
UPSTASH_REDIS_REST_TOKEN=your-upstash-token

# Monitoring
SENTRY_DSN=your-sentry-dsn
MIXPANEL_TOKEN=your-mixpanel-token

# Security
RATE_LIMIT_MAX=100
RATE_LIMIT_WINDOW=900000
EOF

    print_status "Production deployment configured"
}

# 5. Setup Security Scanning
setup_security_scanning() {
    echo ""
    echo "🛡️  Setting up Security Scanning..."
    
    # Install security tools (if not in CI)
    if ! command -v trivy &> /dev/null; then
        print_warning "Trivy not installed. Install from: https://aquasecurity.github.io/trivy/"
    fi
    
    # Create security scan script
    cat > scripts/security-scan.sh << 'EOF'
#!/bin/bash

echo "🔍 Running security scans..."

# Trivy filesystem scan
if command -v trivy &> /dev/null; then
    echo "Running Trivy scan..."
    trivy fs --security-checks vuln,config .
else
    echo "Trivy not installed, skipping..."
fi

# npm audit
echo "Running npm audit..."
pnpm audit --audit-level moderate

# Check for secrets
echo "Checking for secrets..."
if command -v trufflehog &> /dev/null; then
    trufflehog filesystem .
else
    echo "TruffleHog not installed, skipping..."
fi

echo "✅ Security scans complete"
EOF

    chmod +x scripts/security-scan.sh
    
    print_status "Security scanning configured"
}

# 6. Setup Development Environment
setup_development() {
    echo ""
    echo "💻 Setting up Development Environment..."
    
    # Install dependencies
    if command -v pnpm &> /dev/null; then
        echo "Installing dependencies..."
        pnpm install
    else
        print_warning "pnpm not installed. Install with: npm install -g pnpm"
    fi
    
    # Setup database
    if [ -f "prisma/schema.prisma" ]; then
        echo "Setting up database..."
        pnpm db:generate || echo "Database generation skipped"
    fi
    
    # Setup git hooks
    if [ -d ".git" ]; then
        echo "Setting up git hooks..."
        if command -v pnpm &> /dev/null; then
            pnpm prepare || echo "Git hooks setup skipped"
        fi
    fi
    
    print_status "Development environment configured"
}

# Main setup function
main() {
    echo "Starting NORMALDANCE Enterprise setup..."
    echo ""
    
    # Run all setup functions
    setup_github_secrets
    setup_sonarcloud
    setup_monitoring
    setup_production_deployment
    setup_security_scanning
    setup_development
    
    echo ""
    echo -e "${GREEN}🎉 NORMALDANCE Enterprise setup complete!${NC}"
    echo ""
    echo "📋 Next steps:"
    echo "1. Add GitHub Secrets: https://github.com/AENDYSTUDIO/NORMALDANCE-Enterprise/settings/secrets"
    echo "2. Setup SonarCloud: https://sonarcloud.io"
    echo "3. Configure monitoring: docker-compose -f monitoring/docker-compose.monitoring.yml up -d"
    echo "4. Deploy to production: ./scripts/deploy-cloud.sh"
    echo "5. Run security scans: ./scripts/security-scan.sh"
    echo ""
    echo "📚 Documentation: https://docs.normaldance.com"
    echo "🆘 Support: support@normaldance.com"
}

# Run main function
main "$@"