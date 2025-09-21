# Комплексный Безопасный Git-Воркфлоу с Автоматизированным Управлением Криптографическими Ключами

## Введение

Этот документ описывает комплексный Git-воркфлоу, адаптированный для платформ GitLab и Bitbucket (учётная запись: andykachess). Воркфлоу обеспечивает высокий уровень безопасности, минимизирует риски утечек ключей и интегрируется с CI/CD инструментами. Он соответствует лучшим практикам OWASP, NIST и другим стандартам (например, SOC2, GDPR).

Ключевые принципы:

- **Автоматизация**: Все процессы (сканирование, ротация ключей, очистка) автоматизированы через скрипты и CI/CD.
- **Масштабируемость**: Поддержка multi-repo/group/workspace структур.
- **Кросс-платформенность**: Примеры для GitLab и Bitbucket с рекомендациями по миграции.
- **Безопасность по умолчанию**: Нет хардкода ключей, временные токены, изоляция.

Воркфлоу использует:

- Git-хуки (pre-commit, pre-push, pre-receive).
- CI/CD: GitLab CI (.gitlab-ci.yml), Bitbucket Pipelines (bitbucket-pipelines.yml).
- Хранилища ключей: GitLab/Bitbucket Variables, AWS Secrets Manager, HashiCorp Vault.
- Инструменты: git-secrets, TruffleHog, Gitleaks, Docker для изоляции.

**Предварительные требования**:

- Учётная запись andykachess с правами Maintainer/Owner.
- Установка Git LFS, GPG, Docker.
- Интеграция с внешними сервисами (Slack, Jira, Vault).

## 1. Контроль Доступа к Ключам

### RBAC на Основе Ролей

- **GitLab**: Используйте Groups/Projects для ролей (Guest, Reporter, Developer, Maintainer, Owner). Доступ к ключам только для Developer+ в feature-ветках (префикс "feature/").
  - Настройка: В Project Settings > Members > Assign roles. Используйте Group-level policies для inheritance.
- **Bitbucket**: Workspaces/Repositories с ролями (Admin, Write, Read). Доступ к ключам только при создании feature-ветки.
  - Настройка: Repository Settings > User and group access.

Автоматический доступ: При создании feature-ветки (via API или UI) генерируйте временный JWT/SSH-ключ с TTL=1h через GitLab API (`/api/v4/projects/:id/repository/files`) или Bitbucket API (`/2.0/repositories/{workspace}/{repo_slug}/ssh-keys`).

### Блокировка Защищённых Веток

- **Серверные Хуки**: Pre-receive/update хуки блокируют push в main/master/develop.
  - GitLab: Custom hooks в Project Settings > Repository > Hooks.
  - Bitbucket: Server-side hooks via add-ons (e.g., ScriptRunner).
- **Правила Защиты**:
  - GitLab: Repository > Settings > Protected branches (Require code owner approval, No push for non-maintainers).
  - Bitbucket: Repository Settings > Branch permissions (Restrict changes to main, Require pull request reviews).
- Интеграция CI/CD: Required status checks (security scans) перед merge.

### Временные Токены

- Генерация: Bash-скрипт для JWT (TTL=1h) via OAuth/SAML.
  Пример скрипта (`generate-token.sh`):
  ```
  #!/bin/bash
  JWT_SECRET=$(vault read -field=secret transit/encrypt/my-key)
  JWT=$(echo -n '{"sub":"andykachess","exp":$(( $(date +%s) + 3600 ))}' | openssl dgst -sha256 -hmac $JWT_SECRET -binary | base64)
  echo $JWT > .tmp/token.jwt
  ```
- Интеграция: SAML для динамических ролей (GitLab: Settings > SAML; Bitbucket: Workspace Settings > Authentication).

### Аудит Доступа

- Логи: GitLab Audit Events, Bitbucket Audit Logs. Экспорт в ELK/Splunk.

## 2. Механизмы Предотвращения Утечек

### Git-Хуки для Сканирования

