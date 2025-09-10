# Система мониторинга здоровья для audio-streaming

## Обзор

Система мониторинга здоровья предназначена для контроля состояния всех компонентов audio-streaming сервиса. Включает проверку доступности сервисов, мониторинг ресурсов, уведомления о проблемах и автоматическое восстановление.

## Архитектура

### Компоненты системы

- **health-check.sh** - основной скрипт проверки здоровья
- **setup-health-monitoring.sh** - скрипт установки и настройки
- **deploy-health-monitoring.sh** - скрипт деплоя на удаленный сервер
- **health-check.json** - конфигурация проверок
- **backup-monitoring.sh** - резервное копирование метрик
- **restore-monitoring.sh** - восстановление из резервной копии

### Проверяемые сервисы

- **Nginx** - веб-сервер и прокси
- **Docker контейнеры** - все запущенные контейнеры
- **Redis** - кэш и сессии
- **PostgreSQL** - база данных
- **Node.js приложения** - основные сервисы
- **Системные ресурсы** - CPU, память, диск

## Установка

### Быстрая установка

```bash
# Клонировать репозиторий
git clone <repository-url>
cd services/audio-streaming

# Установить на локальном сервере
sudo ./scripts/setup-health-monitoring.sh --verbose --cron --systemd

# Или установить на удаленный сервер
./scripts/deploy-health-monitoring.sh --host 176.108.246.49 --user aendy --verbose
```

### Параметры установки

#### setup-health-monitoring.sh

```bash
sudo ./scripts/setup-health-monitoring.sh [options]

Options:
  --verbose, -v     Подробный вывод
  --cron, -c        Установить cron задачу
  --systemd, -s     Установить systemd сервис и таймер
  --user, -u        Создать пользователя для мониторинга
  --group, -g       Указать группу для пользователя
  --help, -h        Показать справку
```

#### deploy-health-monitoring.sh

```bash
./scripts/deploy-health-monitoring.sh --host <hostname> [options]

Required:
  --host, -h        Адрес удаленного сервера

Options:
  --user, -u        Пользователь для подключения (default: root)
  --port, -p        Порт SSH (default: 22)
  --key, -k         Путь к приватному ключу SSH
  --verbose, -v     Подробный вывод
  --dry-run, -n     Показать что будет сделано без выполнения
  --no-backup, -B   Не создавать резервные копии
  --no-restart, -R  Не перезапускать сервисы
  --force, -f       Принудительный деплой без подтверждения
```

## Конфигурация

### Основная конфигурация

Файл: `config/health-check.json`

```json
{
  "services": {
    "nginx": {
      "enabled": true,
      "port": 80,
      "health_endpoint": "/health",
      "timeout": 5
    },
    "redis": {
      "enabled": true,
      "host": "localhost",
      "port": 6379,
      "timeout": 3
    },
    "postgresql": {
      "enabled": true,
      "host": "localhost",
      "port": 5432,
      "database": "audio_streaming",
      "timeout": 5
    }
  },
  "alerts": {
    "slack_webhook": "https://hooks.slack.com/services/YOUR/WEBHOOK/URL",
    "email": "admin@dnb1st.ru",
    "webhook_timeout": 10
  }
}
```

### Настройка уведомлений

#### Slack Webhook

1. Перейдите в Slack → Apps → Incoming Webhooks
2. Создайте новый webhook для вашего канала
3. Скопируйте URL в конфигурацию

#### Email уведомления

Настройте почтовый сервер или используйте внешний SMTP:

```bash
# Установить postfix
sudo apt-get install postfix

# Или настройте внешний SMTP в конфигурации
```

## Использование

### Ручная проверка

```bash
# Запуск проверки вручную
sudo /opt/monitoring/scripts/health-check.sh --verbose

# Проверка с кастомной конфигурацией
sudo /opt/monitoring/scripts/health-check.sh --config /path/to/config.json
```

### Просмотр логов

