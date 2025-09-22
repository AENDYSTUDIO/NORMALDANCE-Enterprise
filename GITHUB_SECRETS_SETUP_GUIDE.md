# Инструкция по добавлению GitHub секретов в репозиторий NORMALDANCE-Enterprise

## Обзор

Данный документ содержит пошаговую инструкцию по добавлению необходимых секретов в GitHub репозиторий [NORMALDANCE-Enterprise](https://github.com/AENDYSTUDIO/NORMALDANCE-Enterprise/settings/secrets/actions).

## Сгенерированные значения

### NEXTAUTH_SECRET

```
WTR8L4N8uXBO/lrsU3kJoEcYl+KVMNPLPkytfHsdw70=
```

## Шаблоны для других секретов

### DATABASE_URL

```
postgresql://user:pass@host:5432/normaldance
```

**Примечание:** Замените `user`, `pass`, `host` на реальные значения вашей базы данных PostgreSQL.

### REDIS_URL

```
redis://host:6379
```

**Примечание:** Замените `host` на реальный адрес вашего Redis-сервера.

### PINATA_JWT

```
ваш_pinata_jwt
```

**Примечание:** Получите JWT токен в вашем аккаунте Pinata:

1. Зайдите в [Pinata Dashboard](https://pinata.cloud/)
2. Перейдите в раздел API Keys
3. Создайте новый ключ или используйте существующий
4. Скопируйте JWT токен

### SONAR_TOKEN

```
86e73a84ed9d3be9bf982ab8960380573fc38e19
```

**Примечание:** Токен уже получен из SonarCloud и готов к добавлению в GitHub Secrets.

### VERCEL_TOKEN

```
ваш_vercel_токен
```

**Примечание:** Получите токен в Vercel:

1. Зайдите в [Vercel Dashboard](https://vercel.com/account/tokens)
2. Нажмите "Create Token"
3. Введите имя токена и выберите необходимые разрешения
4. Скопируйте сгенерированный токен

## Пошаговая инструкция по добавлению секретов в GitHub

### Шаг 1: Перейдите в настройки секретов репозитория

1. Откройте репозиторий [NORMALDANCE-Enterprise](https://github.com/AENDYSTUDIO/NORMALDANCE-Enterprise)
2. Нажмите на вкладку "Settings"
3. В меню слева выберите "Secrets and variables" → "Actions"

### Шаг 2: Добавьте каждый секрет

Для каждого секрета выполните следующие действия:

1. Нажмите кнопку "New repository secret"
2. В поле "Name" введите имя секрета (например, `NEXTAUTH_SECRET`)
3. В поле "Secret" вставьте значение секрета
4. Нажмите кнопку "Add secret"

#### Пример добавления NEXTAUTH_SECRET:

1. Name: `NEXTAUTH_SECRET`
2. Secret: `WTR8L4N8uXBO/lrsU3kJoEcYl+KVMNPLPkytfHsdw70=`
3. Нажмите "Add secret"

#### Пример добавления DATABASE_URL:

1. Name: `DATABASE_URL`
2. Secret: `postgresql://user:pass@host:5432/normaldance` (замените на реальные значения)
3. Нажмите "Add secret"

#### Пример добавления REDIS_URL:

1. Name: `REDIS_URL`
2. Secret: `redis://host:6379` (замените на реальный адрес)
3. Нажмите "Add secret"

#### Пример добавления PINATA_JWT:

1. Name: `PINATA_JWT`
2. Secret: `ваш_pinata_jwt` (замените на реальный токен)
3. Нажмите "Add secret"

#### Пример добавления SONAR_TOKEN:

1. Name: `SONAR_TOKEN`
2. Secret: `86e73a84ed9d3be9bf982ab8960380573fc38e19`
3. Нажмите "Add secret"

#### Пример добавления VERCEL_TOKEN:

1. Name: `VERCEL_TOKEN`
2. Secret: `ваш_vercel_токен` (замените на реальный токен)
3. Нажмите "Add secret"

### Шаг 3: Проверка добавленных секретов

После добавления всех секретов вы можете проверить их в списке:

1. Убедитесь, что все 6 секретов отображаются в списке
2. Проверьте, что имена секретов соответствуют ожидаемым:
   - NEXTAUTH_SECRET
   - DATABASE_URL
   - REDIS_URL
   - PINATA_JWT
   - SONAR_TOKEN
   - VERCEL_TOKEN

### Шаг 4: Тестирование доступа к секретам в CI/CD

Для проверки корректности добавления секретов вы можете создать тестовый workflow:

1. Создайте файл `.github/workflows/test-secrets.yml`
2. Добавьте следующий код:

```yaml
name: Test Secrets

on:
  workflow_dispatch:

jobs:
  test-secrets:
    runs-on: ubuntu-latest
    steps:
      - name: Test NEXTAUTH_SECRET
        env:
          NEXTAUTH_SECRET: ${{ secrets.NEXTAUTH_SECRET }}
        run: echo "NEXTAUTH_SECRET length: ${#NEXTAUTH_SECRET}"

      - name: Test DATABASE_URL
        env:
          DATABASE_URL: ${{ secrets.DATABASE_URL }}
        run: echo "DATABASE_URL is set: $DATABASE_URL"

      - name: Test REDIS_URL
        env:
          REDIS_URL: ${{ secrets.REDIS_URL }}
        run: echo "REDIS_URL is set: $REDIS_URL"

      - name: Test PINATA_JWT
        env:
          PINATA_JWT: ${{ secrets.PINATA_JWT }}
        run: echo "PINATA_JWT is set: $PINATA_JWT"

      - name: Test SONAR_TOKEN
        env:
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
        run: echo "SONAR_TOKEN is set: $SONAR_TOKEN"

      - name: Test VERCEL_TOKEN
        env:
          VERCEL_TOKEN: ${{ secrets.VERCEL_TOKEN }}
        run: echo "VERCEL_TOKEN is set: $VERCEL_TOKEN"
```

3. Сохраните и закоммитьте файл
4. Запустите workflow вручную через вкладку "Actions" в GitHub
5. Проверьте логи выполнения workflow, чтобы убедиться, что все секреты доступны

## Важные замечания по безопасности

1. Никогда не публикуйте значения секретов в открытом доступе
2. Регулярно обновляйте секреты, особенно токены доступа
3. Используйте токены с ограниченными правами доступа
4. Следите за истечением срока действия токенов
5. В случае компрометации немедленно отзовите и замените скомпрометированные секреты

## Заключение

После выполнения всех шагов репозиторий NORMALDANCE-Enterprise будет полностью настроен для использования в CI/CD процессах с необходимыми секретами. Убедитесь, что все секреты добавлены корректно и доступны в workflow перед развертыванием.
