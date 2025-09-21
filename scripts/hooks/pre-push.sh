#!/bin/sh
# Pre-push hook для дополнительной валидации перед push
# Установка: cp scripts/hooks/pre-push.sh .git/hooks/pre-push && chmod +x .git/hooks/pre-push

# Получаем remote и branch
REMOTE="$1"
URL="$2"

# Проверка на push в защищённые ветки (main/develop) - предупреждение, но не блокировка (серверные хуки заблокируют)
while read local_ref local_sha remote_ref remote_sha; do
  local_branch=$(echo "$local_ref" | sed 's/refs\/heads\///')
  remote_branch=$(echo "$remote_ref" | sed 's/refs\/heads\///')

  if [[ "$remote_branch" == "main" || "$remote_branch" == "develop" ]]; then
    echo "Warning: Direct push to $remote_branch detected. Use Pull Request/Merge Request instead."
    echo "This push may be rejected by server hooks."
  fi

  # Проверка префикса для feature branches
  if [[ "$local_branch" != "main" && ! "$local_branch" =~ ^(feature/|hotfix/) ]]; then
    echo "Warning: Branch '$local_branch' does not follow naming convention. Consider renaming."
  fi

  # Дополнительное сканирование staged изменений перед push
  if command -v trufflehog >/dev/null 2>&1; then
    git diff --name-only $local_sha $remote_sha | xargs trufflehog --path . --no-verification
    if [ $? -ne 0 ]; then
      echo "Error: Potential secrets in diff detected by TruffleHog!"
      exit 1
    fi
  fi
done < "$3"

# Проверка на большие файлы в push
git diff --name-only --diff-filter=AM $local_sha $remote_sha | while read file; do
  if [[ -f "$file" ]]; then
    size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    if [[ "$size" -gt 10485760 ]]; then
      echo "Error: File $file in push is larger than 10MB. Use Git LFS."
      exit 1
    fi
  fi
done

echo "Pre-push checks passed."
exit 0