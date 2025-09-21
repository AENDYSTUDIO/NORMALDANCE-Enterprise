#!/bin/bash

# Демонстрация Container Apps
# Только CLI команды без объяснений

echo "=== ДЕМОНСТРАЦИЯ CONTAINER APPS ==="

# Создание простого приложения
cloud container create --name demo-app-1 --image nginx:latest --port 80:80

# Создание приложения с переменными окружения
cloud container create --name demo-app-2 --image node:18 --port 3000:3000 --env NODE_ENV=production --env PORT=3000

# Создание приложения с volume
cloud container create --name demo-app-3 --image redis:7 --port 6379:6379 --volume redis-data:/data

# Список приложений
cloud container list

# Запуск приложений
cloud container start demo-app-1
cloud container start demo-app-2
cloud container start demo-app-3

# Статус приложений
cloud container status demo-app-1
cloud container status demo-app-2
cloud container status demo-app-3

# Масштабирование приложений
cloud container scale demo-app-1 --replicas 2
cloud container scale demo-app-2 --replicas 3

# Логи приложений
cloud container logs demo-app-1
cloud container logs demo-app-2 --follow

# Создание Load Balancer
cloud container create-lb --name demo-lb-1 --app demo-app-1 --port 80:80

# Создание Ingress
cloud container create-ingress --name demo-ingress-1 --app demo-app-2 --host demo.example.com

# Создание volume
cloud container volume create --name demo-volume-1 --size 5Gi

# Подключение volume к приложению
cloud container create --name demo-app-4 --image postgres:14 --volume demo-volume-1:/var/lib/postgresql/data --env POSTGRES_PASSWORD=demo

# Создание секрета
cloud container secret create --name demo-secret-1 --env DB_PASSWORD=demo123

# Создание приложения с секретом
cloud container create --name demo-app-5 --image myapp --secret demo-secret-1

# Обновление приложений
cloud container update demo-app-2 --image node:18.17
cloud container update demo-app-2 --env NODE_ENV=staging

# Метрики приложений
cloud container metrics demo-app-1
cloud container metrics demo-app-2

# Создание network policy
cloud container create-network-policy --name demo-policy-1 --app demo-app-1 --allow-ingress --port 80

# Создание service account
cloud container create-service-account --name demo-sa-1 --app demo-app-1

# Создание role
cloud container create-role --name demo-role-1 --app demo-app-1 --verb get,list --resource pods

# Создание role binding
cloud container create-role-binding --name demo-rb-1 --role demo-role-1 --service-account demo-sa-1

# Остановка приложений
cloud container stop demo-app-1
cloud container stop demo-app-2
cloud container stop demo-app-3
cloud container stop demo-app-4
cloud container stop demo-app-5

# Удаление приложений
cloud container delete demo-app-1 --force
cloud container delete demo-app-2 --force
cloud container delete demo-app-3 --force
cloud container delete demo-app-4 --force
cloud container delete demo-app-5 --force

# Удаление Load Balancer
cloud container lb delete demo-lb-1 --force

# Удаление Ingress
cloud container ingress delete demo-ingress-1 --force

# Удаление volume
cloud container volume delete demo-volume-1 --force

# Удаление секрета
cloud container secret delete demo-secret-1 --force

echo "=== ДЕМОНСТРАЦИЯ ЗАВЕРШЕНА ==="