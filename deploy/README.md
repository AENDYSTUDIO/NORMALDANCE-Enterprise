# Деплой DNB1ST на сервер

## Быстрый старт

1. **Подключиться к серверу:**
```bash
ssh aendy@176.108.246.49
```

2. **Скопировать файлы на сервер:**
```bash
scp -r deploy/ aendy@176.108.246.49:/home/aendy/
```

3. **Настроить сервер:**
```bash
chmod +x /home/aendy/deploy/scripts/*.sh
sudo /home/aendy/deploy/scripts/server-setup.sh
```

4. **Деплой проектов:**
```bash
/home/aendy/deploy/scripts/deploy.sh
```

5. **Настроить SSL (после работы DNS):**
```bash
sudo /home/aendy/deploy/scripts/ssl-setup.sh
```

## Структура

- `nginx/` - конфигурации nginx
- `docker/` - Docker Compose файлы
- `scripts/` - скрипты автоматизации

## Проекты

- **dnb1st.ru** → порт 3000 (музыкальная платформа)
- **dnb1st.store** → порт 3001 (магазин)

## Проверка

```bash
# Статус сервисов
sudo systemctl status nginx
docker ps

# Логи
docker logs dnb1st-platform
docker logs dnb1st-store

# Тест доменов
curl -I http://dnb1st.ru
curl -I http://dnb1st.store
```