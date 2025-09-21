#!/bin/sh
# Pre-commit hook для сканирования секретов и валидации
# Установка: cp scripts/hooks/pre-commit.sh .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit

# Проверка на большие файлы (>10MB)
if git rev-parse --verify HEAD >/dev/null 2>&1; then
  git diff --cached --name-only | while read file; do
    if [[ -f "$file" ]]; then
      size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
      if [[ "$size" -gt 10485760 ]]; then
        echo "Error: File $file is larger than 10MB. Use Git LFS."
        exit 1
      fi
    fi
  done
fi

# Сканирование на секреты с git-secrets
if command -v git-secrets >/dev/null 2>&1; then
  if ! git-secrets --scan; then
    echo "Error: Secrets detected by git-secrets!"
    exit 1
  fi
else
  echo "Warning: git-secrets not installed. Install with: brew install git-secrets"
fi

# Сканирование с TruffleHog (если установлен)
if command -v trufflehog >/dev/null 2>&1; then
  if ! trufflehog --git . --since-commit HEAD~1; then
    echo "Error: Secrets detected by TruffleHog!"
    exit 1
  fi
else
  echo "Warning: TruffleHog not installed."
fi

# Сканирование с Gitleaks (если установлен)
if command -v gitleaks >/dev/null 2>&1; then
  if ! gitleaks detect --source .; then
    echo "Error: Secrets detected by Gitleaks!"
    exit 1
  fi
else
  echo "Warning: Gitleaks not installed."
fi

# Проверка на feature branch prefix (локально)
branch=$(git rev-parse --abbrev-ref HEAD)
if [[ ! "$branch" =~ ^(feature/|hotfix/) ]] && [[ "$branch" != "main" ]]; then
  echo "Warning: Branch '$branch' does not follow naming convention. Use feature/ or hotfix/ prefix."
fi

echo "Pre-commit checks passed."
exit 0