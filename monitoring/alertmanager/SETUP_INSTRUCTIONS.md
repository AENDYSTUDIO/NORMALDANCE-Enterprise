# Настройка интеграций AlertManager для NORMALDANCE-Enterprise

## Обзор

Этот документ содержит инструкции по настройке интеграций для AlertManager в проекте NORMALDANCE-Enterprise.

## 1. Настройка Email уведомлений

### Требования

- SMTP сервер для отправки email уведомлений
- Учетные данные для аутентификации

### Конфигурация

В файле `alertmanager.yml` уже настроена базовая email конфигурация:

```yaml
global:
  smtp_smarthost: "localhost:587"
  smtp_from: "alerts@normaldance.com"
  smtp_auth_username: "alerts@normaldance.com"
  smtp_auth_password: "${SMTP_PASSWORD}"
```

### Настройка переменных окружения

Добавьте следующие переменные в ваш `.env` файл:

```bash
# Email настройки
SMTP_PASSWORD=ваш_пароль_SMTP
SMTP_HOST=smtp.your-provider.com
SMTP_PORT=587
SMTP_TLS=true
```

### Поддерживаемые провайдеры

- **Gmail**: `smtp.gmail.com:587`
- **Outlook**: `smtp.office365.com:587`
- **SendGrid**: `smtp.sendgrid.net:587`

## 2. Настройка Slack уведомлений

### Получение Slack Webhook URL

1. **Откройте Slack workspace**
2. **Перейдите в раздел Apps**: https://your-workspace.slack.com/apps/manage
3. **Найдите "Incoming Webhooks"** и установите приложение
4. **Создайте webhook**:

   - Перейдите в "Incoming Webhooks" в настройках приложения
   - Нажмите "Add Configuration to Workspace"
   - Выберите канал `#alerts-critical`
   - Нажмите "Allow"

5. **Скопируйте Webhook URL** - он будет выглядеть как:
   ```
   https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX
   ```

### Настройка переменных окружения

Добавьте в `.env` файл:

```bash
# Slack настройки
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/ваш-webhook-url
SLACK_CHANNEL=#alerts-critical
```

### Конфигурация в AlertManager

Webhook URL уже настроен в конфигурации:

```yaml
slack_configs:
  - api_url: "${SLACK_WEBHOOK_URL}"
    channel: "#alerts-critical"
    title: "🚨 Critical Alert: {{ .GroupLabels.alertname }}"
    text: |
      *Alert:* {{ .GroupLabels.alertname }}
      *Severity:* {{ .CommonLabels.severity }}
      *Cluster:* {{ .CommonLabels.cluster }}
      *Service:* {{ .CommonLabels.service }}
      *Description:* {{ .CommonAnnotations.description }}
```

## 3. Группировка и маршрутизация оповещений

### Текущая группировка

```yaml
route:
  group_by: ["alertname", "severity", "cluster", "service"]
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 12h
```

### Уровни серьезности

- **critical**: Критические ошибки (требуют немедленного внимания)
- **warning**: Предупреждения (требуют рассмотрения)
- **info**: Информационные сообщения (для мониторинга)

### Маршрутизация

- Критические оповещения → `admin@normaldance.com` + Slack `#alerts-critical`
- Предупреждения → `team@normaldance.com`
- Информационные → `devops@normaldance.com`

## 4. Подавление оповещений (Inhibit Rules)

### Конфигурация

```yaml
inhibit_rules:
  - source_match:
      severity: "critical"
    target_match:
      severity: "warning"
    equal: ["alertname", "cluster", "service"]
    for: 5m

  - source_match:
      severity: "critical"
    target_match:
      severity: "info"
    equal: ["alertname", "cluster", "service"]
    for: 10m
```

### Логика подавления

- При критической ошибке, предупреждения по тому же сервису подавляются на 5 минут
- При критической ошибке, информационные сообщения подавляются на 10 минут

## 5. Тестирование уведомлений

### Проверка email

```bash
# Отправить тестовое email
echo "Test email from AlertManager" | mail -s "Test Alert" admin@normaldance.com
```

### Проверка Slack

Используйте curl для тестирования webhook:

```bash
curl -X POST -H 'Content-type: application/json' \
--data '{"text":"Test message from AlertManager"}' \
ваш_slack_webhook_url
```

## 6. Мониторинг и отладка

### Логирование AlertManager

```bash
# Запуск с подробным логированием
alertmanager --config.file=alertmanager.yml --log.level=debug

# Просмотр логов
tail -f /var/log/alertmanager/alertmanager.log
```

### Проверка статуса

```bash
# Проверка конфигурации
alertmanager --config.file=alertmanager.yml --dry-run

# Проверка статуса сервиса
systemctl status alertmanager
```

## 7. Безопасность

### Рекомендации

1. **Никогда не храните пароли в конфигурационных файлах**
2. **Используйте переменные окружения** для секретов
3. **Регулярно обновляйте** AlertManager до последней версии
4. **Ограничьте доступ** к конфигурационным файлам
5. **Используйте TLS** для SMTP соединений

### Best Practices

- Регулярно проверяйте работоспособность уведомлений
- Настраивайте ротацию паролей
- Используйте двухфакторную аутентификацию где возможно
- Мониторите количество отправленных уведомлений

## 8. Контактная информация

Для технической поддержки по настройке AlertManager:

- Email: devops@normaldance.com
- Slack: #devops-support
- Документация: [Wiki](https://wiki.normaldance.com/monitoring)

---

_Последнее обновление: 2025-09-20_
_Версия: 1.0_
