# 🚀 NORMALDANCE Enterprise Activation Guide

## 📋 Quick Start

Запустите один скрипт для полной настройки enterprise окружения:

```bash
chmod +x scripts/setup-enterprise.sh
./scripts/setup-enterprise.sh
```

## 🔧 Manual Setup Steps

### 1. 🔐 GitHub Actions & Secrets

#### Активация GitHub Actions
1. Перейдите в **Settings** → **Actions** → **General**
2. Выберите **Allow all actions and reusable workflows**
3. Сохраните настройки

#### Настройка Secrets
Добавьте в **Settings** → **Secrets and variables** → **Actions**:

```bash
# Core Application
NEXTAUTH_SECRET=<generated-32-char-secret>
DATABASE_URL=postgresql://user:pass@host:5432/normaldance
REDIS_URL=redis://host:6379

# External Services  
PINATA_JWT=your-pinata-jwt-token
SOLANA_RPC_URL=https://api.mainnet-beta.solana.com
UPSTASH_REDIS_REST_URL=your-upstash-url
UPSTASH_REDIS_REST_TOKEN=your-upstash-token

# Monitoring & Analytics
SENTRY_DSN=your-sentry-dsn
MIXPANEL_TOKEN=your-mixpanel-token
SONAR_TOKEN=your-sonarcloud-token

# Deployment
VERCEL_TOKEN=your-vercel-token
VERCEL_ORG_ID=your-vercel-org-id  
VERCEL_PROJECT_ID=your-vercel-project-id

# Cloud Provider (выберите один)
AWS_ACCESS_KEY_ID=your-aws-key
AWS_SECRET_ACCESS_KEY=your-aws-secret
# ИЛИ
GOOGLE_CREDENTIALS=your-gcp-service-account-json
# ИЛИ  
AZURE_CREDENTIALS=your-azure-service-principal
```

### 2. 🔍 SonarCloud Setup

#### Автоматическая настройка
```bash
chmod +x scripts/setup-sonarcloud.sh
./scripts/setup-sonarcloud.sh
```

