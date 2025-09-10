# 🚀 Deployment Guide

## Prerequisites
- Docker 20.10+
- Kubernetes 1.25+
- Node.js 18+

## Environment Setup

### 1. Environment Variables
```bash
# Database
DATABASE_URL="postgresql://user:pass@localhost:5432/normaldance"

# Security
JWT_SECRET="your-jwt-secret"
NEXTAUTH_SECRET="your-nextauth-secret"

# Web3
SOLANA_RPC_URL="https://api.mainnet-beta.solana.com"
IPFS_API_URL="https://ipfs.infura.io:5001"

# Monitoring
SENTRY_DSN="your-sentry-dsn"
```

### 2. Security Configuration
```bash
# Generate secrets
kubectl create secret generic normaldance-secrets \
  --from-literal=database-url=$DATABASE_URL \
  --from-literal=jwt-secret=$JWT_SECRET
```

## Deployment Steps

### 1. Build and Push
```bash
docker build -t normaldance:latest .
docker push registry/normaldance:latest
```

### 2. Deploy to Kubernetes
```bash
kubectl apply -f k8s/
kubectl rollout status deployment/normaldance-app
```

### 3. Verify Deployment
```bash
kubectl get pods -l app=normaldance
curl https://your-domain.com/api/health
```

## Security Checklist
- [ ] All secrets in environment variables
- [ ] HTTPS enabled
- [ ] CSP headers configured
- [ ] Rate limiting active
- [ ] Database encrypted