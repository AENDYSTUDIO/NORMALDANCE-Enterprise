# 🔍 Инструкция по настройке SonarCloud для NORMALDANCE-Enterprise

## Обзор

SonarCloud - это облачный сервис для непрерывного анализа кода, который помогает обнаруживать ошибки, уязвимости и технический долг в вашем коде. Эта инструкция поможет вам настроить SonarCloud для проекта NORMALDANCE-Enterprise.

## Предварительные требования

- Аккаунт GitHub с доступом к репозиторию `AENDYSTUDIO/NORMALDANCE-Enterprise`
- Права администратора в репозитории для добавления GitHub Secrets
- Настроенный проект в SonarCloud (если еще не настроен)

## Шаг 1: Вход в SonarCloud через GitHub

1. Перейдите на [https://sonarcloud.io](https://sonarcloud.io)
2. Нажмите кнопку "Sign in with GitHub"
3. Авторизуйтесь с использованием вашего GitHub аккаунта
4. Разрешите SonarCloud доступ к вашему GitHub аккаунту

## Шаг 2: Импорт проекта

1. После входа нажмите "Analyze new project"
2. Выберите организацию `AENDYSTUDIO`
3. Найдите и выберите репозиторий `NORMALDANCE-Enterprise`
4. Нажмите "Set Up"

## Шаг 3: Получение SONAR_TOKEN

1. После импорта проекта перейдите в настройки проекта:

   - Нажмите на иконку проекта в правом верхнем углу
   - Выберите "Project Settings"
   - Перейдите в раздел "General" → "Security"

2. В разделе "Security" вы найдете:

   - **Project Key**: `AENDYSTUDIO_NORMALDANCE-Enterprise`
   - **Organization**: `aendystudio`
   - **SONAR_TOKEN**: Нажмите "Generate" или скопируйте существующий токен

3. Сохраните SONAR_TOKEN в безопасном месте

## Шаг 4: Добавление SONAR_TOKEN в GitHub Secrets

1. Перейдите в репозиторий GitHub: `AENDYSTUDIO/NORMALDANCE-Enterprise`
2. Нажмите "Settings" → "Secrets and variables" → "Actions"
3. Нажмите "New repository secret"
4. Введите:
   - **Name**: `SONAR_TOKEN`
   - **Secret**: [вставьте ваш SONAR_TOKEN]
5. Нажмите "Add secret"

## Шаг 5: Проверка конфигурационных файлов

### Файл sonar-project.properties

Убедитесь, что в корне проекта существует файл [`sonar-project.properties`](sonar-project.properties) со следующим содержимым:

```properties
sonar.projectKey=AENDYSTUDIO_NORMALDANCE-Enterprise
sonar.organization=aendystudio
sonar.projectName=NORMALDANCE Enterprise
sonar.projectVersion=1.0.1

# Source code
sonar.sources=src
sonar.tests=tests
sonar.test.inclusions=**/*.test.ts,**/*.test.tsx,**/*.spec.ts,**/*.spec.tsx

# Exclusions
sonar.exclusions=**/node_modules/**,**/.next/**,**/coverage/**,**/dist/**,**/*.d.ts,**/out/**,**/build/**,**/public/**,**/docs/**

# Coverage
sonar.javascript.lcov.reportPaths=coverage/lcov.info
sonar.typescript.lcov.reportPaths=coverage/lcov.info

# Language settings
sonar.typescript.node=node

# Quality gate
sonar.qualitygate.wait=true

# Security
sonar.security.hotspots.inheritFromParent=true

# JavaScript/TypeScript specific settings
sonar.javascript.file.suffixes=.js,.jsx,.ts,.tsx
sonar.typescript.file.suffixes=.ts,.tsx

# Additional source paths for enterprise project
sonar.inclusions=**/*.ts,**/*.tsx,**/*.js,**/*.jsx

# Encoding
sonar.sourceEncoding=UTF-8

# Branch analysis
sonar.pullrequest.github.repository=AENDYSTUDIO/NORMALDANCE-Enterprise
```

### GitHub Actions Workflow

Убедитесь, что существует файл [`.github/workflows/sonarcloud.yml`](.github/workflows/sonarcloud.yml):

```yaml
name: SonarCloud Analysis

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  sonarcloud:
    name: SonarCloud
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: "18"
          cache: "npm"

      - name: Install dependencies
        run: npm install --frozen-lockfile

      - name: Run tests with coverage
        run: npm run test:coverage

      - name: SonarCloud Scan
        uses: SonarSource/sonarcloud-github-action@master
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
```

## Шаг 6: Запуск первого анализа

1. Сделайте коммит и push изменений в ветку `main` или `develop`
2. Перейдите в раздел "Actions" в GitHub репозитории
3. Найдите и выберите "SonarCloud Analysis"
4. Наблюдайте за выполнением workflow

## Шаг 7: Проверка результатов

1. После успешного выполнения workflow перейдите на [SonarCloud](https://sonarcloud.io)
2. Выберите ваш проект `AENDYSTUDIO_NORMALDANCE-Enterprise`
3. Изучите результаты анализа:
   - **Quality Gate**: статус прохождения проверки качества
   - **Reliability**: ошибки и баги
   - **Security**: уязвимости
   - **Maintainability**: технический долг
   - **Coverage**: покрытие кода тестами

## Настройка Quality Gate

1. В SonarCloud перейдите в "Quality Gates"
2. Выберите "Sonar way" или создайте кастомный Quality Gate
3. Настройте пороговые значения для вашего проекта:
   - Coverage > 80%
   - New Reliability Rating = A
   - New Security Rating = A
   - Maintainability Rating = A

## Интеграция с Pull Requests

SonarCloud автоматически будет анализировать Pull Requests и оставлять комментарии с результатами анализа. Убедитесь, что:

1. В настройках проекта включена опция "Pull Request Decoration"
2. Настроены правила для блокировки PR при неудачном Quality Gate

## Устранение неполадок

### Ошибка: SONAR_TOKEN not found

**Решение:**

1. Проверьте, что SONAR_TOKEN добавлен в GitHub Secrets
2. Убедитесь, что имя секрета точно `SONAR_TOKEN`
3. Проверьте права доступа к репозиторию

### Ошибка: Coverage report not found

**Решение:**

1. Убедитесь, что скрипт `npm run test:coverage` генерирует файл `coverage/lcov.info`
2. Проверьте путь к отчету в `sonar-project.properties`
3. Запустите тесты локально: `npm run test:coverage`

### Ошибка: Project not found

**Решение:**

1. Проверьте `sonar.projectKey` в `sonar-project.properties`
2. Убедитесь, что проект импортирован в SonarCloud
3. Проверьте правильность организации `aendystudio`

## Полезные ссылки

- [SonarCloud Documentation](https://docs.sonarcloud.io/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Project Dashboard](https://sonarcloud.io/project/overview?id=AENDYSTUDIO_NORMALDANCE-Enterprise)
- [Quality Gate Settings](https://sonarcloud.io/quality_gates)

## Автоматизация

Для автоматической настройки используйте скрипты:

- **Linux/macOS**: [`scripts/setup-sonarcloud.sh`](scripts/setup-sonarcloud.sh)
- **Windows**: [`scripts/setup-sonarcloud.bat`](scripts/setup-sonarcloud.bat)

## Поддержка

Если у вас возникли проблемы с настройкой:

1. Проверьте логи GitHub Actions
2. Обратитесь к документации SonarCloud
3. Создайте issue в репозитории проекта

---

**Примечание:** Эта инструкция предполагает, что у вас уже есть доступ к репозиторию и необходимые права для настройки интеграции.
