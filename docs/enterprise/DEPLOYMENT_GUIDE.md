# 🚀 NORMALDANCE Enterprise Deployment Guide

## 📋 Overview

This guide provides comprehensive instructions for deploying NORMALDANCE in enterprise environments with maximum security, scalability, and reliability.

## 🏗️ Architecture Overview

```mermaid
graph TB
    subgraph "Load Balancer"
        LB[Nginx/HAProxy]
    end
    
    subgraph "Application Tier"
        APP1[App Instance 1]
        APP2[App Instance 2]
        APP3[App Instance 3]
    end
    
    subgraph "Database Tier"
        DB[(PostgreSQL Primary)]
        DB_REPLICA[(PostgreSQL Replica)]
        REDIS[(Redis Cluster)]
    end
    
    subgraph "Storage Tier"
        S3[Object Storage]
        IPFS[IPFS Network]
    end
    
    subgraph "Monitoring"
        PROM[Prometheus]
        GRAF[Grafana]
        ALERT[AlertManager]
    end
    
    LB --> APP1
    LB --> APP2
    LB --> APP3
    
    APP1 --> DB
    APP2 --> DB
    APP3 --> DB
    
    DB --> DB_REPLICA
    
    APP1 --> REDIS
    APP2 --> REDIS
    APP3 --> REDIS
    
    APP1 --> S3
    APP2 --> S3
    APP3 --> S3
    
    APP1 --> IPFS
    APP2 --> IPFS
    APP3 --> IPFS
    
    PROM --> APP1
    PROM --> APP2
    PROM --> APP3
    PROM --> DB
    PROM --> REDIS
    
    GRAF --> PROM
    ALERT --> PROM
```

## 🐳 Docker Deployment

### Prerequisites

- Docker 24.0+
- Docker Compose 2.0+
- 8GB+ RAM
- 50GB+ storage

### Quick Start

```bash
# Clone repository
git clone https://github.com/AENDYSTUDIO/NORMALDANCE-Enterprise.git
cd NORMALDANCE-Enterprise

# Set up environment
cp .env.example .env.production
# Edit .env.production with your configuration

# Deploy with Docker Compose
docker-compose -f docker-compose.enterprise.yml up -d

# Verify deployment
docker-compose ps
```

### Environment Configuration

```bash
# .env.production
NODE_ENV=production
DATABASE_URL=postgresql://postgres:${POSTGRES_PASSWORD}@db:5432/normaldance
REDIS_URL=redis://redis:6379
NEXTAUTH_SECRET=${NEXTAUTH_SECRET}
NEXTAUTH_URL=https://your-domain.com

# Security
POSTGRES_PASSWORD=your-secure-password
REDIS_PASSWORD=your-redis-password
GRAFANA_PASSWORD=your-grafana-password

# External Services
PINATA_JWT=your-pinata-jwt
SOLANA_RPC_URL=https://api.mainnet-beta.solana.com
UPSTASH_REDIS_REST_URL=your-upstash-url
UPSTASH_REDIS_REST_TOKEN=your-upstash-token

# Monitoring
SENTRY_DSN=your-sentry-dsn
MIXPANEL_TOKEN=your-mixpanel-token
```

## ☸️ Kubernetes Deployment

### Prerequisites

- Kubernetes 1.24+
- kubectl configured
- Helm 3.0+
- Ingress controller
- Cert-manager (for SSL)

### Namespace Setup

```yaml
# k8s/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: normaldance
  labels:
    name: normaldance
    environment: production
```

### ConfigMap and Secrets

```yaml
# k8s/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: normaldance-config
  namespace: normaldance
data:
  NODE_ENV: "production"
  REDIS_URL: "redis://redis-service:6379"
  NEXTAUTH_URL: "https://normaldance.com"

---
apiVersion: v1
kind: Secret
metadata:
  name: normaldance-secrets
  namespace: normaldance
type: Opaque
stringData:
  DATABASE_URL: "postgresql://postgres:password@postgres-service:5432/normaldance"
  NEXTAUTH_SECRET: "your-nextauth-secret"
  POSTGRES_PASSWORD: "your-postgres-password"
```

### Application Deployment

```yaml
# k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: normaldance-app
  namespace: normaldance
spec:
  replicas: 3
  selector:
    matchLabels:
      app: normaldance-app
  template:
    metadata:
      labels:
        app: normaldance-app
    spec:
      containers:
      - name: app
        image: ghcr.io/aendystudio/normaldance-enterprise:latest
        ports:
        - containerPort: 3000
        envFrom:
        - configMapRef:
            name: normaldance-config
        - secretRef:
            name: normaldance-secrets
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /api/health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /api/health
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
```