- **Pre-commit/Pre-push**: Локальные хуки сканируют на секреты.
  - Инструменты: git-secrets, TruffleHog, Gitleaks.
  - Установка: `git secrets --install`, добавить паттерны в `.gitsecrets`.
  - Пример pre-commit hook (`.git/hooks/pre-commit`):
    ```
    #!/bin/sh
    if ! git-secrets --scan; then
      echo "Secrets detected! Commit rejected."
      exit 1
    fi
    trufflehog --path . --since-commit HEAD~1
    ```
- **Pre-receive**: Серверный хук для входящих push.
  - GitLab: Custom server hook.
  - Bitbucket: Pre-receive hook script.

Интеграция: GitLab Security Scanning (в .gitlab-ci.yml), Bitbucket Code Insights.

### Автоматический Откат

- CI-скрипт: При обнаружении секрета - revert commit, notify via Slack/email.
  Пример в CI (см. раздел 6).

### Изолированные Feature-Ветки

- Обязательный префикс "feature/". Ключи извлекаются временно в `.tmp/` директорию.
- Очистка: Post-merge webhook удаляет ключи (`git clean -fd; rm -rf .tmp`).
- Блокировка больших файлов: Pre-receive hook + LFS.
  Пример hook:
  ```
  if [[ $(git ls-files | xargs wc -c | tail -1 | awk '{print $1}') -gt 10485760 ]]; then
    echo "File >10MB! Use LFS."
    exit 1
  fi
  ```

### Шифрование Файлов

- Перед работой: `gpg --encrypt --recipient andykachess keys.asc`.
- После: Автоматическая очистка via cron в CI (TTL=30min).

### Изоляция Окружений

- Docker containers: Монтируйте только `/tmp` для ключей.
  Пример Dockerfile:
  ```
  FROM alpine
  RUN apk add git gpg
  VOLUME ["/workspace", "/tmp/keys"]
  CMD ["git", "clone", "$REPO"]
  ```
- CI Runners: GitLab Shared Runners с ephemeral storage.

## 3. Управление Жизненным Циклом Ключей

### Извлечение Ключей

- При checkout feature-ветки: Pull request approval → extract via CI Variables/Vault.
  Пример: `vault kv get -field=key secret/keys/feature-$(git branch --show-current)`.

### Очистка

- Pre-switch hook: `shred -u keys/*; sdelete keys/*` (Windows: sdelete).
- Таймаут: Cron в CI (`*/30 * * * * timeout-check.sh`).

### Ротация Ключей

- Еженедельно: Scheduled pipeline.
  Пример скрипт (`rotate-keys.sh`):
  ```
  #!/bin/bash
  NEW_KEY=$(vault write transit/keys/my-key rotate=true)
  OLD_KEY=$(vault read -field=old transit/keys/my-key)
  shred -u $OLD_KEY
  echo "Rotated: $NEW_KEY"
  ```
- Обновление: В хранилище, notify team.

### Журнал Ключей

- Encrypted repo: `git init keys-audit; gpg --encrypt commit.msg`.
- Версионирование: PGP sign commits (`git commit -S`).

## 4. Контроль Доступа на Уровне Репозитория

### Права Доступа

- GitLab: Developers - write only to feature/\*; Maintainers - protected branches.
- Bitbucket: Write role - feature branches only.

### Блокировка Push/Merge

- Branch protection: No direct push to main, require CI checks.
- Code Review: Min 2 approvers for security-related MR/PR.

### Required Checks

- Status checks: SAST/DAST via Semgrep, OWASP ZAP.

## 5. Аудит и Мониторинг

### Логирование

- ELK Stack: Forward logs via Filebeat.
- Шифрование: TLS + AES-256.

### Уведомления

- Webhooks: Slack bot для алертов.
  Пример: GitLab Webhook → Slack API.

### Раннее Предупреждение

- ML: GitLab Security Dashboard или custom (anomaly detection via ELK ML).

### Отчёты

- Еженедельно: Scheduled job → GitLab Insights dashboard.

