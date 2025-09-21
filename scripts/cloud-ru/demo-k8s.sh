#!/bin/bash

# Демонстрация Managed Kubernetes
# Только CLI команды без объяснений

echo "=== ДЕМОНСТРАЦИЯ MANAGED KUBERNETES ==="

# Создание кластера
cloud k8s create --name demo-k8s-cluster --version 1.27.0 --nodes 2 --node-flavor v2-c-2-4

# Список кластеров
cloud k8s list

# Статус кластера
cloud k8s status demo-k8s-cluster

# Настройка kubectl
cloud k8s config demo-k8s-cluster > ~/.kube/config-demo
export KUBECONFIG=~/.kube/config-demo

# Проверка подключения
kubectl cluster-info
kubectl get nodes

# Развертывание тестового приложения
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: demo-app
  template:
    metadata:
      labels:
        app: demo-app
    spec:
      containers:
      - name: demo-app
        image: nginx:latest
        ports:
        - containerPort: 80
EOF

# Создание service
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: demo-service
spec:
  selector:
    app: demo-app
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  type: LoadBalancer
EOF

# Проверка pod'ов
kubectl get pods
kubectl get services

# Масштабирование deployment
kubectl scale deployment demo-app --replicas 3

# Обновление deployment
kubectl set image deployment/demo-app demo-app=nginx:1.21

# Проверка обновления
kubectl rollout status deployment/demo-app

# Создание namespace
kubectl create namespace demo-namespace

# Развертывание в namespace
kubectl apply -f - -n demo-namespace <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app-ns
  namespace: demo-namespace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: demo-app-ns
  template:
    metadata:
      labels:
        app: demo-app-ns
    spec:
      containers:
      - name: demo-app-ns
        image: redis:7
        ports:
        - containerPort: 6379
EOF

# Проверка всех namespace
kubectl get namespaces
kubectl get pods -n demo-namespace

# Удаление ресурсов
kubectl delete namespace demo-namespace
kubectl delete deployment demo-app
kubectl delete service demo-service

# Остановка кластера
cloud k8s stop demo-k8s-cluster

# Удаление кластера
cloud k8s delete demo-k8s-cluster --force

echo "=== ДЕМОНСТРАЦИЯ ЗАВЕРШЕНА ==="