### Service and Ingress

```yaml
# k8s/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: normaldance-service
  namespace: normaldance
spec:
  selector:
    app: normaldance-app
  ports:
  - port: 80
    targetPort: 3000
  type: ClusterIP

---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: normaldance-ingress
  namespace: normaldance
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/rate-limit: "100"
    nginx.ingress.kubernetes.io/rate-limit-window: "1m"
spec:
  tls:
  - hosts:
    - normaldance.com
    secretName: normaldance-tls
  rules:
  - host: normaldance.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: normaldance-service
            port:
              number: 80
```

### Deploy to Kubernetes

```bash
# Apply configurations
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# Verify deployment
kubectl get pods -n normaldance
kubectl get services -n normaldance
kubectl get ingress -n normaldance
```

## 🌐 Cloud Provider Deployments

### AWS EKS Deployment

```bash
# Create EKS cluster
eksctl create cluster \
  --name normaldance-cluster \
  --version 1.24 \
  --region us-west-2 \
  --nodegroup-name standard-workers \
  --node-type t3.medium \
  --nodes 3 \
  --nodes-min 1 \
  --nodes-max 4 \
  --managed

# Install AWS Load Balancer Controller
kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"

# Deploy application
kubectl apply -f k8s/
```

### Google GKE Deployment

```bash
# Create GKE cluster
gcloud container clusters create normaldance-cluster \
  --zone us-central1-a \
  --num-nodes 3 \
  --enable-autoscaling \
  --min-nodes 1 \
  --max-nodes 5 \
  --machine-type e2-standard-2

# Get credentials
gcloud container clusters get-credentials normaldance-cluster --zone us-central1-a

# Deploy application
kubectl apply -f k8s/
```

### Azure AKS Deployment

```bash
# Create resource group
az group create --name normaldance-rg --location eastus

# Create AKS cluster
az aks create \
  --resource-group normaldance-rg \
  --name normaldance-cluster \
  --node-count 3 \
  --enable-addons monitoring \
  --generate-ssh-keys

# Get credentials
az aks get-credentials --resource-group normaldance-rg --name normaldance-cluster

# Deploy application
kubectl apply -f k8s/
```

## 🔧 Configuration Management

### Environment-Specific Configurations

```typescript
// config/environments.ts
export const environments = {
  development: {
    database: {
      host: 'localhost',
      port: 5432,
      ssl: false
    },
    redis: {
      host: 'localhost',
      port: 6379
    },
    logging: {
      level: 'debug'
    }
  },
  staging: {
    database: {
      host: process.env.DB_HOST,
      port: 5432,
      ssl: true
    },
    redis: {
      host: process.env.REDIS_HOST,
      port: 6379
    },
    logging: {
      level: 'info'
    }
  },
  production: {
    database: {
      host: process.env.DB_HOST,
      port: 5432,
      ssl: true,
      pool: {
        min: 5,
        max: 20
      }
    },
    redis: {
      host: process.env.REDIS_HOST,
      port: 6379,
      cluster: true
    },
    logging: {
      level: 'warn'
    }
  }
};
```

### Secrets Management

```bash
# Using Kubernetes secrets
kubectl create secret generic normaldance-secrets \
  --from-literal=database-url="postgresql://..." \
  --from-literal=nextauth-secret="..." \
  --from-literal=pinata-jwt="..." \
  -n normaldance

# Using HashiCorp Vault
vault kv put secret/normaldance \
  database-url="postgresql://..." \
  nextauth-secret="..." \
  pinata-jwt="..."
```

## 📊 Monitoring and Observability

### Prometheus Configuration

```yaml
# monitoring/prometheus/prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "alert_rules.yml"

scrape_configs:
  - job_name: 'normaldance-app'
    static_configs:
      - targets: ['app:3000']
    metrics_path: '/api/metrics'
    scrape_interval: 30s

  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres-exporter:9187']

  - job_name: 'redis'
    static_configs:
      - targets: ['redis-exporter:9121']

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093
```

### Grafana Dashboards

```json
{
  "dashboard": {
    "title": "NORMALDANCE Production Dashboard",
    "panels": [
      {
        "title": "Request Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(http_requests_total[5m])",
            "legendFormat": "{{method}} {{status}}"
          }
        ]
      },
      {
        "title": "Response Time",
        "type": "graph",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))",
            "legendFormat": "95th percentile"
          }
        ]
      }
    ]
  }
}
```

### Alert Rules

