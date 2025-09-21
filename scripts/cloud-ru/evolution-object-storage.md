# Evolution Object Storage - Quick Start

## Создание бакета

```bash
# Создание бакета
cloud storage create-bucket --name my-bucket --region msk

# Создание бакета с версионированием
cloud storage create-bucket --name my-bucket-versioned --region msk --versioning

# Создание бакета с шифрованием
cloud storage create-bucket --name my-bucket-encrypted --region msk --encryption

# Создание публичного бакета
cloud storage create-bucket --name my-bucket-public --region msk --public-read
```

## Управление бакетами

```bash
# Список бакетов
cloud storage list-buckets

# Детальная информация о бакете
cloud storage show-bucket my-bucket

# Удаление бакета
cloud storage delete-bucket my-bucket

# Принудительное удаление
cloud storage delete-bucket my-bucket --force

# Восстановление удаленного бакета
cloud storage restore-bucket my-bucket
```

## Работа с объектами

```bash
# Загрузка файла
cloud storage upload --file /path/to/file.txt --bucket my-bucket --object file.txt

# Загрузка файла с метаданными
cloud storage upload --file /path/to/file.txt --bucket my-bucket --object file.txt --metadata "Content-Type=text/plain"

# Загрузка директории
cloud storage upload-dir --dir /path/to/dir --bucket my-bucket --prefix dir/

# Скачивание файла
cloud storage download --bucket my-bucket --object file.txt --output /path/to/file.txt

# Скачивание директории
cloud storage download-dir --bucket my-bucket --prefix dir/ --output /path/to/dir/

# Удаление объекта
cloud storage delete-object --bucket my-bucket --object file.txt

# Удаление нескольких объектов
cloud storage delete-objects --bucket my-bucket --objects "file1.txt,file2.txt"
```

## Управление доступом

```bash
# Создание policy
cloud storage create-policy --name policy-read-only --document '{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"AWS": "*"},
    "Action": ["s3:GetObject"],
    "Resource": ["arn:aws:s3:::my-bucket/*"]
  }]
}'

# Применение policy к бакету
cloud storage apply-policy --bucket my-bucket --policy policy-read-only

# Создание пользователя
cloud storage create-user --name user-read-only --access-key AKIAIOSFODNN7EXAMPLE --secret-key wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

# Назначение прав пользователю
cloud storage grant-user --bucket my-bucket --user user-read-only --read-only
```

## Синхронизация

```bash
# Синхронизация локальной директории
cloud storage sync --dir /local/path --bucket my-bucket --prefix sync/

# Синхронизация с удаленной директорией
cloud storage sync --bucket my-bucket --prefix sync/ --output /local/path

# Двусторонняя синхронизация
cloud storage sync --dir /local/path --bucket my-bucket --prefix sync/ --two-way
```

## Копирование и перемещение

```bash
# Копирование объекта в другой бакет
cloud storage copy-object --source-bucket my-bucket --source-object file.txt --dest-bucket my-bucket2 --dest-object file.txt

# Перемещение объекта
cloud storage move-object --source-bucket my-bucket --source-object file.txt --dest-bucket my-bucket --dest-object new-file.txt

# Копирование между регионами
cloud storage cross-region-copy --source-bucket my-bucket --source-object file.txt --dest-bucket my-bucket-spb --dest-region spb
```

## Шифрование

```bash
# Шифрование объекта
cloud storage encrypt-object --bucket my-bucket --object file.txt --key-id my-key

# Расшифровка объекта
cloud storage decrypt-object --bucket my-bucket --object file.txt --output /path/to/decrypted.txt

# Создание ключа шифрования
cloud storage create-key --name my-key --description "My encryption key"
```

## Бэкапы

```bash
# Создание бэкапа бакета
cloud storage backup-bucket --bucket my-bucket --backup my-bucket-backup

# Восстановление бэкапа
cloud storage restore-bucket --backup my-bucket-backup --bucket my-bucket-restored

# Автоматический бэкап
cloud storage auto-backup --bucket my-bucket --schedule "0 2 * * *" --retention 7
```

## Мониторинг

