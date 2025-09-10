# Скрипты управления версиями NormalDANCE

Этот каталог содержит скрипты для автоматизации управления версиями NormalDANCE.

## Содержание

- [Version Manager](#version-manager)
- [Compatibility Manager](#compatibility-manager)
- [GitHub Actions Workflows](#github-actions-workflows)

## Version Manager

Скрипт `version-manager.js` предназначен для автоматического управления версиями проекта.

### Использование

```bash
# Увеличить версию (по умолчанию patch)
node scripts/version-manager.js bump

# Увеличить major версию
node scripts/version-manager.js bump major

# Увеличить minor версию
node scripts/version-manager.js bump minor

# Увеличить patch версию
node scripts/version-manager.js bump patch

# Сгенерировать отчет о версиях
node scripts/version-manager.js report

# Показать существующие теги
node scripts/version-manager.js tags

# Показать текущую версию
node scripts/version-manager.js current
```

### Функциональность

- Автоматическое определение следующей версии
- Обновление package.json
- Обновление CHANGELOG.md
- Создание git тегов
- Коммит изменений
- Генерация отчетов

### Интеграция с npm

В package.json добавлены следующие скрипты:

```json
{
  "version": "node scripts/version-manager.js bump",
  "version:major": "node scripts/version-manager.js bump major",
  "version:minor": "node scripts/version-manager.js bump minor",
  "version:patch": "node scripts/version-manager.js bump patch",
  "version:report": "node scripts/version-manager.js report",
  "version:tags": "node scripts/version-manager.js tags",
  "version:current": "node scripts/version-manager.js current"
}
```

## Compatibility Manager

Скрипт `compatibility-manager.js` предназначен для проверки обратной совместимости.

### Использование

```bash
# Проверить обратную совместимость
node scripts/compatibility-manager.js check

# Сгенерировать отчет о совместимости
node scripts/compatibility-manager.js report

# Валидировать релиз (проверка + создание guide)
node scripts/compatibility-manager.js validate

# Создать migration guide
node scripts/compatibility-manager.js guide
```

### Функциональность

- Проверка API совместимости
- Проверка базы данных совместимости
- Проверка конфигурации совместимости
- Проверка зависимостей совместимости
- Проверка breaking changes
- Генерация migration guides

### Интеграция с npm

В package.json добавлены следующие скрипты:

```json
{
  "compatibility:check": "node scripts/compatibility-manager.js check",
  "compatibility:report": "node scripts/compatibility-manager.js report",
  "compatibility:validate": "node scripts/compatibility-manager.js validate",
  "compatibility:guide": "node scripts/compatibility-manager.js guide"
}
```

## GitHub Actions Workflows

### Version Management Workflow

Файл `.github/workflows/version-management.yml` содержит основной workflow для управления версиями.

#### Триггеры

- Push в ветки `main` и `develop`
- Создание тега `v*`
- Создание релиза
- Ручной запуск

#### Задачи

1. **Version Validation**: Проверка коммитов для определения типа версии
2. **Version Management**: Обновление версий в package.json и changelog
3. **Release Management**: Создание релизов и артефактов
4. **Deployment**: Развертывание в staging/production
5. **Notification**: Уведомления о результатах

#### Ручной запуск

```bash
# Запустить workflow вручную
gh workflow run version-management.yml

# С указанием параметров
gh workflow run version-management.yml --field version-type=major --field environment=production
```

### Notifications Workflow

Файл `.github/workflows/notifications.yml` содержит workflow для отправки уведомлений.

#### Каналы уведомлений

- Slack: `#deployments`
- Email: Уведомления подписчикам
- Discord: Уведомления в сервере

## Процесс управления версиями

### 1. Разработка

1. Разработчики создают коммиты с осмысленными сообщениями
2. Используются стандартные префиксы: `feat:`, `fix:`, `docs:`, и т.д.
3. Коммиты объединяются в Pull Request

### 2. Автоматическое определение версии

При merge Pull Request в `main`:
- Анализируются коммиты в PR
- Определяется тип версии (major/minor/patch)
- Автоматически создается релиз

### 3. Ручной запуск

Для ручного управления версиями:
```bash
# Проверить совместимость
npm run compatibility:check

# Увеличить версию
npm run version:major

# Валидировать релиз
npm run compatibility:validate
```

### 4. Развертывание

1. Создается релиз в GitHub
2. Генерируются артефакты (Docker, ZIP, TAR.GZ)
3. Происходит развертывание в staging
4. После тестирования - в production

### 5. Уведомления

- Отправляются уведомления в Slack
- Создается GitHub Release
- Обновляется CHANGELOG.md

## Best Practices

### Разработка

1. **Используйте осмысленные коммиты**
   ```bash
   # Хорошо
   git commit -m "feat: add user authentication"
   git commit -m "fix: resolve login issue"
   
   # Плохо
   git commit -m "update"
   git commit -m "fix bug"
   ```

2. **Следуйте соглашениям о коммитах**
   - `feat:` - Новая функциональность
   - `fix:` - Исправление ошибок
   - `docs:` - Документация
   - `style:` - Форматирование кода
   - `refactor:` - Рефакторинг
   - `test:` - Тесты
   - `chore:` - Рутинные задачи

3. **Проверяйте совместимость перед релизом**
   ```bash
   npm run compatibility:check
   npm run compatibility:validate
   ```

### Релизы

1. **Тестируйте thoroughly**
   ```bash
   npm run ci:test
   npm run test:e2e
   npm run test:performance
   ```

2. **Создавайте бэкапы**
   ```bash
   npm run backup:create
   ```

3. **Планируйте откаты**
   ```bash
   # Проверьте текущую версию
   npm run version:current
   
   # Откат к предыдущей версии
   git checkout v1.0.0
   ```

### Поддержка

1. **Отслеживайте обратную связь**
   - Мониторьте Slack и GitHub Issues
   - Собирайте отзывы пользователей

2. **Быстро реагируйте на проблемы**
   ```bash
   # Создайте hotfix ветку
   git checkout -b hotfix/issue-123
   
   # Исправьте проблему
   git commit -m "fix: resolve critical issue"
   
   # Создайте релиз
   npm run version:patch
   ```

## Troubleshooting

### Проблемы с версиями

1. **Неправильная версия определена**
   ```bash
   # Проверить текущую версию
   npm run version:current
   
   # Исправить вручную
   npm run version:patch
   ```

2. **Конфликт версий**
   ```bash
   # Проверить зависимости
   npm audit
   
   # Обновить зависимости
   npm update
   ```

### Проблемы с совместимостью

1. **Проблемы с API**
   ```bash
   # Проверить API совместимость
   npm run compatibility:check
   
   # Создать migration guide
   npm run compatibility:guide
   ```

2. **Проблемы с базой данных**
   ```bash
   # Создать миграцию
   npm run db:migrate
   
   # Откатить миграцию
   npm run db:reset
   ```

## Контактная информация

По вопросам управления версиями обращайтесь:

- **Email**: versions@normaldance.com
- **Slack**: Канал `#versions`
- **GitHub Issues**: https://github.com/normaldance/normaldance/issues

---

**Версия документа:** 1.0.1  
**Дата последнего обновления:** 2025-09-01  
**Автор:** NormalDance DevOps Team