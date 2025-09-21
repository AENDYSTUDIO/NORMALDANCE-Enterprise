# Managed Kubernetes - Quick Start

## Создание кластера

```bash
# Создание кластера с 3 узлами
cloud k8s create --name k8s-cluster-1 --version 1.27.0 --nodes 3 --node-flavor v2-c-2-4

# Создание кластера с кастомными настройками
cloud k8s create --name k8s-cluster-2 --version 1.26.0 --nodes 5 --node-flavor v2-c-4-8 --network k8s-net

# Создание single-node кластера
cloud k8s create --name k8s-single --version 1.27.0 --nodes 1 --node-flavor v1-c-2-2
```

## Управление кластером

```bash
# Запуск кластера
cloud k8s start k8s-cluster-1

# Остановка кластера
cloud k8s stop k8s-cluster-1

# Перезапуск кластера
cloud k8s reboot k8s-cluster-1

# Удаление кластера
cloud k8s delete k8s-cluster-1

# Принудительное удаление
cloud k8s delete k8s-cluster-1 --force
```

## Настройка kubectl

```bash
# Получение конфигурации kubectl
cloud k8s config k8s-cluster-1 > ~/.kube/config

# Установка текущего кластера
cloud k8s use k8s-cluster-1

# Проверка подключения
kubectl cluster-info

# Проверка узлов
kubectl get nodes
```

## Управление узлами

```bash
# Масштабирование кластера
cloud k8s scale k8s-cluster-1 --nodes 5

# Обновление узлов
cloud k8s upgrade k8s-cluster-1 --version 1.28.0

# Перезапуск узлов
cloud k8s restart-nodes k8s-cluster-1

# Обновление узлов
cloud k8s update-nodes k8s-cluster-1
```

## Мониторинг

```bash
# Список кластеров
cloud k8s list

# Детальная информация о кластере
cloud k8s show k8s-cluster-1

# Статус кластера
cloud k8s status k8s-cluster-1

# Логи кластера
cloud k8s logs k8s-cluster-1

# Метрики кластера
cloud k8s metrics k8s-cluster-1
```

## Работа с приложениями

```bash
# Развертывание приложения
kubectl apply -f app-deployment.yaml

# Масштабирование deployment
kubectl scale deployment my-app --replicas 3

# Обновление deployment
kubectl set image deployment/my-app app=my-app:latest

# Откат deployment
kubectl rollout undo deployment/my-app
```

## Сеть

```bash
# Создание Ingress
kubectl apply -f ingress.yaml

# Создание LoadBalancer
kubectl apply -f loadbalancer.yaml

# Создание ClusterIP
kubectl apply -f clusterip.yaml
```

## Хранилища

```bash
# Создание PersistentVolume
kubectl apply -f pv.yaml

# Создание PersistentVolumeClaim
kubectl apply -f pvc.yaml

# Монтирование storage в pod
kubectl apply -f pod-with-storage.yaml
```

## Безопасность

```bash
# Создание ServiceAccount
kubectl create serviceaccount sa-app

# Создание Role
kubectl create role role-app --verb=get,list --resource=pods

# Создание RoleBinding
kubectl create rolebinding rb-app --role=role-app --serviceaccount=default:sa-app

# Создание NetworkPolicy
kubectl apply -f network-policy.yaml
```

## Инструменты

```bash
# Установка dashboard
cloud k8s install-dashboard k8s-cluster-1

# Доступ к dashboard
cloud k8s dashboard k8s-cluster-1

# Установка monitoring
cloud k8s install-monitoring k8s-cluster-1

# Установка logging
cloud k8s install-logging k8s-cluster-1
```

## Очистка

```bash
# Удаление всех namespace
kubectl delete namespace --all

# Удаление всех deployments
kubectl delete deployment --all --all-namespaces

# Удаление всех services
kubectl delete service --all --all-namespaces

# Удаление кластера
cloud k8s delete k8s-cluster-1 --force
```
