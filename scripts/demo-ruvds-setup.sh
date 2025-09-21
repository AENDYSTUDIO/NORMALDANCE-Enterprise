#!/bin/bash

# ==============================================================================
# ДЕМОНСТРАЦИОННАЯ ВЕРСИЯ скрипта для заказа и настройки VPS на RUVDS
# ==============================================================================
# 
# Эта версия показывает как будет работать скрипт без реальных изменений системы
# ==============================================================================

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

pause() {
    read -p "Нажмите Enter для продолжения..."
}

demo_research_tariffs() {
    log_info "Исследование тарифов RUVDS..."
    echo
    echo "=== ТАРИФЫ RUVDS ДЛЯ ПРОЕКТА NORMALDANCE ==="
    echo
    echo "1. Бюджетные тарифы (рекомендуемые):"
    echo "   - VPS-1: 1 vCPU, 1 GB RAM, 25 GB SSD, 1 TB трафик - от 150 руб/мес"
    echo "   - VPS-2: 1 vCPU, 2 GB RAM, 25 GB SSD, 1 TB трафик - от 250 руб/мес"
    echo "   - VPS-3: 2 vCPU, 2 GB RAM, 25 GB SSD, 1 TB трафик - от 350 руб/мес"
    echo
    echo "2. Рекомендации для NORMALDANCE:"
    echo "   - Минимальный: VPS-2 (2GB RAM) для разработки и тестирования"
    echo "   - Оптимальный: VPS-3 (2GB RAM, 2vCPU) для продакшена"
    echo "   - Для продакшена с высокой нагрузкой: VPS-4+ (4GB+ RAM)"
    echo
    echo "3. Дополнительные опции:"
    echo "   - Резервное копирование: +50 руб/мес"
    echo "   - Защита от DDoS: +100 руб/мес"
    echo "   - Дополнительный IP: +50 руб/мес"
    echo
    echo "4. Регионы:"
    echo "   - Москва (MSK) - низкая пинг"
    echo "   - Санкт-Петербург (SPB) - низкая пинг"
    echo "   - Финляндия (Helsinki) - для европейских пользователей"
    echo
    pause
}

demo_order_instructions() {
    log_info "Пошаговые инструкции по заказу VPS..."
    echo
    echo "=== ШАГИ ДЛЯ ЗАКАЗА VPS ==="
    echo
    echo "1. Регистрация на RUVDS: https://ruvds.com/"
    echo "2. Пополнение счета (минимум 300 руб)"
    echo "3. Заказ VPS с Ubuntu 22.04 LTS"
    echo "4. Выбор конфигурации: VPS-2 или VPS-3"
    echo "5. Настройка сети и firewall"
    echo "6. Оплата и ожидание активации (5-15 мин)"
    echo
    pause
}

demo_ssh_setup() {
    log_info "Настройка SSH ключей (демо)..."
    echo
    echo "=== НАСТРОЙКА SSH КЛЮЧЕЙ ==="
    echo
    echo "1. Генерация SSH ключей:"
    echo "   ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa_normaldance"
    echo
    echo "2. Публичный ключ для добавления в RUVDS:"
    echo "   ssh-rsa AAAAB3NzaC1yc2E... normaldance@$(hostname)"
    echo
    echo "3. SSH конфигурация:"
    echo "   Host normaldance-vps"
    echo "     HostName ВАШ_IP_АДРЕС"
    echo "     User normaldance"
    echo "     IdentityFile ~/.ssh/id_rsa_normaldance"
    echo
    pause
}

demo_system_setup() {
    log_info "Базовая настройка системы (демо)..."
    echo
    echo "=== БАЗОВАЯ НАСТРОЙКА СИСТЕМЫ ==="
    echo
    echo "1. Обновление системы:"
    echo "   apt update && apt upgrade -y"
    echo
    echo "2. Установка пакетов:"
    echo "   apt install curl wget git htop vim unzip net-tools"
    echo
    echo "3. Настройка swap (2GB):"
    echo "   fallocate -l 2G /swapfile"
    echo "   chmod 600 /swapfile"
    echo "   mkswap /swapfile"
    echo "   swapon /swapfile"
    echo
    echo "4. Настройка firewall:"
    echo "   ufw allow ssh http https"
    echo "   ufw --force enable"
    echo
    pause
}

