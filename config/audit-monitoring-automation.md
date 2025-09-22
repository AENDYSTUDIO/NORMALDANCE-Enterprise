# Рекомендации по Аудиту, Мониторингу и Автоматизации

## Введение

Этот документ предоставляет рекомендации по реализации аудита, мониторинга и автоматизации в рамках безопасного Git-воркфлоу. Фокус на централизованном логировании, уведомлениях, ML-анализе и интеграции с ITSM. Соответствует OWASP, NIST (e.g., SP 800-53 для аудита).

Ключевые цели:

- **Аудит**: Полный трекинг операций с ключами (access, modify, delete).
- **Мониторинг**: Real-time алерты на нарушения, anomaly detection.
- **Автоматизация**: Scheduled jobs, webhooks, rollback mechanisms.
- **Retention**: 90 дней для логов, шифрование (TLS + AES-256).

Интеграция: ELK Stack (Elasticsearch, Logstash, Kibana), Slack/Telegram, Jira. Для GitLab/Bitbucket - встроенные logs + export.

## 1. Аудит

### Централизованное Логирование

- **Источники**: Git hooks, CI jobs, Vault/AWS API calls, branch protections.
- **Формат**: JSON с timestamps, user ID (andykachess), action (e.g., "key-extract"), IP.
- **Хранение**: ELK Stack или GitLab Audit Events/Bitbucket Audit Logs.
  - GitLab: Включите в Project Settings > General > Audit events.
  - Bitbucket: Workspace Settings > Audit log (export via API).

Пример скрипта для логирования в hooks (добавьте в pre-commit.sh и т.д.):

```
#!/bin/bash
LOG_DIR="/var/log/git-audit"
mkdir -p $LOG_DIR
echo "$(date '+%Y-%m-%d %H:%M:%S') | User: $USER | Action: commit | Branch: $(git branch --show-current) | SHA: $(git rev-parse HEAD)" >> $LOG_DIR/audit.log
# Шифрование: gpg --encrypt --recipient andykachess $LOG_DIR/audit.log
```

### Интеграция с SIEM

- **Экспорт**: Real-time via Filebeat (to ELK) или API.
  - GitLab: `/api/v4/audit_events` (cron job: curl + jq).
  - Bitbucket: `/2.0/workspaces/{workspace}/audit` (script для polling).
- **Корреляция**: В ELK - queries для patterns (e.g., multiple failed extracts).
- **Retention Policy**: 90 дней, auto-delete старых логов (cron: find $LOG_DIR -mtime +90 -delete).

### Аудит Ключей

- Vault: `vault audit enable file file_path=/var/log/vault.log`.
- AWS: CloudTrail для Secrets Manager (filter: eventName=GetSecretValue).
- Версионированный журнал: Encrypted Git repo (gpg sign commits).

Еженедельные отчёты: Scheduled pipeline → generate PDF via pandoc, send to dashboard.

## 2. Мониторинг

### Уведомления

- **Triggers**: Violations (secrets detected, unauthorized access), pipeline failures.
- **Каналы**: Slack bots, email (SendGrid), Telegram.
- **Webhooks**:
  - GitLab: Project Settings > Webhooks → Slack integration (payload: {"text": "Alert: Secret in commit $CI_COMMIT_SHA"}).
  - Bitbucket: Repository Settings > Webhooks → URL: Slack API.

Пример webhook payload для Slack:

```
{
  "text": "🚨 Security Alert: Unauthorized push to main by $USER",
  "attachments": [
    {
      "color": "danger",
      "fields": [
        {"title": "Branch", "value": "$CI_COMMIT_REF_NAME"},
        {"title": "Repo", "value": "$CI_PROJECT_PATH"}
      ]
    }
  ]
}
```

- **Email**: CI script: `curl -X POST https://api.sendgrid.com/v3/mail/send -d '{"personalizations": [{"to": [{"email": "andykachess@example.com"}]}],"from": {"email": "alert@repo.com"},"subject": "Git Security Breach","content": [{"type": "text/plain","value": "Details..."}]}'`.

### Раннее Предупреждение

- **ML Anomaly Detection**: GitLab Security Dashboard (built-in ML) или ELK ML jobs.
  - Пример ELK query: Detect unusual access (e.g., >5 extracts/hour).
- **Custom**: Python script с scikit-learn для patterns (e.g., non-feature branch access).
- **Метрики**: Key usage count, scan failures - в GitLab Insights/Bitbucket Analytics.

### Еженедельные Отчёты

- Scheduled job: Aggregate logs → dashboard (Kibana).
- Пример: `python report.py --from yesterday --to today --output compliance-report.md`.

## 3. Автоматизация

### Scheduled Pipelines

- **GitLab**: CI/CD > Schedules → cron: "0 0 \* \* 0" (Sunday midnight) для ротации/отчётов.
  - Job: rotate-keys + generate-report.
- **Bitbucket**: Pipelines > Schedules → аналогично.

Пример в .gitlab-ci.yml:

```
weekly-audit:
  stage: deploy
  script:
    - python scripts/generate-audit.py
    - curl -X POST $SLACK_WEBHOOK -d '{"text":"Weekly report attached"}'
  rules:
    - if: $CI_PIPELINE_SOURCE == "schedule"
```

### Rollback Mechanisms

- **Автоматический Revert**: При post-deploy issues - trigger via webhook.
  Пример скрипт (`rollback.sh`):
  ```
  #!/bin/bash
  git revert --no-commit HEAD
  git push origin HEAD:main
  curl -X POST $JIRA_WEBHOOK -d '{"issue": {"key": "SEC-123", "fields": {"summary": "Auto-rollback due to breach"}}}'
  ```
- **Git Bisect**: В CI для root cause: `git bisect start bad good; git bisect run test-script.sh`.

### Интеграция с ITSM (Jira/ServiceNow)

- **Auto-Ticket**: Webhook на breaches.
  - GitLab/Bitbucket Webhook → Jira API: Create issue in "Security" project.
    Пример: `curl -u user:token -X POST https://jira.example.com/rest/api/2/issue/ -H "Content-Type: application/json" -d '{"fields":{"project":{"key":"SEC"},"summary":"Breach: Secret detected","description":"Details from $CI_COMMIT_SHA","issuetype":{"name":"Bug"}}}'`.
- **Escalation**: If repeat violations - lock account via API (GitLab: `/api/v4/users/:id/block`).

### Дополнительная Автоматизация

- **Key Cleanup**: Cron в CI: `*/30 * * * * find .tmp -mtime +0.02 -delete` (30min timeout).
- **Onboarding**: Script для new feature branch: `create-feature.sh` (setup hooks, CI template).
- **Pentesting**: Monthly scheduled: Run Burp Suite via Docker в pipeline.

## Best Practices

- **Compliance**: SOC2/GDPR - encrypt logs, access controls.
- **Testing**: Mock alerts в dev (e.g., test webhooks).
- **Scalability**: Use Kubernetes для ELK если multi-repo.
- **Troubleshooting**: Если webhook fails - fallback to email; monitor log volume.

Эти рекомендации интегрируются с предыдущими конфигурациями. Для внедрения - начните с webhook setup.
