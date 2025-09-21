#!/bin/sh
# Pre-receive hook (server-side) для блокировки небезопасных push
# Установка: Для GitLab - разместите в custom_hooks/pre-receive; Для Bitbucket - используйте add-ons как ScriptRunner
# Этот хук читает stdin для refs и проверяет изменения

# Функция для сканирования refs на секреты
scan_refs() {
  while read oldrev newrev refname; do
    if [ "$newrev" = "0000000000000000000000000000000000000000" ]; then
      # Delete ref - allow
      continue
    fi

    # Checkout временно для сканирования
    git --work-tree=/tmp/repo --git-dir=.git checkout --quiet $newrev

    # Сканирование с git-secrets
    if command -v git-secrets >/dev/null 2>&1; then
      if ! git-secrets --scan; then
        echo "Error: Secrets detected in $refname by git-secrets!"
        exit 1
      fi
    fi

    # TruffleHog для новых коммитов
    if command -v trufflehog >/dev/null 2>&1; then
      trufflehog --git . --since-commit $oldrev
      if [ $? -ne 0 ]; then
        echo "Error: Secrets detected in $refname by TruffleHog!"
        exit 1
      fi
    fi

    # Gitleaks
    if command -v gitleaks >/dev/null 2>&1; then
      gitleaks detect --source . --from-ref $oldrev --to-ref $newrev
      if [ $? -ne 0 ]; then
        echo "Error: Secrets detected in $refname by Gitleaks!"
        exit 1
      fi
    fi

    # Проверка на большие файлы в новых коммитах
    git diff --name-only $oldrev $newrev | while read file; do
      if [[ -f "$file" ]]; then
        size=$(stat -c%s "$file" 2>/dev/null || echo 0)
        if [[ "$size" -gt 10485760 ]]; then
          echo "Error: Large file $file (>10MB) in $refname. Use LFS."
          exit 1
        fi
      fi
    done
  done
}

# Блокировка push в защищённые ветки
while read oldrev newrev refname; do
  branch=$(basename "$refname")
  if [[ "$branch" == "main" || "$branch" == "master" || "$branch" == "develop" ]]; then
    if [ "$newrev" != "0000000000000000000000000000000000000000" ]; then  # Not delete
      echo "Error: Direct push to protected branch '$branch' is forbidden. Use Pull/Merge Request."
      exit 1
    fi
  fi

  # Только feature/hotfix для non-main
  if [[ ! "$branch" =~ ^(feature/|hotfix/) ]] && [[ "$branch" != "main" && "$branch" != "develop" ]]; then
    echo "Error: Branch '$branch' must use feature/ or hotfix/ prefix."
    exit 1
  fi
done

# Сканирование всех refs
scan_refs

# Логирование для аудита
echo "$(date): Pre-receive passed for $refname" >> /var/log/git-hooks.log

echo "Pre-receive checks passed."
exit 0