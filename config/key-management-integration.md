# Интеграция с Хранилищами Ключей: HashiCorp Vault и AWS Secrets Manager

## Введение

Этот документ описывает интеграцию Git-воркфлоу с защищёнными хранилищами ключей для автоматизированного извлечения, использования и очистки криптографических ключей. Интеграция обеспечивает:

- **Эфемерность**: Ключи извлекаются только в runtime (CI/CD jobs) с TTL.
- **Безопасность**: Нет хранения в codebase; использование masked/protected variables.
- **Автоматизация**: Скрипты для ротации, аудита и очистки.
- **Совместимость**: С GitLab CI и Bitbucket Pipelines.

Предварительные требования:

- Vault: Установленный сервер, роли с политиками (e.g., read-only для CI).
- AWS: IAM роли для runners (e.g., SecretsManagerReadWrite).
- CI Variables: VAULT_TOKEN (masked), AWS_ACCESS_KEY_ID (protected).

## 1. Интеграция с HashiCorp Vault

### Настройка

- **Vault Policies**: Создайте policy для CI (e.g., `ci-policy.hcl`):
  ```
  path "secret/data/keys/feature/*" {
    capabilities = ["read"]
  }
  path "transit/keys/my-key" {
    capabilities = ["update", "read"]
  }
  ```
  Примените: `vault policy write ci-policy ci-policy.hcl`.
- **Auth Method**: AppRole или JWT для CI (GitLab/Bitbucket OIDC).
- **CI Variables**:
  - GitLab: VAULT_ADDR, VAULT_ROLE_ID, VAULT_SECRET_ID (masked).
  - Bitbucket: Аналогично в Repository Variables.

### Извлечение Ключей

- В feature-ветках: Извлекать по branch name.
- Пример скрипта (`extract-vault-key.sh`):

  ```
  #!/bin/bash
  # Требует VAULT_ADDR, VAULT_TOKEN в CI env

  BRANCH_SLUG=${CI_COMMIT_REF_SLUG:-${BITBUCKET_BRANCH#feature/}}
  mkdir -p .tmp/keys

  # Auth (если JWT)
  VAULT_TOKEN=$(vault write -field=client_token auth/jwt/login role=ci jwt=$CI_JOB_JWT)

  # Извлечение
  vault kv get -field=key secret/keys/feature/$BRANCH_SLUG > .tmp/keys/app.key
  chmod 600 .tmp/keys/*

  # TTL: Удалить через 1h (используйте at или cron в CI)
  (sleep 3600 && shred -u .tmp/keys/* && rm -rf .tmp/keys) &
  echo "Key extracted with TTL=1h"
  ```

### Ротация Ключей

- Еженедельно: В scheduled pipeline.
- Пример в .gitlab-ci.yml (см. rotate-keys job):
  ```
  vault write transit/keys/my-key rotate=true
  vault kv put secret/keys/old version=$(vault read -field=version transit/keys/my-key)
  ```
- Аудит: `vault audit enable file file_path=/var/log/vault-audit.log`.

### Очистка

- Post-job: `shred -u .tmp/keys/*; rm -rf .tmp/keys`.
- Zeroing: Используйте `sdelete` на Windows runners.

## 2. Интеграция с AWS Secrets Manager

### Настройка

- **Secrets**: Создайте secrets (e.g., `keys/feature-branch`) с JSON: `{"key": "value"}`.
- **IAM Policy** для CI runner:
  ```
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "secretsmanager:GetSecretValue",
          "secretsmanager:UpdateSecret"
        ],
        "Resource": "arn:aws:secretsmanager:*:*:secret:keys/*"
      }
    ]
  }
  ```
- **CI Variables**:
  - AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY (protected).
  - SECRET_ARN: `arn:aws:secretsmanager:us-east-1:123456789012:secret:keys/feature-`.

### Извлечение Ключей

- Пример скрипта (`extract-aws-key.sh`):

  ```
  #!/bin/bash
  # Требует AWS CLI и credentials в env

  BRANCH_SLUG=${CI_COMMIT_REF_SLUG:-${BITBUCKET_BRANCH#feature/}}
  SECRET_ID="keys/feature-$BRANCH_SLUG"
  mkdir -p .tmp/keys

  # Извлечение
  SECRET_VALUE=$(aws secretsmanager get-secret-value --secret-id $SECRET_ID --query SecretString --output text)
  echo $SECRET_VALUE | jq -r '.key' > .tmp/keys/app.key
  chmod 600 .tmp/keys/*

  # TTL cleanup
  (sleep 3600 && shred -u .tmp/keys/* && rm -rf .tmp/keys) &
  echo "Key extracted from AWS Secrets Manager"
  ```

### Ротация Ключей

- Пример в Bitbucket Pipelines:
  ```
  aws secretsmanager update-secret --secret-id my-keys --secret-string '{"key":"new-rotated-key"}'
  aws secretsmanager tag-resource --secret-id my-keys --tags Key=rotated,Value=true
  ```
- Lambda для автоматизации: Trigger еженедельно via EventBridge.

### Очистка

- Аналогично Vault: Secure delete в post-script.

## 3. Интеграция в CI/CD

### GitLab CI Пример

В .gitlab-ci.yml (build stage):

```
before_script:
  - apk add --no-cache vault-cli aws-cli jq
  - chmod +x scripts/extract-vault-key.sh
script:
  - if [[ $CI_COMMIT_REF_NAME =~ ^feature/ ]]; then ./scripts/extract-vault-key.sh; fi
after_script:
  - shred -u .tmp/keys/* || true
```

### Bitbucket Pipelines Пример

В bitbucket-pipelines.yml (build step):

```
script:
  - apk add --no-cache aws-cli jq
  - if [[ $BITBUCKET_BRANCH =~ ^feature/ ]]; then ./scripts/extract-aws-key.sh; fi
  - npm run build  # Использует .tmp/keys
```

## 4. Best Practices (OWASP/NIST)

- **RBAC**: CI роли - least privilege (read-only для extract).
- **Аудит**: Включите logging в Vault/AWS (CloudTrail).
- **Эфемерность**: Никогда не коммитьте .tmp/keys в Git (gitignore).
- **Fallback**: Multi-provider (Vault primary, AWS secondary).
- **Тестирование**: Mock secrets в dev (e.g., Vault dev server).
- **Compliance**: Retention 90 дней, encryption at rest (AES-256).
- **Ошибки**: Graceful fallback - если extract fails, pipeline fails.

Для миграции: Экспортируйте secrets via API (Vault: `vault kv get -format=json`; AWS: CLI export).

Этот setup минимизирует риски утечек и обеспечивает масштабируемость.