```bash
# Просмотр последних логов
sudo tail -f /var/log/monitoring-health.log

# Просмотр всех логов
sudo journalctl -u monitoring-health.service -f

# Просмотр cron логов
sudo tail -f /var/log/cron.log | grep monitoring-health
```

### Управление сервисами

```bash
# Systemd
sudo systemctl status monitoring-health.timer
sudo systemctl start monitoring-health.timer
sudo systemctl stop monitoring-health.timer
sudo systemctl restart monitoring-health.timer

# Cron
sudo crontab -l | grep monitoring-health
```

## Мониторинг и диагностика

### Метрики

Система собирает следующие метрики:

- **uptime** - время работы сервисов
- **response_time** - время ответа
- **cpu_usage** - загрузка CPU
- **memory_usage** - использование памяти
- **disk_usage** - использование диска
- **container_status** - статус контейнеров

### Графики и дашборды

Для визуализации метрик можно использовать:

- **Grafana** - для создания дашбордов
- **Prometheus** - для сбора метрик
- **ELK Stack** - для анализа логов

### Типичные проблемы и решения

#### Проблема: Сервис недоступен

```bash
# Проверить статус сервиса
sudo systemctl status nginx

# Проверить логи
sudo journalctl -u nginx -f

# Перезапустить сервис
sudo systemctl restart nginx
```

#### Проблема: Высокая загрузка CPU

```bash
# Проверить процессы
top -o %CPU

# Проверить логи приложения
sudo tail -f /var/log/audio-streaming/app.log

# Перезапустить контейнеры
docker-compose restart
```

#### Проблема: Не работают уведомления

```bash
# Проверить конфигурацию
sudo cat /etc/monitoring/health-check.json | jq '.alerts'

# Проверить сетевое подключение
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"Test message"}' \
  YOUR_SLACK_WEBHOOK_URL
```

## Резервное копирование

### Автоматическое резервное копирование

```bash
# Настроить cron для резервного копирования
sudo crontab -e

# Добавить строку
0 2 * * * /opt/monitoring/scripts/backup-monitoring.sh --config /etc/monitoring/backup-config.json
```

### Ручное резервное копирование

```bash
# Создать резервную копию
sudo ./scripts/backup-monitoring.sh --verbose

# Восстановить из резервной копии
sudo ./scripts/restore-monitoring.sh --backup-file /path/to/backup.tar.gz
```

## Безопасность

### Рекомендации

1. **Изоляция пользователей**
   - Используйте отдельного пользователя для мониторинга
   - Ограничьте права доступа к конфигурации

2. **Шифрование**
   - Используйте HTTPS для webhook уведомлений
   - Шифруйте чувствительные данные в конфигурации

3. **Сетевые настройки**
   - Ограничьте доступ к мониторинговым портам
   - Используйте firewall для фильтрации трафика

### Настройка firewall

```bash
# Разрешить только необходимые порты
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

## Разработка

### Структура проекта

```
services/audio-streaming/
├── scripts/
│   ├── health-check.sh              # Основной скрипт проверки
│   ├── setup-health-monitoring.sh   # Установка системы
│   ├── deploy-health-monitoring.sh  # Деплой на сервер
│   ├── backup-monitoring.sh         # Резервное копирование
│   └── restore-monitoring.sh        # Восстановление
├── config/
│   ├── health-check.json           # Конфигурация проверок
│   └── backup-config.json          # Конфигурация резервного копирования
├── logs/
│   └── monitoring-health.log       # Логи мониторинга
└── README.md                       # Этот файл
```

### Тестирование

```bash
# Запуск тестов
./scripts/health-check.sh --test-mode

# Проверка конфигурации
./scripts/health-check.sh --validate-config

# Тестирование уведомлений
./scripts/health-check.sh --test-alerts
```

### Контрибуция

1. Форкните репозиторий
2. Создайте ветку для вашей функции
3. Добавьте тесты
4. Создайте pull request

## Поддержка

- **Email**: admin@dnb1st.ru
- **Slack**: #audio-streaming-support
- **Issues**: GitHub Issues

## Лицензия

MIT License - см. LICENSE файл для деталей.