#### Ручная настройка
1. Перейдите на [SonarCloud.io](https://sonarcloud.io)
2. Войдите через GitHub
3. Импортируйте репозиторий: `AENDYSTUDIO/NORMALDANCE-Enterprise`
4. Получите **SONAR_TOKEN** из SonarCloud
5. Добавьте токен в GitHub Secrets
6. Запушьте изменения для первого анализа

### 3. 📊 Monitoring Stack

#### Локальный запуск
```bash
# Запуск полного monitoring stack
docker-compose -f monitoring/docker-compose.monitoring.yml up -d

# Проверка статуса
docker-compose -f monitoring/docker-compose.monitoring.yml ps
```

#### Доступ к сервисам
- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3001 (admin/admin123)
- **AlertManager**: http://localhost:9093
- **Loki**: http://localhost:3100

#### Production Kubernetes
```bash
# Применить monitoring manifests
kubectl apply -f k8s/monitoring/
```

### 4. 🚀 Production Deployment

#### Выбор Cloud Provider

**AWS EKS:**
```bash
./scripts/deploy-cloud.sh
# Выберите опцию 1 (AWS EKS)
```

**Google GKE:**
```bash
./scripts/deploy-cloud.sh  
# Выберите опцию 2 (Google GKE)
```

**Azure AKS:**
```bash
./scripts/deploy-cloud.sh
# Выберите опцию 3 (Azure AKS)
```

**Local Docker:**
```bash
./scripts/deploy-cloud.sh
# Выберите опцию 4 (Local Docker)
```

#### Vercel Deployment
```bash
# Установка Vercel CLI
npm i -g vercel

# Деплой
vercel --prod
```

### 5. 🛡️ Security Scanning

#### Активация Dependabot
Dependabot уже настроен в `.github/dependabot.yml` и активируется автоматически.

#### Trivy Security Scanning
```bash
# Установка Trivy (macOS)
brew install trivy

# Установка Trivy (Linux)
wget https://github.com/aquasecurity/trivy/releases/latest/download/trivy_Linux-64bit.tar.gz
tar zxvf trivy_Linux-64bit.tar.gz
sudo mv trivy /usr/local/bin/

# Запуск сканирования
./scripts/security-scan.sh
```

#### CodeQL Analysis
CodeQL активируется автоматически через GitHub Actions при push в main/develop.

## 🎯 Verification Checklist

### ✅ GitHub Actions
- [ ] Actions активированы в Settings
- [ ] Все secrets добавлены
- [ ] CI/CD pipeline запускается при push
- [ ] Security scans проходят успешно

### ✅ SonarCloud  
- [ ] Проект импортирован в SonarCloud
- [ ] SONAR_TOKEN добавлен в GitHub Secrets
- [ ] Quality Gate настроен (80% coverage)
- [ ] Анализ запускается при PR

### ✅ Monitoring
- [ ] Prometheus собирает метрики
- [ ] Grafana показывает дашборды
- [ ] AlertManager настроен
- [ ] Loki собирает логи

### ✅ Production Deployment
- [ ] Cloud provider выбран и настроен
- [ ] Kubernetes cluster создан
- [ ] Application развернуто
- [ ] Health checks проходят
- [ ] SSL сертификаты настроены

### ✅ Security
- [ ] Trivy сканирование настроено
- [ ] Dependabot активирован
- [ ] CodeQL analysis работает
- [ ] Secret scanning включен
- [ ] Security headers настроены

## 🔧 Configuration Files Status

| Component | File | Status |
|-----------|------|--------|
| CI/CD | `.github/workflows/enterprise-ci.yml` | ✅ Ready |
| Security | `.github/workflows/security-scan.yml` | ✅ Ready |
| SonarCloud | `sonar-project.properties` | ✅ Ready |
| ESLint | `eslint.config.enterprise.js` | ✅ Ready |
| Jest | `jest.config.enterprise.js` | ✅ Ready |
| Docker | `Dockerfile.enterprise` | ✅ Ready |
| Monitoring | `monitoring/docker-compose.monitoring.yml` | ✅ Ready |
| Kubernetes | `k8s/*.yaml` | ✅ Ready |
| Deployment | `scripts/deploy-cloud.sh` | ✅ Ready |

## 🚨 Troubleshooting

### GitHub Actions не запускаются
```bash
# Проверьте настройки Actions
# Settings → Actions → General → Allow all actions
```

### SonarCloud анализ не работает
```bash
# Проверьте SONAR_TOKEN в GitHub Secrets
# Убедитесь что проект импортирован в SonarCloud
```

### Monitoring не запускается
```bash
# Проверьте Docker
docker --version
docker-compose --version

# Перезапустите stack
docker-compose -f monitoring/docker-compose.monitoring.yml down
docker-compose -f monitoring/docker-compose.monitoring.yml up -d
```

### Deployment не работает
```bash
# Проверьте cloud credentials
aws sts get-caller-identity  # для AWS
gcloud auth list            # для GCP  
az account show            # для Azure

# Проверьте kubectl
kubectl cluster-info
```

## 📞 Support

### 🆘 Immediate Help
- **Discord**: [#enterprise-support](https://discord.gg/normaldance)
- **Email**: enterprise@normaldance.com
- **GitHub Issues**: [Create Issue](https://github.com/AENDYSTUDIO/NORMALDANCE-Enterprise/issues/new)

### 📚 Documentation
- **Full Docs**: [docs.normaldance.com](https://docs.normaldance.com)
- **API Reference**: [api.normaldance.com](https://api.normaldance.com)
- **Architecture**: [docs/enterprise/](docs/enterprise/)

### 🎯 Success Metrics

После активации вы получите:

- ✅ **99.9% Uptime** SLA
- ✅ **< 2s** Page Load Time  
- ✅ **80%+** Test Coverage
- ✅ **Zero** Critical Vulnerabilities
- ✅ **Daily** Automated Deployments
- ✅ **Real-time** Monitoring & Alerts

---

**🏢 NORMALDANCE Enterprise** - Production-Ready Web3 Music Platform

*Created by AENDY STUDIO - Enterprise Web3 Solutions*