demo_nodejs_nginx() {
    log_info "Установка Node.js и Nginx (демо)..."
    echo
    echo "=== УСТАНОВКА NODE.JS И NGINX ==="
    echo
    echo "1. Установка Node.js 18.x:"
    echo "   curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -"
    echo "   apt install -y nodejs"
    echo
    echo "2. Установка Nginx:"
    echo "   apt install -y nginx"
    echo
    echo "3. Настройка Nginx для NORMALDANCE:"
    echo "   - Проксирование /api на localhost:3000"
    echo "   - Проксирование /socket.io на WebSocket"
    echo "   - Статические файлы из /var/www/normaldance"
    echo
    echo "4. Тестовая страница создана:"
    echo "   /var/www/normaldance/index.html"
    echo
    pause
}

demo_create_user() {
    log_info "Создание пользователя normaldance (демо)..."
    echo
    echo "=== СОЗДАНИЕ ПОЛЬЗОВАТЕЛЯ normaldance ==="
    echo
    echo "1. Создание пользователя:"
    echo "   useradd -m -s /bin/bash normaldance"
    echo
    echo "2. Добавление в sudo группу:"
    echo "   usermod -aG sudo normaldance"
    echo
    echo "3. Настройка SSH доступа:"
    echo "   mkdir -p /home/normaldance/.ssh"
    echo "   cp ~/.ssh/id_rsa_normaldance.pub /home/normaldance/.ssh/authorized_keys"
    echo
    echo "4. Полезные алиасы в .bashrc:"
    echo "   - nd-start: запуск проекта"
    echo "   - nd-dev: режим разработки"
    echo "   - nd-build: сборка проекта"
    echo "   - nd-log: логи Nginx"
    echo
    pause
}

demo_disable_root() {
    log_info "Отключение root доступа по SSH (демо)..."
    echo
    echo "=== ОТКЛЮЧЕНИЕ ROOT ДОСТУPA ПО SSH ==="
    echo
    echo "1. Резервная копия конфигурации:"
    echo "   cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup"
    echo
    echo "2. Отключение root входа:"
    echo "   sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config"
    echo
    echo "3. Перезапуск SSH сервиса:"
    echo "   systemctl restart sshd"
    echo
    echo "4. ВАЖНО: Теперь подключайтесь как normaldance@"
    echo
    pause
}

demo_final_report() {
    log_info "Финальный отчет (демо)..."
    echo
    echo "=== ОТЧЕТ О НАСТРОЙКЕ ==="
    echo
    echo "✅ Система обновлена"
    echo "✅ Node.js 18.x установлен"
    echo "✅ Nginx настроен для NORMALDANCE"
    echo "✅ Пользователь normaldance создан"
    echo "✅ SSH ключи настроены"
    echo "✅ Root доступ отключен"
    echo "✅ Firewall активирован"
    echo "✅ Swap настроен (2GB)"
    echo "✅ Часовой пояс: Europe/Moscow"
    echo
    echo "Следующие шаги:"
    echo "1. Подключитесь: ssh normaldance@ВАШ_IP_АДРЕС"
    echo "2. Клонируйте проект: git clone https://github.com/normaldance/project.git"
    echo "3. Установите зависимости: cd project && npm install"
    echo "4. Запустите: npm start"
    echo "5. Настройте домен и SSL"
    echo
    log_success "Демонстрация завершена! Скрипт готов к использованию."
}

main() {
    echo "=============================================================================="
    echo "              ДЕМОНСТРАЦИЯ НАСТРОЙКИ VPS ДЛЯ NORMALDANCE"
    echo "=============================================================================="
    echo
    echo "Эта демонстрация показывает как будет работать скрипт"
    echo "без реальных изменений на системе."
    echo
    
    demo_research_tariffs
    demo_order_instructions
    demo_ssh_setup
    demo_system_setup
    demo_nodejs_nginx
    demo_create_user
    demo_disable_root
    demo_final_report
}

main "$@"