### SIEM Интеграция

- Экспорт: Real-time via API to Splunk/ELK.

## 6. Автоматизация

### Скрипты для Веток

- Создание feature: `create-feature.sh` с шаблонами CI.
  ```
  #!/bin/bash
  git checkout -b feature/$1
  cp .gitlab-ci.template.yml .gitlab-ci.yml
  git add .gitlab-ci.yml
  git commit -m "Init feature branch"
  ```

### CI/CD Интеграция

- **GitLab CI (.gitlab-ci.yml)**:

  ```
  stages:
    - scan
    - build
    - test
    - security
    - deploy

  scan:
    stage: scan
    script:
      - git-secrets --scan
      - trufflehog --path .
    rules:
      - if: $CI_COMMIT_REF_NAME =~ /^feature\//

  security:
    stage: security
    script:
      - semgrep --config=auto .
      - OWASP_ZAP --spider $CI_PROJECT_URL
    artifacts:
      reports:
        sast: gl-sast-report.json

  build:
    stage: build
    script:
      - npm ci
      - npm run build
    only:
      - feature/*
      - main

  deploy:
    stage: deploy
    script:
      - echo "Deploy to staging"
      - vault kv put secret/deploy key=$NEW_KEY
    when: manual
    only:
      - main
  ```

- **Bitbucket Pipelines (bitbucket-pipelines.yml)**:
  ```
  pipelines:
    branches:
      feature/*:
        - step:
            name: Scan
            script:
              - git-secrets --scan .
              - trufflehog --path .
        - step:
            name: Security
            script:
              - semgrep --config=auto .
          services:
            - docker
      main:
        - step:
            name: Build and Deploy
            deployment: staging
            script:
              - npm ci
              - npm run build
              - pipe: atlassian/aws-secrets-manager-injector:0.4.0
                variables:
                  AWS_DEFAULT_REGION: 'us-east-1'
                  SECRET_ID: 'my-keys'
  ```

### Автоматизация Тегов

- Post-successful pipeline: `git tag v$(semver up -p patch); git push --tags`.

### Rollback

- CI trigger: `git bisect` или revert to tag.
- Интеграция Jira: Auto-ticket via webhook.

### ITSM

- Jira: Webhook для breaches → create issue.

## 7. Обработка Релизов

### Теги Релизов

- Только из main после pipeline + 2 approvals.
- Semantic versioning: Conventional commits.
- Changelog: `conventional-changelog -p angular -i CHANGELOG.md`.

### Верификация

- Post-push: `git fetch; git verify-tag vX.Y.Z`.

### Hotfix

- Ветки "hotfix/": Bypass reviews, но mandatory scans.
- Post-merge: Rotate keys.

### История Версий

- Rollback: `git revert --no-commit $(git rev-list -n 1 v1.0.0..HEAD)`.

## 8. Дополнительные Требования

### Документация

- Храните в GitLab Wiki/Bitbucket Wiki.
- API Endpoints: `/api/v4/projects/:id/merge_requests` для approvals.
- Troubleshooting: "If hook fails: check permissions".

### Аудит и Pentesting

- Ежеквартально: Internal audit + Burp Suite.
- Ежемесячно: Pentesting (simulate exfiltration).

### Обучение

- Onboarding: Sessions + quizzes (e.g., via GitLab Pages).
- Annual refreshers.

### Bug Bounty

- HackerOne: Tied to andykachess repos, rewards $100-1000.

## Рекомендации по Миграции (GitLab ↔ Bitbucket)

- Экспорт: `git clone --mirror; tar czf repo.tar.gz .git`.
- Импорт: GitLab Import Project / Bitbucket Import Repository.
- CI: Конвертировать .gitlab-ci.yml в bitbucket-pipelines.yml (используйте yaml converters).
- Хуки: Перенос custom hooks via API.
- Ключи: Migrate Variables via export/import scripts.

Этот воркфлоу готов к внедрению. Для кастомизации обратитесь к andykachess.
