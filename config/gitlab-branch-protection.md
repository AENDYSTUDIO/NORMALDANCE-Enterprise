# Примеры Настроек Защиты Веток для GitLab

## Общие Рекомендации

В GitLab настройте защиту веток в **Project Settings > Repository > Protected branches**. Это предотвращает прямые push в защищённые ветки (main, master, develop) и требует code review, status checks.

- **Allowed to push**: Только Maintainers (не Developers).
- **Allowed to merge**: Maintainers после approvals.
- **Code owner approval**: Required для security files (e.g., \*.key, .env).
- **Require status checks**: Интегрируйте с CI jobs (scan-secrets, security-scan).
- **Force push**: Disabled.
- **Delete branch**: Allowed only for Maintainers.

## Примеры Конфигураций

### 1. Защита Main Branch

- **Branch name**: `main`
- **Allowed to push and merge**: Maintainers
- **Allowed to push**: No one (только через MR)
- **Allowed to merge**: Maintainers
- **Require approval from code owners**: Yes
- **Minimum number of approvals**: 2
- **Require status checks to pass before merging**:
  - `scan-secrets`
  - `security-scan`
  - `test`
- **Push rules**:
  - Reject unsigned commits: Yes (GPG sign required)
  - Reject force pushes: Yes
  - Reject non-linear history: Yes

API для автоматизации (используйте в скриптах):

```
curl --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  --request POST "https://gitlab.com/api/v4/projects/:id/protected_branches" \
  --form "name=main" \
  --form "push_access_levels=40" \  # Maintainer=40
  --form "merge_access_levels=40" \
  --form "code_owner_approval_required=true" \
  --form "approvals_required=2"
```

### 2. Защита Develop Branch

- **Branch name**: `develop`
- **Allowed to push**: Developers (для feature merges)
- **Allowed to merge**: Maintainers
- **Require status checks**:
  - `build`
  - `test`
- **Wildcard protection**: `develop-*` для sub-branches.

### 3. Защита Feature Branches (Ограничения)

Feature branches не защищены напрямую, но:

- Используйте **Repository rules** (GitLab Premium): Restrict push to `feature/*` для Developers.
- Интеграция с CI: Автоматический scan в .gitlab-ci.yml.

### 4. Защита Release Tags

- **Branch name**: `v*` (для тегов)
- **Allowed to create**: Maintainers
- **Require status checks**: `deploy`

### Интеграция с RBAC

- Group-level protection: В Group Settings > Permissions для inheritance.
- SAML/OAuth: Динамические роли via external auth.

### Troubleshooting

- Если MR не merges: Проверьте status checks в Pipeline.
- Аудит: Просмотр в Audit Events.

Эти настройки обеспечивают compliance с OWASP/NIST. Для Bitbucket аналогично в Repository Settings > Branch permissions.
