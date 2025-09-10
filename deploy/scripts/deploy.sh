#!/bin/bash

echo "=== ДЕПЛОЙ DNB1ST ПРОЕКТОВ ==="

# Переход в рабочую директорию
cd /var/www/

# Клонирование репозиториев
echo "Клонирование репозиториев..."
git clone https://github.com/your-username/dnb1st-platform.git dnb1st.ru
git clone https://github.com/your-username/dnb1st-store.git dnb1st.store

# Настройка платформы (dnb1st.ru)
echo "Настройка платформы..."
cd /var/www/dnb1st.ru
npm install
cp .env.example .env.local

# Настройка магазина (dnb1st.store)
echo "Настройка магазина..."
cd /var/www/dnb1st.store
npm install
cp .env.example .env.local

# Сборка проектов
echo "Сборка проектов..."
cd /var/www/dnb1st.ru
npm run build

cd /var/www/dnb1st.store
npm run build

# Запуск через Docker Compose
echo "Запуск контейнеров..."
cd /var/www/
docker-compose -f deploy/docker/docker-compose.yml up -d

# Проверка статуса
echo "Проверка статуса..."
docker ps
sudo systemctl status nginx

echo "=== ДЕПЛОЙ ЗАВЕРШЕН ==="
echo "dnb1st.ru - http://176.108.246.49:3000"
echo "dnb1st.store - http://176.108.246.49:3001"