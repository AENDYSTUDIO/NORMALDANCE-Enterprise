#!/bin/bash

# Демонстрация Virtual Machines (Free Tier)
# Только CLI команды без объяснений

echo "=== ДЕМОНСТРАЦИЯ VIRTUAL MACHINES (FREE TIER) ==="

# Создание ВМ
cloud vm create --name demo-vm-1 --image ubuntu-22.04 --flavor v1-c-1-2 --network default
cloud vm create --name demo-vm-2 --image centos-8 --flavor v1-c-1-2 --network default

# Список ВМ
cloud vm list

# Запуск ВМ
cloud vm start demo-vm-1
cloud vm start demo-vm-2

# Статус ВМ
cloud vm status demo-vm-1
cloud vm status demo-vm-2

# Создание дисков
cloud disk create --name demo-disk-1 --size 10GB --image ubuntu-22.04
cloud disk create --name demo-disk-2 --size 20GB --image centos-8

# Подключение дисков
cloud vm attach-disk demo-vm-1 --disk demo-disk-1
cloud vm attach-disk demo-vm-2 --disk demo-disk-2

# VNC подключение
echo "VNC подключение: cloud vm vnc demo-vm-1"

# Логи консоли
cloud vm console demo-vm-1
# Создание SSH ключа с предоставленным публичным ключом
cloud key create --name demo-key --public-key -----BEGIN RSA PUBLIC KEY-----
# Назначение SSH ключа к ВМ
cloud vm add-key demo-vm-1 --key demo-key
cloud vm add-key demo-vm-2 --key demo-key

MIIBigKCAYEAvaF9z24vorSPAa6nJYUfyhxNW97ZqWXmhcVfxH4D/XnLg4CTEExT
lPjJeWrXS16D7xcqAhu/eAj4xWI3ZsubbW/TJKkg+yS3fk/6wypyQdqMSplSCZNi
nuPktxLjC2EC+8lym4/6teyjEUFymCQrOSy8mBMHu6u5rosTwAsim8vlptsvCi4u
sDLE284XQhAqEcuORcLEU0Fa3LAgsmZ2BsIlLcZc86m6Df35PE3mpyJISDdvBMtD
FzV13jCQvsNujSxnJPyKt5LZnsBBGWcSjPTxwj6HxPvjkv3+BWnf9oL2jN4NKH8i
JtAjR6udgUcJmisBefxzu+TImWCDu2ICqNwpvkF9J9bpN02EtEkkR3k88eGDCPRl
8LkWF0f1gTPQBVzZYw5VXI2huMc0VplV4MwhkD2kgTEaJpc+gdIHTBmX4NxMWYX1
fz9f9BUSc38RwZN8g9L24dIPrQ3KT2TMz5Hivba9OrQFfMlyFPH6nBQLTZFJ6RwI
83NsTHVLd7fPAgMBAAE=
-----END RSA PUBLIC KEY-----


# Остановка ВМ
cloud vm stop demo-vm-1
cloud vm stop demo-vm-2

# Удаление ВМ
cloud vm delete demo-vm-1 --force
cloud vm delete demo-vm-2 --force

# Удаление дисков
cloud disk delete demo-disk-1 --force
cloud disk delete demo-disk-2 --force

echo "=== ДЕМОНСТРАЦИЯ ЗАВЕРШЕНА ==="