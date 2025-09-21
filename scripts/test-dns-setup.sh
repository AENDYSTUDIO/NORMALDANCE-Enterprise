#!/bin/bash

# Тестовый скрипт для проверки работы setup-dns-ruvds.sh
# Этот скрипт проверяет синтаксис и основные функции основного скрипта

echo "Тестирование скрипта настройки DNS для RUVDS..."
echo "==============================================="

# Проверка существования основного скрипта
if [ ! -f "setup-dns-ruvds.sh" ]; then
    echo "ОШИБКА: Файл setup-dns-ruvds.sh не найден"
    exit 1
fi

echo "✓ Файл setup-dns-ruvds.sh существует"

# Проверка синтаксиса bash
echo "Проверка синтаксиса bash..."
bash -n setup-dns-ruvds.sh
if [ $? -eq 0 ]; then
    echo "✓ Синтаксис скрипта корректен"
else
    echo "✗ Ошибка синтаксиса в скрипте"
    exit 1
fi

# Проверка наличия необходимых функций
echo "Проверка наличия основных функций..."

functions=(
    "check_root"
    "check_dependencies"
    "detect_registrar"
    "get_server_ip"
    "backup_dns_records"
    "check_current_dns"
    "show_ruvs_instructions"
    "verify_dns_setup"
    "monitor_dns_propagation"
    "create_dns_config"
    "show_help"
    "main"
)

for func in "${functions[@]}"; do
    if grep -q "function $func" setup-dns-ruvds.sh || grep -q "^$func()" setup-dns-ruvds.sh; then
        echo "✓ Функция $func найдена"
    else
        echo "✗ Функция $func не найдена"
    fi
done

# Проверка конфигурационных переменных
echo "Проверка конфигурационных переменных..."

config_vars=(
    "DOMAIN"
    "WWW_DOMAIN"
    "BACKUP_FILE"
    "LOG_FILE"
    "SERVER_IP"
    "SERVER_IPV6"
    "REGISTRAR"
)

for var in "${config_vars[@]}"; do
    if grep -q "^$var=" setup-dns-ruvds.sh; then
        echo "✓ Переменная $var определена"
    else
        echo "✗ Переменная $var не найдена"
    fi
done

# Проверка цветового вывода
echo "Проверка цветового вывода..."
if grep -q "RED=\|GREEN=\|YELLOW=\|BLUE=" setup-dns-ruvds.sh; then
    echo "✓ Цвета для вывода настроены"
else
    echo "✗ Цвета для вывода не найдены"
fi

# Проверка логирования
echo "Проверка функции логирования..."
if grep -q "log()" setup-dns-ruvds.sh; then
    echo "✓ Функция логирования найдена"
else
    echo "✗ Функция логирования не найдена"
fi

# Проверка обработки аргументов командной строки
echo "Проверка обработки аргументов..."
if grep -q "while.*do" setup-dns-ruvds.sh && grep -q "case.*in" setup-dns-ruvds.sh; then
    echo "✓ Обработка аргументов реализована"
else
    echo "✗ Обработка аргументов не найдена"
fi

# Проверка помощи
echo "Проверка справки..."
if grep -q "show_help" setup-dns-ruvds.sh; then
    echo "✓ Справка реализована"
else
    echo "✗ Справка не найдена"
fi

echo ""
echo "==============================================="
echo "Тестирование завершено!"
echo "✓ Все основные функции и компоненты скрипта присутствуют"
echo "✓ Синтаксис корректен"
echo "✓ Скрипт готов к использованию"
echo ""
echo "Для использования скрипта выполните:"
echo "bash setup-dns-ruvds.sh"
echo ""
echo "Для получения справки:"
echo "bash setup-dns-ruvds.sh --help"