# 🔄 Git Commands для создания production-ready ветки

## Быстрые команды для создания ветки

### 1. Автоматическое создание ветки
```bash
# Запустить скрипт создания ветки
chmod +x scripts/git/create-release-branch.sh
./scripts/git/create-release-branch.sh
```

### 2. Ручное создание ветки
```bash
# Создать новую ветку
git checkout -b release/v2.0.0-production-ready

# Добавить все файлы
git add .

# Коммит с описанием
git commit -m "feat: Production-ready release v2.0.0

✅ Security fixes implemented:
- XSS protection with SecuritySanitizer
- Path traversal prevention  
- Log injection prevention
- Code injection elimination
- Hardcoded credentials removed

✅ Infrastructure improvements:
- AWS CloudFormation templates
- Kubernetes auto-scaling (HPA)
- Database high availability (3 replicas)
- Automated backups with S3
- SSL/TLS configuration

✅ CI/CD pipeline:
- Security scanning in pipeline
- Zero-downtime deployments
- Automated rollback capabilities
- Health checks post-deployment

✅ Monitoring & alerting:
- Distributed tracing
- Production alerts configuration
- Performance metrics collection
- Health monitoring endpoints

✅ Complete documentation:
- API documentation
- Deployment guide
- Security guidelines
- Production checklist

Ready for production deployment!"

# Отправить ветку на GitHub
git push -u origin release/v2.0.0-production-ready
```

### 3. Создание Pull Request
После создания ветки:

1. Перейти на GitHub: https://github.com/normaldance/normaldance-platform
2. Нажать "Compare & pull request"
3. Заполнить описание PR:

```markdown
# 🚀 Production Ready Release v2.0.0

## Summary
Major production-ready release with comprehensive security fixes and infrastructure improvements.

## Changes
- ✅ All critical security vulnerabilities fixed
- ✅ Production infrastructure templates ready
- ✅ Complete CI/CD pipeline implemented
- ✅ Monitoring and alerting configured
- ✅ Full documentation suite

## Testing
- [x] Security tests passing
- [x] E2E tests passing  
- [x] Performance tests passing
- [x] Infrastructure tests passing

## Deployment
Ready for immediate production deployment with one-click script.

## Breaking Changes
- Environment variables structure updated
- New security headers implemented
- Updated authentication requirements

## Checklist
- [x] Security audit completed
- [x] Performance testing done
- [x] Documentation updated
- [x] Deployment tested
- [x] Rollback plan ready
```

### 4. Создание Release на GitHub
После мержа PR:

```bash
# Создать тег
git tag -a v2.0.0 -m "Production Ready Release v2.0.0"
git push origin v2.0.0

# Или через GitHub CLI
gh release create v2.0.0 \
  --title "NormalDance v2.0.0 - Production Ready" \
  --notes-file RELEASE_NOTES_v2.0.0.md \
  --prerelease
```

## 📋 Checklist перед созданием ветки

- [ ] Все файлы созданы и протестированы
- [ ] Security fixes реализованы
- [ ] Infrastructure templates готовы
- [ ] CI/CD pipeline настроен
- [ ] Documentation обновлена
- [ ] Release notes подготовлены

## 🎯 Результат

После выполнения команд получите:
- ✅ Новую ветку `release/v2.0.0-production-ready`
- ✅ Все изменения закоммичены
- ✅ Ветка отправлена на GitHub
- ✅ Готов для создания Pull Request
- ✅ Готов для production deployment