```yaml
# monitoring/prometheus/alert_rules.yml
groups:
  - name: normaldance.rules
    rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.1
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value }} errors per second"

      - alert: HighResponseTime
        expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 2
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High response time detected"
          description: "95th percentile response time is {{ $value }} seconds"

      - alert: DatabaseConnectionFailure
        expr: up{job="postgres"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Database connection failure"
          description: "PostgreSQL database is not responding"
```

## 🔒 Security Hardening

### SSL/TLS Configuration

```nginx
# nginx/ssl.conf
server {
    listen 443 ssl http2;
    server_name normaldance.com;

    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    
    add_header Strict-Transport-Security "max-age=63072000" always;
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header Referrer-Policy "strict-origin-when-cross-origin";
    
    location / {
        proxy_pass http://app:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Network Policies

```yaml
# k8s/network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: normaldance-network-policy
  namespace: normaldance
spec:
  podSelector:
    matchLabels:
      app: normaldance-app
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 3000
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: postgres
    ports:
    - protocol: TCP
      port: 5432
  - to:
    - podSelector:
        matchLabels:
          app: redis
    ports:
    - protocol: TCP
      port: 6379
```

## 🔄 CI/CD Pipeline

### GitHub Actions Deployment

```yaml
# .github/workflows/deploy-production.yml
name: Deploy to Production

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-west-2
      
      - name: Login to Amazon ECR
        uses: aws-actions/amazon-ecr-login@v2
      
      - name: Build and push Docker image
        run: |
          docker build -f Dockerfile.enterprise -t $ECR_REGISTRY/$ECR_REPOSITORY:$GITHUB_SHA .
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$GITHUB_SHA
      
      - name: Deploy to EKS
        run: |
          aws eks update-kubeconfig --name normaldance-cluster
          kubectl set image deployment/normaldance-app app=$ECR_REGISTRY/$ECR_REPOSITORY:$GITHUB_SHA -n normaldance
          kubectl rollout status deployment/normaldance-app -n normaldance
```

## 🚨 Disaster Recovery

### Backup Strategy

```bash
#!/bin/bash
# scripts/backup.sh

# Database backup
pg_dump $DATABASE_URL | gzip > backups/db-$(date +%Y%m%d-%H%M%S).sql.gz

# Redis backup
redis-cli --rdb backups/redis-$(date +%Y%m%d-%H%M%S).rdb

# Upload to S3
aws s3 sync backups/ s3://normaldance-backups/$(date +%Y/%m/%d)/
```

### Recovery Procedures

```bash
#!/bin/bash
# scripts/restore.sh

# Restore database
gunzip -c backups/db-20240101-120000.sql.gz | psql $DATABASE_URL

# Restore Redis
redis-cli --rdb backups/redis-20240101-120000.rdb

# Verify restoration
npm run test:smoke
```

## 📈 Scaling Guidelines

### Horizontal Pod Autoscaler

```yaml
# k8s/hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: normaldance-hpa
  namespace: normaldance
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: normaldance-app
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

### Database Scaling

```sql
-- Read replicas configuration
CREATE PUBLICATION normaldance_pub FOR ALL TABLES;

-- On replica
CREATE SUBSCRIPTION normaldance_sub 
CONNECTION 'host=primary-db port=5432 dbname=normaldance user=replicator' 
PUBLICATION normaldance_pub;
```

## 🔍 Troubleshooting

### Common Issues

1. **Pod CrashLoopBackOff**
   ```bash
   kubectl logs -f deployment/normaldance-app -n normaldance
   kubectl describe pod <pod-name> -n normaldance
   ```

2. **Database Connection Issues**
   ```bash
   kubectl exec -it deployment/normaldance-app -n normaldance -- psql $DATABASE_URL
   ```

3. **High Memory Usage**
   ```bash
   kubectl top pods -n normaldance
   kubectl describe node <node-name>
   ```

### Health Checks

```typescript
// src/app/api/health/route.ts
export async function GET() {
  const checks = {
    database: await checkDatabase(),
    redis: await checkRedis(),
    ipfs: await checkIPFS(),
    timestamp: new Date().toISOString()
  };

  const isHealthy = Object.values(checks).every(check => 
    typeof check === 'boolean' ? check : check.status === 'ok'
  );

  return Response.json(checks, { 
    status: isHealthy ? 200 : 503 
  });
}
```

## 📞 Support

For deployment support:
- **Email**: devops@normaldance.com
- **Discord**: [#deployment channel](https://discord.gg/normaldance)
- **Documentation**: [docs.normaldance.com](https://docs.normaldance.com)

---

*Last updated: January 2025*