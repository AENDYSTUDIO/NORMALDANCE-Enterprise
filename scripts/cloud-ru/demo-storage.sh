#!/bin/bash

# Демонстрация Evolution Object Storage
# Только CLI команды без объяснений

echo "=== ДЕМОНСТРАЦИЯ EVOLUTION OBJECT STORAGE ==="

# Создание бакетов
cloud storage create-bucket --name demo-bucket-1 --region msk
cloud storage create-bucket --name demo-bucket-2 --region msk --versioning
cloud storage create-bucket --name demo-bucket-3 --region msk --public-read

# Список бакетов
cloud storage list-buckets

# Создание тестовых файлов
echo "Hello, World!" > demo-file-1.txt
echo "This is a test file for Object Storage" > demo-file-2.txt
mkdir -p demo-dir
echo "File in directory" > demo-dir/demo-file-3.txt

# Загрузка файлов
cloud storage upload --file demo-file-1.txt --bucket demo-bucket-1 --object demo-file-1.txt
cloud storage upload --file demo-file-2.txt --bucket demo-bucket-1 --object demo-file-2.txt
# Создание симметричного ключа
cloud storage create-symmetric-key --name demo-symmetric-key --algorithm AES256 --description "Demo symmetric key"
# Шифрование объекта с симметричным ключом
cloud storage encrypt-object --bucket demo-bucket-2 --object demo-file-1.txt --key-id demo-symmetric-key --symmetric

>>>>>>> REPLACE

>>>>>>> REPLACE
cloud storage upload-dir --dir demo-dir --bucket demo-bucket-1 --prefix demo-dir/

# Список объектов
cloud storage list-objects --bucket demo-bucket-1

# Загрузка файлов с метаданными
cloud storage upload --file demo-file-1.txt --bucket demo-bucket-2 --object demo-file-1.txt --metadata "Content-Type=text/plain"
cloud storage upload --file demo-file-2.txt --bucket demo-bucket-2 --object demo-file-2.txt --metadata "Content-Type=text/plain"

# Скачивание файлов
cloud storage download --bucket demo-bucket-1 --object demo-file-1.txt --output downloaded-file-1.txt
cloud storage download-dir --bucket demo-bucket-1 --prefix demo-dir/ --output downloaded-dir/

# Статистика бакетов
cloud storage stats --bucket demo-bucket-1
cloud storage stats --bucket demo-bucket-2

# Копирование объектов
cloud storage copy-object --source-bucket demo-bucket-1 --source-object demo-file-1.txt --dest-bucket demo-bucket-3 --dest-object copied-file-1.txt

# Перемещение объектов
cloud storage move-object --source-bucket demo-bucket-1 --source-object demo-file-2.txt --dest-bucket demo-bucket-1 --dest-object moved-file-2.txt

# Создание policy
cloud storage create-policy --name demo-policy-1 --document '{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"AWS": "*"},
    "Action": ["s3:GetObject"],
    "Resource": ["arn:aws:s3:::demo-bucket-3/*"]
  }]
}'

# Применение policy
cloud storage apply-policy --bucket demo-bucket-3 --policy demo-policy-1

# Включение CDN
cloud storage enable-cdn --bucket demo-bucket-3

# Статистика CDN
cloud storage cdn-stats --bucket demo-bucket-3

# Создание ключа шифрования
cloud storage create-key --name demo-key-1 --description "Demo encryption key"

# Шифрование объекта
cloud storage encrypt-object --bucket demo-bucket-2 --object demo-file-1.txt --key-id demo-key-1

# Создание бэкапа
cloud storage backup-bucket --bucket demo-bucket-1 --backup demo-bucket-1-backup

# Автоматический бэкап
cloud storage auto-backup --bucket demo-bucket-2 --schedule "0 2 * * *" --retention 7

# Логи доступа
cloud storage access-logs --bucket demo-bucket-1 --output demo-logs/

# События бакета
cloud storage events --bucket demo-bucket-1 --output demo-events/

# Создание lifecycle policy
cloud storage create-lifecycle --bucket demo-bucket-1 --rules '{
  "Rules": [{
    "ID": "DeleteOldObjects",
    "Status": "Enabled",
    "Expiration": { "Days": 30 }
  }]
}'

# Создание webhook
cloud storage create-webhook --bucket demo-bucket-1 --url https://httpbin.org/post --events "s3:ObjectCreated:*"

# Синхронизация
cloud storage sync --dir demo-dir --bucket demo-bucket-1 --prefix sync-test/

# Удаление объектов
cloud storage delete-object --bucket demo-bucket-1 --object demo-file-1.txt
cloud storage delete-object --bucket demo-bucket-1 --object moved-file-2.txt
cloud storage delete-objects-by-prefix --bucket demo-bucket-1 --prefix demo-dir/

# Удаление бэкапов
cloud storage delete-backup demo-bucket-1-backup --force

# Удаление webhook
cloud storage delete-webhook --bucket demo-bucket-1 --url https://httpbin.org/post

# Отключение CDN
cloud storage disable-cdn --bucket demo-bucket-3

# Удаление policy
cloud storage delete-policy --bucket demo-bucket-3 --policy demo-policy-1

# Удаление ключа шифрования
cloud storage delete-key demo-key-1 --force

# Удаление бакетов
cloud storage delete-bucket demo-bucket-1 --force
cloud storage delete-bucket demo-bucket-2 --force
cloud storage delete-bucket demo-bucket-3 --force

# Очистка тестовых файлов
rm -f demo-file-1.txt demo-file-2.txt downloaded-file-1.txt
rm -rf demo-dir downloaded-dir demo-logs demo-events

echo "=== ДЕМОНСТРАЦИЯ ЗАВЕРШЕНА ==="
# Удаление симметричного ключа
cloud storage delete-symmetric-key demo-symmetric-key --force
