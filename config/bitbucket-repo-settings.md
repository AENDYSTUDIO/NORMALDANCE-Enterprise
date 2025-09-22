# Примеры Настроек Репозитория для Bitbucket

## Общие Рекомендации

В Bitbucket настройте репозиторий в **Repository Settings**. Это включает branch permissions, merge checks, access controls для предотвращения утечек и обеспечения RBAC.

- **User and group access**: Роли - Admin (полный доступ), Write (только feature branches), Read.
- **Branch permissions**: Защита main/develop от прямых push.
- **Merge checks**: Required pull requests, approvals, status checks.
- **Repository variables**: Для ключей (masked, protected).
- **Hooks**: Pre-receive для серверных проверок (требует add-ons как ScriptRunner).
- **Code insights**: Интеграция с security scans.

## Примеры Конфигураций

### 1. Доступ к Репозиторию (User and Group Access)

- **Workspace access**: Только для группы "Developers" с Write ролью.
- **Repository access**:
  - andykachess: Admin
  - Developers group: Write (ограничено feature/\*)
  - Auditors: Read-only
- API для управления (используйте в скриптах):
  ```
  curl -u andykachess:token \
    -X PUT "https://api.bitbucket.org/2.0/repositories/andykachess/my-repo/permissions-config/users/andykachess" \
    -H "Content-Type: application/json" \
    -d '{
      "type": "repository",
      "permission": "admin"
    }'
  ```

### 2. Защита Веток (Branch Permissions)

- **Branch pattern**: `main`

  - Restrict changes: Yes
  - Prevent all changes: Yes (только через PR)
  - Who can write: Admin only
  - Require pull request: Yes
  - Minimum reviewers: 2
  - Require build status: Yes (интегрируйте с Pipelines: scan-secrets, security-scan)
  - Ban force push: Yes
  - Ban delete: Yes

- **Branch pattern**: `develop`

  - Who can write: Write role (Developers)
  - Require pull request: Yes
  - Minimum reviewers: 1

- **Branch pattern**: `feature/*`

  - Who can write: Write role
  - No restrictions on push (но CI scans enforced)

- **Branch pattern**: `hotfix/*`
  - Similar to feature, but accelerated merge.

API для branch permissions:

```
curl -u andykachess:token \
  -X POST "https://api.bitbucket.org/2.0/repositories/andykachess/my-repo/branch-permissions" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "branch-permission",
    "pattern": "main",
    "write_permissions": ["andykachess"],
    "merge_checks": {
      "minimum_number_of_approvals": 2,
      "require_build_status": true
    }
  }'
```

### 3. Merge Checks (Pull Requests)

- **Minimum number of approvals**: 2 для security-related PR.
- **Require build status**: Pipelines must pass (scan-secrets, test).
- **Require linked issues**: Yes (интеграция с Jira).
- **Block merges with conflicts**: Yes.
- **Delete source branch after merge**: Yes (автоматическая очистка).

### 4. Repository Variables для Ключей

- **Key**: `VAULT_TOKEN` - Value: masked secret from Vault.
- **Key**: `AWS_SECRET_ID` - Protected: Yes (только в pipelines).
- **Key**: `SLACK_WEBHOOK` - Masked: Yes.

Настройка: Repository Settings > Repository variables > Add variable.

### 5. Интеграция с Code Insights

- Включите Security scans: TruffleHog, Semgrep via Pipelines.
- Reports: Upload artifacts to Bitbucket для dashboard.

### 6. Хуки (Hooks)

- **Pre-receive**: Для серверных проверок (требует Bitbucket Server или add-ons).
  Пример: ScriptRunner для execution `git-secrets --scan` на push.
- Webhooks: Для уведомлений (Slack, Jira) на events (push, merge).

### Troubleshooting

- Если PR не merges: Проверьте build status в Pipelines.
- Аудит: Bitbucket Audit Logs в Workspace Settings.

Эти настройки обеспечивают кросс-платформенную совместимость с GitLab. Для миграции используйте Bitbucket Import tool.
