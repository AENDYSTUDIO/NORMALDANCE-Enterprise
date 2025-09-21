# Container Apps - Quick Start

## Создание приложения

```bash
# Создание простого контейнерного приложения
cloud container create --name app-simple --image nginx:latest --port 80:80

# Создание приложения с переменными окружения
cloud container create --name app-env --image node:18 --port 3000:3000 --env NODE_ENV=production

# Создание приложения с volume
cloud container create --name app-volume --image redis:7 --port 6379:6379 --volume redis-data:/data

# Создание приложения с health check
cloud container create --name app-health --image python:3.9 --port 8000:8000 --health-cmd "curl -f http://localhost:8000/health || exit 1"
```

## Управление приложением

```bash
# Запуск приложения
cloud container start app-simple

# Остановка приложения
cloud container stop app-simple

# Перезапуск приложения
cloud container restart app-simple

# Удаление приложения
cloud container delete app-simple

# Принудительное удаление
cloud container delete app-simple --force
```

## Масштабирование

```bash
# Масштабирование до 3 экземпляров
cloud container scale app-simple --replicas 3

# Автоматическое масштабирование
cloud container scale app-simple --min 1 --max 5 --cpu-target 70

# Горизонтальное масштабирование
cloud container scale app-simple --replicas 5

# Вертикальное масштабирование
cloud container scale app-simple --cpu 2 --memory 4Gi
```

## Обновление

```bash
# Обновление образа
cloud container update app-simple --image nginx:1.21

# Обновление переменных окружения
cloud container update app-simple --env NODE_ENV=staging

# Обновление портов
cloud container update app-simple --port 8080:80

# Обновление ресурсов
cloud container update app-simple --cpu 1 --memory 2Gi
```

## Мониторинг

```bash
# Список приложений
cloud container list

# Детальная информация
cloud container show app-simple

# Статус приложения
cloud container status app-simple

# Логи приложения
cloud container logs app-simple

# Логи в реальном времени
cloud container logs app-simple --follow

# Метрики приложения
cloud container metrics app-simple
```

## Сеть

```bash
# Создание Load Balancer
cloud container create-lb --name lb-app --app app-simple --port 80:80

# Создание Ingress
cloud container create-ingress --name ingress-app --app app-simple --host app.example.com

# Создание Internal Load Balancer
cloud container create-internal-lb --name internal-lb --app app-simple --port 80:80 --internal
```

## Хранилища

```bash
# Создание volume
cloud container volume create --name vol-data --size 10Gi

# Подключение volume к приложению
cloud container create --name app-with-volume --image postgres:14 --volume vol-data:/var/lib/postgresql/data

# Создание persistent volume
cloud container create-pv --name pv-app --size 20Gi --storage-class fast-ssd

# Создание persistent claim
cloud container create-pvc --name pvc-app --pv pv-app --size 10Gi
```

## Секреты

```bash
# Создание секрета
cloud container secret create --name secret-db --env DB_PASSWORD=mysecretpassword

# Создание секрета из файла
cloud container secret create --name secret-config --from-file config.json

# Использование секрета в приложении
cloud container create --name app-secret --image myapp --secret secret-db
```

## CI/CD

```bash
# Создание pipeline
cloud container pipeline create --name pipeline-app --git-repo https://github.com/user/app.git --branch main

# Запуск pipeline
cloud container pipeline run pipeline-app

# Статус pipeline
cloud container pipeline status pipeline-app

# Логи pipeline
cloud container pipeline logs pipeline-app
```

## Безопасность

```bash
# Создание network policy
cloud container create-network-policy --name policy-app --app app-simple --allow-ingress --port 80

# Создание service account
cloud container create-service-account --name sa-app --app app-simple

# Создание role
cloud container create-role --name role-app --app app-simple --verb get,list --resource pods

# Создание role binding
cloud container create-role-binding --name rb-app --role role-app --service-account sa-app
```

## Бэкапы

```bash
# Создание бэкапа
cloud container backup create --name backup-app --app app-simple

# Восстановление из бэкапа
cloud container backup restore --name backup-app --app app-restored

# Список бэкапов
cloud container backup list

# Удаление бэкапа
cloud container backup delete backup-app
```

## Очистка

```bash
# Удаление всех приложений
cloud container list --format json | jq -r '.[].name' | xargs -I {} cloud container delete {} --force

# Удаление всех load balancers
cloud container lb list --format json | jq -r '.[].name' | xargs -I {} cloud container lb delete {}

# Удаление всех ingress
cloud container ingress list --format json | jq -r '.[].name' | xargs -I {} cloud container ingress delete {}

# Удаление всех volumes
cloud container volume list --format json | jq -r '.[].name' | xargs -I {} cloud container volume delete {}
```
