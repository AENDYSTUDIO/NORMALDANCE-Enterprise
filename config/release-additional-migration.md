# Обработка Релизов, Дополнительные Требования и Миграция

## Введение

Этот документ дополняет основной воркфлоу, фокусируясь на обработке релизов, дополнительных требованиях (аудит, обучение, bug bounty) и миграции между GitLab и Bitbucket. Обеспечивает semantic versioning, compliance и seamless переход.

## 1. Обработка Релизов

### Теги Релизов (vX.Y.Z)

- **Создание**: Только из main/master после full pipeline (security checks, code review, min 2 approvals).
- **Semantic Versioning**: Используйте conventional commits (feat:, fix:, etc.) для auto-increment.
- **Автоматизация**: Post-successful pipeline - create tag, push with GPG sign.
  Пример скрипт (`create-release.sh`):

  ```
  #!/bin/bash
  # Требует semver npm package

  CURRENT_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
  NEW_TAG=$(npm run semver -- inc patch $CURRENT_TAG)
  git tag -a $NEW_TAG -m "Release $NEW_TAG"
  git push origin $NEW_TAG
  # Changelog
  conventional-changelog -p angular -i CHANGELOG.md -s
  git add CHANGELOG.md
  git commit -m "docs: update changelog"
  git push origin main
  echo "Release $NEW_TAG created and pushed."
  ```

- **Верификация**: Post-push - fetch + verify-tag.
  В CI: `git fetch; git verify-tag $NEW_TAG`.

### Hotfix-Ветки

- **Префикс**: "hotfix/".
- **Процесс**: Accelerated - bypass non-critical reviews, но mandatory security scans (scan-secrets, security-scan).
- **Post-Merge**: Автоматическая ротация ключей + notify.
  Пример в CI: `if [[ $CI_COMMIT_REF_NAME =~ ^hotfix/ ]]; then ./scripts/rotate-keys.sh; fi`.

### Changelog Generation

- **Tool**: conventional-changelog или github-release-notes.
- **Security Impact**: Добавьте раздел "Security Changes" с анализом (e.g., "Rotated keys, fixed leak in hook").
- **Автоматизация**: В release job: `conventional-changelog -p angular -r 2 -i CHANGELOG.md -s`.

### История Версий и Rollback

- **Dedicated Branches/Tags**: `release/v1.0` для history.
- **Rollback Capability**: Test in staging: `git checkout v1.0.0; git revert HEAD..v1.1.0`.
- **Автоматизация**: CI trigger для rollback (manual job): `git revert --no-commit $(git rev-list -n 1 v1.0.0..HEAD); git push`.

## 2. Дополнительные Требования

### Полная Документация

- **Формат**: Markdown/Confluence guides.
- **Содержание**: Процессы (workflow diagram via Mermaid), API endpoints (e.g., GitLab MR API), troubleshooting (e.g., "Hook fail: check permissions").
- **Хранение**: Protected wiki - GitLab Wiki (Project > Wiki) или Bitbucket Wiki (Repository > Wiki).
  Пример Mermaid diagram в docs:
  ```
  graph TD
    A[Create Feature Branch] --> B[Extract Keys from Vault]
    B --> C[Run Scans & Build]
    C --> D[PR/MR with 2 Approvals]
    D --> E[Merge to Main & Rotate Keys]
    E --> F[Create Tag & Deploy]
  ```

### Ежеквартальный Аудит и Pentesting

- **Internal/External**: Review workflow compliance (SOC2, GDPR).
- **Tools**: Burp Suite для pentesting (simulate key exfiltration).
- **Автоматизация**: Scheduled pipeline: `docker run -it portswigger/burp-suite scan --url $PROJECT_URL`.
- **Ежемесячное Pentesting**: Full system scan, report to Jira.

### Обучение

- **Mandatory Onboarding**: Sessions (1h) + quizzes (e.g., "What is TTL for keys?").
- **Tools**: GitLab Pages для quizzes (HTML/JS), annual refreshers via Zoom.
- **Content**: Best practices (no hardcode secrets, use feature branches).

### Bug Bounty Программа

- **Platforms**: HackerOne, integrated with andykachess repos.
- **Rewards**: $100 (low), $500 (medium), $1000 (critical) за vulnerabilities (e.g., hook bypass).
- **Scope**: Git workflow, CI configs, key management.
- **Setup**: HackerOne program → invite andykachess, policy: "Report secrets leaks".

## 3. Рекомендации по Миграции (GitLab ↔ Bitbucket)

### Общий Процесс

- **Экспорт Репозитория**: `git clone --mirror repo.git; tar czf repo.tar.gz .git`.
- **Импорт**:
  - GitLab: New Project > Import > GitLab/Bitbucket URL.
  - Bitbucket: Repository Settings > Import repository > URL or ZIP.
- **CI/CD Миграция**: Конвертируйте configs.
  - .gitlab-ci.yml → bitbucket-pipelines.yml: Use online converters (e.g., yaml-migrate tool) или manual (stages → steps).
    Пример converter script (Python):
  ```
  import yaml
  with open('.gitlab-ci.yml') as f:
    ci = yaml.safe_load(f)
  # Transform stages to pipelines branches
  pipelines = {'branches': {}}
  for job in ci['jobs']:
    pipelines['branches']['main'] = [{'step': {'name': job['stage'], 'script': job['script']}}]
  with open('bitbucket-pipelines.yml', 'w') as f:
    yaml.dump(pipelines, f)
  ```

### Специфические Шаги

- **Branch Protections**: Manual transfer - recreate rules via UI/API.
  - API: GitLab protected_branches → Bitbucket branch-permissions (curl scripts).
- **Hooks**: Custom hooks - copy scripts, re-install (GitLab custom_hooks dir; Bitbucket add-ons).
- **Variables/Secrets**: Export/import.
  - GitLab: API `/api/v4/projects/:id/variables`.
  - Bitbucket: Repository Variables UI or API `/2.0/repositories/{}/pipelines_config`.
    Script: `curl export > vars.json; jq process for import`.
- **Webhooks/Audit**: Recreate integrations (Slack, Jira).
- **Key Stores**: Vault/AWS - no change, update CI vars.
- **Downtime**: Mirror repo during migration; test in staging.

### Post-Migration

- **Validation**: Run full pipeline, check hooks.
- **Cleanup**: Delete old repo after verification.
- **Timeline**: 1-2 days для small repo; scale with automation scripts.

Этот раздел завершает воркфлоу. Для внедрения - протестируйте release process в dev repo.
