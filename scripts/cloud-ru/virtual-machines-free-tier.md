# Virtual Machines (Free Tier) - Quick Start

## Создание ВМ

```bash
# Создание ВМ с Ubuntu 22.04
cloud vm create --name vm-free-1 --image ubuntu-22.04 --flavor v1-c-1-2 --network default

# Создание ВМ с CentOS 8
cloud vm create --name vm-free-2 --image centos-8 --flavor v1-c-1-2 --network default

# Создание ВМ с Debian 11
cloud vm create --name vm-free-3 --image debian-11 --flavor v1-c-1-2 --network default
```

## Управление ВМ

```bash
# Запуск ВМ
cloud vm start vm-free-1

# Остановка ВМ
cloud vm stop vm-free-1

# Перезапуск ВМ
cloud vm reboot vm-free-1

# Удаление ВМ
cloud vm delete vm-free-1

# Принудительное удаление
cloud vm delete vm-free-1 --force
```

## Мониторинг и информация

```bash
# Список всех ВМ
cloud vm list

# Детальная информация о ВМ
cloud vm show vm-free-1

# Статус ВМ
cloud vm status vm-free-1

# Логи консоли
cloud vm console vm-free-1

# VNC подключение
cloud vm vnc vm-free-1
```

## Управление дисками

```bash
# Создание диска
cloud disk create --name disk-free-1 --size 20GB --image ubuntu-22.04

# Подключение диска к ВМ
cloud vm attach-disk vm-free-1 --disk disk-free-1

# Отключение диска
cloud vm detach-disk vm-free-1 --disk disk-free-1

# Удаление диска
cloud disk delete disk-free-1
```

## Управление сетью

```bash
# Создание сети
cloud network create --name free-tier-net --cidr 192.168.1.0/24

# Создание подсети
cloud subnet create --name free-tier-subnet --network free-tier-net --cidr 192.168.1.0/24

# Назначение floating IP
cloud vm add-floating-ip vm-free-1 --ip 192.168.1.100

# Удаление floating IP
cloud vm remove-floating-ip vm-free-1 --ip 192.168.1.100
```

## Резервное копирование

```bash
# Создание snapshot
cloud vm snapshot create vm-free-1 --name snapshot-free-1

# Восстановление из snapshot
cloud vm restore vm-free-1 --snapshot snapshot-free-1

# Удаление snapshot
cloud vm snapshot delete snapshot-free-1
```

## Безопасность

```bash
# Создание SSH ключа
cloud key create --name free-tier-key --public-key ~/.ssh/id_rsa.pub

# Назначение ключа ВМ
cloud vm add-key vm-free-1 --key free-tier-key

# Удаление ключа
cloud vm remove-key vm-free-1 --key free-tier-key
```

## Шаблоны

```bash
# Экспорт шаблона ВМ
cloud vm export vm-free-1 --template vm-template-1

# Создание ВМ из шаблона
cloud vm create-from-template --name vm-from-template --template vm-template-1
```

## Очистка

```bash
# Остановка и удаление всех ВМ
cloud vm list --format json | jq -r '.[].name' | xargs -I {} cloud vm delete {} --force

# Удаление всех дисков
cloud disk list --format json | jq -r '.[].name' | xargs -I {} cloud disk delete {} --force

# Удаление всех сетей
cloud network list --format json | jq -r '.[].name' | xargs -I {} cloud network delete {} --force
```

## KMS Интеграция

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
curl -X GET https://api.cloud.ru/v1/virtual-machines \
     --header 'Authorization: Bearer $TOKEN'
```

### Управление SSH ключами через KMS

```bash
# Создание SSH ключа через KMS
curl --location 'https://kms.api.cloud.ru/v1/keys' \
     --header 'Authorization: Bearer $TOKEN' \
     --header 'Content-Type: application/json' \
     --data '{
       "name": "ssh-key-vm",
       "algorithm": "RSA",
       "size": 2048
     }'

# Получение публичного ключа
curl --location 'https://kms.api.cloud.ru/v1/keys/{key_id}/public' \
     --header 'Authorization: Bearer $TOKEN'

# Назначение ключа ВМ
cloud vm create --name vm-kms --image ubuntu-22.04 --flavor v1-c-1-2 --key ssh-key-vm

# Проверка ключей
curl --location 'https://kms.api.cloud.ru/v1/keys' \
     --header 'Authorization: Bearer $TOKEN'
```
