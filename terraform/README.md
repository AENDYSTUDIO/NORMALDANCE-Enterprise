# Бюджетная инфраструктура на Cloud.ru

Этот проект содержит конфигурацию Terraform для развертывания бюджетной инфраструктуры на платформе Cloud.ru.

## Структура инфраструктуры

### Компоненты инфраструктуры
- **VPC сеть**: `192.168.0.0/16`
- **Подсеть**: `192.168.1.0/24`
- **Виртуальная машина**: 1 ядро, 2 ГБ RAM
- **Балансировщик нагрузки**: HTTP
- **База данных PostgreSQL**: 1 vCPU, 2 ГБ RAM, 20 ГБ SSD
- **Redis кэш**: 1 vCPU, 1 ГБ RAM, 10 ГБ SSD
- **Хранилище для бэкапов**: Объектное хранилище OBS

### Стоимость (ориентировочно)
- Виртуальная машина: ~50 руб/месяц
- База данных: ~100 руб/месяц
- Redis: ~30 руб/месяц
- Балансировщик: ~20 руб/месяц
- Хранилище: ~10 руб/месяц
**Итого: ~210 руб/месяц**

## Требования

- Установленный Terraform (версия 1.5+)
- Аккаунт Cloud.ru с API ключами
- Настроенные переменные окружения для Cloud.ru

## Настройка

### 1. Установка Terraform

```bash
wget https://releases.hashicorp.com/terraform/1.5.0/terraform_1.5.0_linux_amd64.zip
unzip terraform_1.5.0_linux_amd64.zip
mv terraform /usr/local/bin/
```

### 2. Настройка Cloud.ru CLI

```bash
# Установка CLI
pip install sbercloud

# Вход в аккаунт
sbercloud login

# Настройка конфигурации
sbercloud config set region ru-moscow-1
```

### 3. Настройка переменных

Скопируйте и настройте файл переменных:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Отредактируйте файл `terraform/terraform.tfvars`:

```hcl
db_password = "ваш_пароль_для_postgres"
redis_password = "ваш_пароль_для_redis"
ubuntu_version = "22.04"  # или "24.04" для Ubuntu 24.04 LTS
```

**Версии Ubuntu:**
- **22.04 LTS** - Рекомендуемый вариант, более стабильный и широко протестированный
- **24.04 LTS** - Более новая версия с последними обновлениями безопасности

## Развертывание

### Локальное развертывание

1. Инициализация Terraform:
```bash
cd terraform
terraform init
```

2. Проверка конфигурации:
```bash
terraform validate
```

3. Просмотр плана:
```bash
terraform plan -var-file=terraform/terraform.tfvars
```

4. Применение конфигурации:
```bash
terraform apply -auto-approve -var-file=terraform/terraform.tfvars
```

### CI/CD развертывание

Используйте GitLab CI/CD для автоматического развертывания:

1. Зафиксируйте изменения в ветке `main`
2. GitLab автоматически запустит пайплайн
3. После успешного плана, запустите развертывание вручную

## Мониторинг

### Встроенный мониторинг
- Cloud.ru Monitoring для виртуальных машин
- Cloud.ru RDS Monitoring для баз данных
- Cloud.ru OBS Monitoring для хранилища

### Внешний мониторинг (опционально)
Для расширенного мониторинга можно настроить:

```bash
# Установка Prometheus
kubectl apply -f monitoring/prometheus/

# Установка Grafana
kubectl apply -f monitoring/grafana/
```

## Резервное копирование

### Автоматическое резервное копирование
Базы данных автоматически резервируются Cloud.ru.

### Ручное резервное копирование
```bash
# Бэкап конфигурации
tar -czf backup-$(date +%Y%m%d).tar.gz terraform/

# Бэкап данных
mysqldump -h <db_endpoint> -u admin -p database > backup-$(date +%Y%m%d).sql
```

## Удаление инфраструктуры

```bash
terraform destroy -auto-approve -var-file=terraform/terraform.tfvars
```

## Тестирование

### Проверка доступности
```bash
# Проверка балансировщика
curl http://<lb_ip>

# Проверка базы данных
telnet <db_endpoint> 5432

# Проверка Redis
telnet <redis_endpoint> 6379
```

### Нагрузочное тестирование
```bash
# Использование Apache Bench
ab -n 1000 -c 10 http://<lb_ip>/
```

## Оптимизация

### Снижение затрат
1. Используйте автоматическое масштабирование
2. Оптимизируйте размеры ресурсов
3. Используйте Reserved Instances для долгосрочных проектов
4. Отключайте неиспользуемые ресур ночью

### Производительность
1. Настройте кэширование в приложении
2. Используйте CDN для статических файлов
3. Оптимизируйте запросы к базе данных
4. Используйте connection pooling

## Безопасность

1. Используйте сложные пароли
2. Настройте firewall rules
3. Регулярно обновляйте ОС и ПО
4. Включайте шифрование данных
5. Используйте IAM для управления доступом

## Поддержка

При возникновении проблем:
1. Проверьте логи Cloud.ru Console
2. Используйте команду `terraform plan` для диагностики
3. Обратитесь в поддержку Cloud.ru
4. Проверьте документацию Terraform

## Лицензия

MIT License