# 🔐 NORMALDANCE Security Workflow

Комплексная система безопасности для управления криптографическими ключами и контроля доступа к репозиторию.

## 📋 Содержание

- [Обзор системы](#обзор-системы)
- [Контроль доступа к ключам](#контроль-доступа-к-ключам)
- [Механизмы предотвращения утечек](#механизмы-предотвращения-утечек)
- [Управление жизненным циклом ключей](#управление-жизненным-циклом-ключей)
- [Контроль доступа на уровне репозитория](#контроль-доступа-на-уровне-репозитория)
- [Аудит и мониторинг](#аудит-и-мониторинг)
- [Автоматизация](#автоматизация)
- [Обработка релизов](#обработка-релизов)
- [Дополнительные требования](#дополнительные-требования)

## 🎯 Обзор системы

NORMALDANCE Security Workflow обеспечивает:

- ✅ **Гранулярный контроль доступа** к криптографическим ключам
- ✅ **Автоматическое сканирование** на наличие чувствительных данных
- ✅ **Ролевая система доступа** (RBAC) для управления ключами
- ✅ **Централизованный аудит** всех операций с ключами
- ✅ **Автоматические уведомления** о нарушениях безопасности
- ✅ **Защита веток** от прямых коммитов
- ✅ **Интеграция с CI/CD** для проверок безопасности

## 🔑 Контроль доступа к ключам

### Система ролей (RBAC)

```typescript
// Роли пользователей
const roles = {
  developer: {
    level: 3,
    permissions: ["read:repository:feature/*", "write:repository:feature/*"],
  },
  "senior-developer": {
    level: 5,
    permissions: ["read:repository:*", "write:repository:feature/*,staging/*"],
  },
  devops: {
    level: 7,
    permissions: ["access:keys:development,staging,production"],
  },
  admin: {
    level: 10,
    permissions: ["*:*:*"],
  },
};
```

### Временные токены доступа

```bash
# Создание временного токена (30 минут)
npm run security:create-token -- --user=developer --duration=30

# Проверка токена
npm run security:validate-token -- --token=abc123...
```

### Интеграция с системой аутентификации

```typescript
// Проверка доступа к ключу
const hasAccess = rbacManager.hasPermission(userId, "access", "keys", {
  environment: "production",
  branch: "main",
});
```

## 🛡️ Механизмы предотвращения утечек

### Git-хуки для безопасности

#### Pre-commit Hook

```bash
# Автоматическая проверка перед коммитом
.git/hooks/pre-commit
```

**Проверяет:**

- Наличие чувствительных данных (API ключи, пароли, токены)
- Размер файлов (>10MB блокируется)
- Соответствие ветки политикам безопасности
- Корректность сообщения коммита

#### Pre-push Hook

```bash
# Проверка перед отправкой в удалённый репозиторий
.git/hooks/pre-push
```

**Проверяет:**

- Блокировку прямых коммитов в main/master
- Обязательное использование feature-веток
- Валидацию тегов релизов

### Автоматическое сканирование секретов

```bash
# Установка инструментов сканирования
npm install -g trufflehog gitleaks

# Сканирование репозитория
npm run security:scan-secrets
```

**Поддерживаемые паттерны:**

- API ключи: `api[_-]?key`
- JWT токены: `eyJ[A-Za-z0-9+/=]+`
- Приватные ключи: `BEGIN.*PRIVATE KEY`
- Пароли: `password`
- Секреты: `secret`

### Автоматический откат небезопасных изменений

```typescript
// Автоматический откат при обнаружении секретов
if (detectedSecrets.length > 0) {
  await git.reset("--hard", "HEAD~1");
  await notifySecurityTeam(detectedSecrets);
}
```

## 🔄 Управление жизненным циклом ключей

### Автоматическое извлечение ключей

```bash
# Создание feature-ветки с автоматическим извлечением ключей
npm run security:create-feature-branch -- --name=feature/new-auth

# Извлечение ключей из защищённого хранилища
npm run security:extract-keys -- --environment=development
```

### Принудительная очистка ключей

```typescript
// Автоматическая очистка при переключении веток
git.on("checkout", async () => {
  await clearLocalKeys();
  await logKeyAccess("branch_switch", currentBranch);
});
```

### Ротация ключей

```bash
# Еженедельная ротация ключей
npm run security:rotate-keys -- --schedule=weekly

# Экстренная ротация при компрометации
npm run security:rotate-keys -- --emergency --reason="suspected_compromise"
```

## 🌿 Контроль доступа на уровне репозитория

### Настройка прав репозитория

```yaml
# .github/settings.yml
repository:
  name: NORMALDANCE-Enterprise
  default_branch: main

  # Защита веток
  branch_protection:
    main:
      required_status_checks:
        - security-scan
        - dependency-check
      enforce_admins: true
      required_pull_request_reviews:
        required_approving_review_count: 2
        dismiss_stale_reviews: true
      restrictions:
        users: []
        teams: ["senior-developers", "devops"]
```

### Branch Protection Rules

```bash
# Настройка защиты веток через GitHub CLI
gh api repos/:owner/:repo/branches/main/protection \
  --method PUT \
  --field required_status_checks='{"strict":true,"contexts":["security-scan"]}' \
  --field enforce_admins=true \
  --field required_pull_request_reviews='{"required_approving_review_count":2}'
```

### Механизм Code Review

```typescript
// Обязательный code review для изменений безопасности
const requiresReview = (files: string[]) => {
  const securityFiles = files.filter(
    (file) =>
      file.includes("security/") ||
      file.includes("auth/") ||
      file.includes("keys/")
  );

  return securityFiles.length > 0;
};
```

## 📊 Аудит и мониторинг

### Централизованное логирование

```typescript
// Логирование всех операций с ключами
const auditLog = {
  timestamp: new Date(),
  userId: "developer123",
  action: "key_access",
  resource: "production_keys",
  success: true,
  ipAddress: "192.168.1.100",
  userAgent: "Git/2.34.1",
};
```

### Система уведомлений

```yaml
# Конфигурация уведомлений
notifications:
  slack:
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
    channel: "#security"
  email:
    recipients: ["security@normaldance.com"]
  telegram:
    bot_token: ${{ secrets.TELEGRAM_BOT_TOKEN }}
    chat_id: ${{ secrets.TELEGRAM_CHAT_ID }}
```

### Мониторинг в реальном времени

```typescript
// Отслеживание подозрительной активности
securityMonitor.on("suspiciousActivity", (event) => {
  if (event.failedLogins > 5) {
    sendAlert("Multiple failed login attempts", event);
  }
});
```

## 🤖 Автоматизация

### Скрипты для создания feature-веток

```bash
#!/bin/bash
# scripts/create-secure-feature-branch.sh

BRANCH_NAME="feature/$1"
ENVIRONMENT="$2"

# Создание ветки с предустановленными политиками
git checkout -b "$BRANCH_NAME"

# Настройка политик безопасности
echo "security.environment=$ENVIRONMENT" > .git/security-config
echo "security.branch=$BRANCH_NAME" >> .git/security-config

# Извлечение ключей для окружения
npm run security:extract-keys -- --environment="$ENVIRONMENT"

echo "✅ Безопасная feature-ветка создана: $BRANCH_NAME"
```

### CI/CD интеграция

```yaml
# .github/workflows/security-pipeline.yml
name: Security Pipeline
on: [push, pull_request]

jobs:
  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run security scan
        run: npm run security:scan
      - name: Check for secrets
        run: npm run security:scan-secrets
```

### Автоматизация тегов релизов

```bash
# Автоматическое создание тегов после успешной сборки
npm run security:create-release-tag -- --version=v1.2.3 --environment=production
```

## 🚀 Обработка релизов

### Создание тегов только из main

```bash
# Проверка ветки перед созданием тега
if [[ "$(git branch --show-current)" != "main" ]]; then
  echo "❌ Теги можно создавать только из ветки main"
  exit 1
fi

# Создание тега после всех проверок
git tag -a "v$VERSION" -m "Release $VERSION"
git push origin "v$VERSION"
```

### Верификация целостности тегов

```bash
# Проверка доступности тега в удалённом репозитории
npm run security:verify-tag -- --tag="v1.2.3" --remote="origin"
```

### Hotfix-ветки для экстренных исправлений

```bash
# Создание hotfix-ветки с отдельным процессом безопасности
npm run security:create-hotfix -- --issue="SECURITY-123" --severity="critical"
```

## 📚 Дополнительные требования

### Документация процессов

- [Security Policy](SECURITY_POLICY.md)
- [Incident Response Plan](INCIDENT_RESPONSE.md)
- [Key Management Procedures](KEY_MANAGEMENT.md)
- [Audit Procedures](AUDIT_PROCEDURES.md)

### Регулярный аудит

```bash
# Ежеквартальный аудит безопасности
npm run security:quarterly-audit

# Ежемесячное тестирование на проникновение
npm run security:penetration-test
```

### Обучение разработчиков

```bash
# Запуск тренинга по безопасности
npm run security:training -- --module="git-security" --user="developer123"
```

### Bug Bounty программа

```typescript
// Система вознаграждений за обнаружение уязвимостей
const bugBounty = {
  critical: 10000, // $10,000
  high: 5000, // $5,000
  medium: 1000, // $1,000
  low: 100, // $100
};
```

## 🚨 Экстренные процедуры

### При обнаружении утечки ключа

1. **Немедленная ротация ключа**

   ```bash
   npm run security:emergency-rotate -- --key="compromised_key_id"
   ```

2. **Уведомление команды безопасности**

   ```bash
   npm run security:alert-team -- --severity="critical" --reason="key_compromise"
   ```

3. **Аудит доступа**
   ```bash
   npm run security:audit-access -- --key="compromised_key_id" --timeframe="30d"
   ```

### При нарушении безопасности

1. **Блокировка доступа**

   ```bash
   npm run security:block-user -- --user="compromised_user" --reason="security_breach"
   ```

2. **Отзыв всех активных сессий**

   ```bash
   npm run security:revoke-sessions -- --user="compromised_user"
   ```

3. **Создание инцидента**
   ```bash
   npm run security:create-incident -- --severity="critical" --description="Security breach detected"
   ```

## 📞 Контакты

- **Security Team**: security@normaldance.com
- **Emergency Hotline**: +1-800-SECURITY
- **Slack Channel**: #security-alerts
- **Documentation**: [docs.normaldance.com/security](https://docs.normaldance.com/security)

---

**⚠️ Важно**: Все операции с ключами логируются и мониторятся. Нарушение политик безопасности может привести к блокировке доступа.

