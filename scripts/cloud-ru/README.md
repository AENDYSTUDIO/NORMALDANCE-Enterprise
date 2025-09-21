# CLOUD.RU Quick Start Guides

## 🚀 Быстрый старт с CLOUD.RU

### Доступные сервисы

| Сервис                       | Описание                                | Файл                                                           |
| ---------------------------- | --------------------------------------- | -------------------------------------------------------------- |
| Virtual Machines (Free Tier) | Виртуальные машины с бесплатным тарифом | [virtual-machines-free-tier.md](virtual-machines-free-tier.md) |
| Managed Kubernetes           | Управляемые Kubernetes кластеры         | [managed-kubernetes.md](managed-kubernetes.md)                 |
| Container Apps               | Контейнерные приложения                 | [container-apps.md](container-apps.md)                         |
| Evolution Object Storage     | Объектное хранилище                     | [evolution-object-storage.md](evolution-object-storage.md)     |

### Предварительные требования

```bash
# Установка Cloud.ru CLI
curl -sSL https://cloud.ru/cli/install.sh | bash
export PATH="$PATH:$HOME/.cloud/bin"

# Настройка API ключей
cloud config set api-key 7d6d24281a43e50068d35d63f7ead515
cloud config set customer-id 9e5cb9bd-968c-4b1c-ada9-abecdb0b6d95
```

### Демонстрационные скрипты

| Скрипт                                 | Описание                        |
| -------------------------------------- | ------------------------------- |
| [demo-vms.sh](demo-vms.sh)             | Демонстрация Virtual Machines   |
| [demo-k8s.sh](demo-k8s.sh)             | Демонстрация Managed Kubernetes |
| [demo-container.sh](demo-container.sh) | Демонстрация Container Apps     |
| [demo-storage.sh](demo-storage.sh)     | Демонстрация Object Storage     |

### Основные команды

```bash
# Проверка статуса
cloud status

# Список сервисов
cloud service list

# Список виртуальных машин
cloud vm list

# Список кластеров
cloud k8s list

# Список бакетов
cloud storage list

# Логи сервиса
cloud logs <service-name>

# Масштабирование
cloud scale <service-name> --replicas <count>
```

### Полезные ссылки

- [Документация CLOUD.RU](https://cloud.ru/docs/)
- [CLI Reference](https://cloud.ru/cli/reference)
- [API Reference](https://cloud.ru/api)

---

_Создано для проекта NORMALDANCE_
_Версия: 1.0_
_Дата: 2025-09-21_

## KMS (Key Management Service)

### Аутентификация в API Key Management

```bash
# Получение токена через IAM API
curl --location 'https://iam.api.cloud.ru/api/v1/auth/token' \
     --header 'Content-Type: application/json' \
     --data '{
       "keyId": "<key_id>",
       "secret": "<secret>"
     }'

# Сохранение токена
export TOKEN="YOUR_TOKEN_HERE"

# Использование токена в API запросах
curl -X GET https://api.cloud.ru/v1/keys \
     --header 'Authorization: Bearer $TOKEN'
```

### Управление ключами

```bash
# Создание ключа
curl --location 'https://kms.api.cloud.ru/v1/keys' \
     --header 'Authorization: Bearer $TOKEN' \
     --header 'Content-Type: application/json' \
     --data '{
       "name": "my-key",
       "algorithm": "RSA",
       "size": 2048
     }'

# Получение списка ключей
curl --location 'https://kms.api.cloud.ru/v1/keys' \
     --header 'Authorization: Bearer $TOKEN'

# Получение информации о ключе
curl --location 'https://kms.api.cloud.ru/v1/keys/{key_id}' \
     --header 'Authorization: Bearer $TOKEN'

# Удаление ключа
curl --location --request DELETE 'https://kms.api.cloud.ru/v1/keys/{key_id}' \
     --header 'Authorization: Bearer $TOKEN'
```
