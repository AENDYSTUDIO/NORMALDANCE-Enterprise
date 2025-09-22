# Инструкция по проверке GitHub секретов

## Краткая проверка

После добавления всех секретов в репозиторий NORMALDANCE-Enterprise выполните следующие шаги для проверки:

### 1. Проверка через интерфейс GitHub

1. Перейдите в репозиторий [NORMALDANCE-Enterprise](https://github.com/AENDYSTUDIO/NORMALDANCE-Enterprise)
2. Нажмите на вкладку "Settings"
3. В меню слева выберите "Secrets and variables" → "Actions"
4. Убедитесь, что в списке присутствуют все 6 секретов:
   - NEXTAUTH_SECRET
   - DATABASE_URL
   - REDIS_URL
   - PINATA_JWT
   - SONAR_TOKEN
   - VERCEL_TOKEN

### 2. Проверка через тестовый workflow

1. Перейдите во вкладку "Actions" в репозитории
2. Выберите workflow "Test Secrets"
3. Нажмите "Run workflow" → "Run workflow"
4. Дождитесь завершения выполнения
5. Проверьте логи выполнения, убедитесь, что все секреты определены:
   - "NEXTAUTH_SECRET is set and has length: 44"
   - "DATABASE_URL is set"
   - "REDIS_URL is set"
   - "PINATA_JWT is set"
   - "SONAR_TOKEN is set"
   - "VERCEL_TOKEN is set"

### 3. Проверка в CI/CD процессах

После успешного выполнения тестового workflow, секреты будут доступны во всех CI/CD процессах репозитория. Вы можете использовать их в своих workflow следующим образом:

```yaml
env:
  NEXTAUTH_SECRET: ${{ secrets.NEXTAUTH_SECRET }}
  DATABASE_URL: ${{ secrets.DATABASE_URL }}
  REDIS_URL: ${{ secrets.REDIS_URL }}
  PINATA_JWT: ${{ secrets.PINATA_JWT }}
  SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
  VERCEL_TOKEN: ${{ secrets.VERCEL_TOKEN }}
```

## Устранение неполадок

Если какой-либо из секретов не определен:

1. Проверьте правильность имени секрета
2. Убедитесь, что значение секрета не пустое
3. Повторно добавьте секрет, если необходимо
4. Запустите тестовый workflow повторно

## Безопасность

- Никогда не публикуйте значения секретов
- Регулярно обновляйте токены доступа
- Используйте токены с минимально необходимыми правами
