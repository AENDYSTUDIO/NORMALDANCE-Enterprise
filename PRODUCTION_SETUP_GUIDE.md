# 🚀 Production Environment Setup Guide

## Quick Start (5 minutes to production)

### Prerequisites
- AWS CLI configured
- Docker installed
- kubectl installed

### 1. One-Click Infrastructure Setup
```bash
# Deploy complete AWS infrastructure
chmod +x scripts/deploy/one-click-deploy.sh
./scripts/deploy/one-click-deploy.sh
```

### 2. Configure Secrets
```bash
# Create secrets in AWS Secrets Manager
aws secretsmanager create-secret \
  --name "normaldance/database-url" \
  --secret-string "postgresql://user:pass@endpoint:5432/normaldance"

aws secretsmanager create-secret \
  --name "normaldance/jwt-secret" \
  --secret-string "your-jwt-secret-here"
```

### 3. Deploy Application
```bash
# Automated deployment with health checks
node tools/cloud-automation.js setup production
```

## Available Automation Tools

### Cloud Management
```bash
# Setup environment
node tools/cloud-automation.js setup [production|staging]

# Scale application
node tools/cloud-automation.js scale 5

# Create backup
node tools/cloud-automation.js backup

# Health check
node tools/cloud-automation.js health
```

### Infrastructure as Code
- **AWS CloudFormation**: Complete infrastructure template
- **Kubernetes manifests**: Production-ready configurations
- **IAM policies**: Least-privilege access controls
- **Monitoring**: Prometheus + Grafana setup

### CI/CD Pipeline Features
- ✅ Automated security scanning
- ✅ Zero-downtime deployments
- ✅ Rollback capabilities
- ✅ Health checks
- ✅ Performance monitoring

## Production Environment Includes

### 🏗️ Infrastructure
- **EKS Cluster** with auto-scaling
- **RDS Aurora PostgreSQL** with Multi-AZ
- **ElastiCache Redis** for caching
- **S3** for backups and static assets
- **CloudFront CDN** for global distribution

### 🔒 Security
- **WAF** protection against attacks
- **SSL/TLS** certificates
- **Secrets Manager** for credentials
- **IAM roles** with least privilege
- **Network security groups**

### 📊 Monitoring
- **CloudWatch** metrics and logs
- **Prometheus** for application metrics
- **Grafana** dashboards
- **Alerting** for critical issues

### 🔄 Automation
- **Auto-scaling** based on load
- **Automated backups** daily
- **Health checks** every 30 seconds
- **Self-healing** pod restarts

## Cost Optimization

### Estimated Monthly Costs (USD)
- **EKS Cluster**: $73
- **RDS Aurora**: $150-300
- **ElastiCache**: $50-100
- **Data Transfer**: $20-50
- **Total**: ~$300-500/month

### Cost Saving Features
- **Spot instances** for non-critical workloads
- **Reserved instances** for predictable workloads
- **Auto-scaling** to match demand
- **S3 lifecycle policies** for old backups

## Support and Maintenance

### Automated Tasks
- ✅ Daily backups
- ✅ Security updates
- ✅ Performance monitoring
- ✅ Log rotation
- ✅ Certificate renewal

### Manual Tasks (Monthly)
- Review security alerts
- Update dependencies
- Capacity planning
- Cost optimization review

## Troubleshooting

### Common Issues
```bash
# Check pod status
kubectl get pods -l app=normaldance

# View logs
kubectl logs -f deployment/normaldance-app

# Check health
curl https://your-domain.com/api/health/detailed

# Scale if needed
node tools/cloud-automation.js scale 10
```

### Emergency Procedures
```bash
# Rollback deployment
kubectl rollout undo deployment/normaldance-app

# Emergency scaling
kubectl scale deployment normaldance-app --replicas=20

# Database failover (automatic with Aurora)
# Backup restore
aws rds restore-db-cluster-from-snapshot
```

**🎯 Result: Production-ready environment in under 10 minutes!**