```bash
# Статистика бакета
cloud storage stats --bucket my-bucket

# Логи доступа
cloud storage access-logs --bucket my-bucket --output /path/to/logs/

# События бакета
cloud storage events --bucket my-bucket --output /path/to/events/

# Метрики использования
cloud storage metrics --bucket my-bucket --period 24h
```

## CDN

```bash
# Включение CDN
cloud storage enable-cdn --bucket my-bucket

# Отключение CDN
cloud storage disable-cdn --bucket my-bucket

# Настройка CDN
cloud storage configure-cdn --bucket my-bucket --cache-ttl 3600 --compression

# Статистика CDN
cloud storage cdn-stats --bucket my-bucket
```

## Очистка

```bash
# Удаление всех объектов
cloud storage list-objects --bucket my-bucket --format json | jq -r '.[].Key' | xargs -I {} cloud storage delete-object --bucket my-bucket --object {}

# Удаление объектов по префиксу
cloud storage delete-objects-by-prefix --bucket my-bucket --prefix old/

# Удаление всех версий
cloud storage delete-all-versions --bucket my-bucket

# Удаление всех удаленных объектов
cloud storage delete-all-deleted --bucket my-bucket
```

## Интеграция

```bash
# Настройка webhook
cloud storage create-webhook --bucket my-bucket --url https://myapp.com/webhook --events "s3:ObjectCreated:*"

# Настройка триггера
cloud storage create-trigger --bucket my-bucket --function my-lambda --events "s3:ObjectCreated:*"

# Настройка lifecycle policy
cloud storage create-lifecycle --bucket my-bucket --rules '{
  "Rules": [{
    "ID": "DeleteOldObjects",
    "Status": "Enabled",
    "Expiration": { "Days": 365 }
  }]
}'
```

## Симметричные ключи

```bash
# Создание симметричного ключа
cloud storage create-symmetric-key --name my-symmetric-key --algorithm AES256 --description "My symmetric key"

# Шифрование объекта с симметричным ключом
cloud storage encrypt-object --bucket my-bucket --object file.txt --key-id my-symmetric-key --symmetric

# Расшифровка объекта с симметричным ключом
cloud storage decrypt-object --bucket my-bucket --object file.txt --key-id my-symmetric-key --output /path/to/decrypted.txt

# Удаление симметричного ключа
cloud storage delete-symmetric-key my-symmetric-key --force
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
curl -X GET https://api.cloud.ru/v1/storage/buckets \
     --header 'Authorization: Bearer $TOKEN'
```

### Управление ключами шифрования через KMS

```bash
# Создание ключа шифрования
curl --location 'https://kms.api.cloud.ru/v1/keys' \
     --header 'Authorization: Bearer $TOKEN' \
     --header 'Content-Type: application/json' \
     --data '{
       "name": "storage-encryption-key",
       "algorithm": "AES256",
       "usage": "ENCRYPT_DECRYPT"
     }'

# Получение списка ключей
curl --location 'https://kms.api.cloud.ru/v1/keys' \
     --header 'Authorization: Bearer $TOKEN'

# Получение информации о ключе
curl --location 'https://kms.api.cloud.ru/v1/keys/{key_id}' \
     --header 'Authorization: Bearer $TOKEN'

# Вращение ключа
curl --location 'https://kms.api.cloud.ru/v1/keys/{key_id}/rotate' \
     --header 'Authorization: Bearer $TOKEN'

# Удаление ключа
curl --location --request DELETE 'https://kms.api.cloud.ru/v1/keys/{key_id}' \
     --header 'Authorization: Bearer $TOKEN'
```

### Шифрование объектов с KMS

```bash
# Шифрование объекта с использованием KMS ключа
curl --location 'https://kms.api.cloud.ru/v1/encrypt' \
     --header 'Authorization: Bearer $TOKEN' \
     --header 'Content-Type: application/json' \
     --data '{
       "key_id": "storage-encryption-key",
       "plaintext": "YOUR_DATA_HERE"
     }'

# Расшифровка объекта
curl --location 'https://kms.api.cloud.ru/v1/decrypt' \
     --header 'Authorization: Bearer $TOKEN' \
     --header 'Content-Type: application/json' \
     --data '{
       "key_id": "storage-encryption-key",
       "ciphertext": "ENCRYPTED_DATA_HERE"
     }'
```
