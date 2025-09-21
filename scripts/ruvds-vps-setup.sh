#!/bin/bash

# ==============================================================================
# Скрипт для заказа и настройки VPS на RUVDS для проекта NORMALDANCE
# ==============================================================================
# 
# Этот скрипт предоставляет пошаговые инструкции по:
# 1. Исследованию тарифов RUVDS
# 2. Заказу VPS сервера
# 3. Настройке SSH ключей
# 4. Базовой настройке системы
# 5. Установке Node.js и Nginx
# 6. Созданию пользователя normaldance
# 7. Отключению root доступа по SSH
#
# Автор: NORMALDANCE Team
# Версия: 1.0
# Дата: 2025-09-21
# ==============================================================================

set -e  # Выход при ошибке

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции для форматирования вывода
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

# Функция для паузы
pause() {
    read -p "Нажмите Enter для продолжения..."
}

# Функция для проверки прав root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Этот скрипт должен быть запущен от имени root пользователя"
        exit 1
    fi
}

# Функция для проверки интернет-соединения
check_connection() {
    if ! ping -c 1 ruvds.com &> /dev/null; then
        log_error "Нет интернет-соединения. Проверьте подключение."
        exit 1
    fi
    log_success "Интернет-соединение установлено"
}

# ==============================================================================
# ЧАСТЬ 1: ИССЛЕДОВАНИЕ ТАРИФОВ RUVDS
# ==============================================================================

research_tariffs() {
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

# ==============================================================================
# ЧАСТЬ 2: ПОШАГОВЫЕ ИНСТРУКЦИИ ПО ЗАКАЗУ VPS
# ==============================================================================

order_vps_instructions() {
    log_info "Пошаговые инструкции по заказу VPS на RUVDS..."
    echo
    echo "=== ШАГИ ДЛЯ ЗАКАЗА VPS ==="
    echo
    echo "Шаг 1: Регистрация на RUVDS"
    echo "1. Перейдите на сайт: https://ruvds.com/"
    echo "2. Нажмите 'Зарегистрироваться'"
    echo "3. Заполните форму регистрации:"
    echo "   - Email (используйте корпоративный)"
    echo "   - Пароль (надежный)"
    echo "   - Телефон"
    echo "   - Принятие условий"
    echo "4. Подтвердите email"
    echo
    echo "Шаг 2: Пополнение счета"
    echo "1. В личном кабинете перейдите 'Пополнение счета'"
    echo "2. Выберите удобный способ оплаты:"
    echo "   - Банковская карта"
    echo "   - Qiwi"
    echo "   - ЮMoney"
    echo "   - СберБанк Онлайн"
    echo "3. Минимальный пополнение: 300 руб"
    echo
    echo "Шаг 3: Заказ VPS"
    echo "1. В личном кабинете перейдите 'Услуги' -> 'VPS'"
    echo "2. Нажмите 'Создать VPS'"
    echo "3. Выберите конфигурацию:"
    echo "   - Операционная система: Ubuntu 22.04 LTS"
    echo "   - Регион: Москва или Санкт-Петербург"
    echo "   - Тариф: VPS-2 или VPS-3"
    echo "   - Дополнительные опции по желанию"
    echo "4. Настройте сеть:"
    echo "   - Включите IPv6 (рекомендуется)"
    echo "   - Настройте firewall (базовые правила)"
    echo "5. Подтвердите заказ"
    echo
    echo "Шаг 4: Оплата"
    echo "1. Проверьте стоимость заказа"
    echo "2. Выберите способ оплаты"
    echo "3. Подтвердите оплату"
    echo
    echo "Шаг 5: Ожидание активации"
    echo "1. VPS будет активирован в течение 5-15 минут"
    echo "2. Вы получите email с данныками доступа"
    echo "3. Запишите IP адрес и пароль root"
    echo
    pause
}

# ==============================================================================
# ЧАСТЬ 3: НАСТРОЙКА SSH КЛЮЧЕЙ
# ==============================================================================

setup_ssh_keys() {
    log_info "Настройка SSH ключей..."
    echo
    echo "=== НАСТРОЙКА SSH КЛЮЧЕЙ ==="
    echo
    
    # Проверка существующих SSH ключей
    if [[ -f ~/.ssh/id_rsa ]]; then
        log_warning "SSH ключ id_rsa уже существует"
        read -p "Хотите создать новый ключ? (y/n): " create_new
        if [[ $create_new == "y" ]]; then
            ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa_normaldance -C "normaldance@$(hostname)"
            log_success "Новый SSH ключ создан: ~/.ssh/id_rsa_normaldance"
        else
            cp ~/.ssh/id_rsa ~/.ssh/id_rsa_normaldance
            log_success "Существующий ключ скопирован"
        fi
    else
        ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa_normaldance -C "normaldance@$(hostname)"
        log_success "SSH ключ создан: ~/.ssh/id_rsa_normaldance"
    fi
    
    # Показать публичный ключ
    echo
    echo "=== ПУБЛИЧНЫЙ SSH КЛЮЧ ==="
    cat ~/.ssh/id_rsa_normaldance.pub
    echo
    echo "Скопируйте этот ключ и добавьте его в личном кабинете RUVDS:"
    echo "1. Войдите в личный кабинет RUVDS"
    echo "2. Перейдите 'Услуги' -> 'VPS' -> 'Ваш VPS'"
    echo "3. Перейдите 'SSH ключи'"
    echo "4. Нажмите 'Добавить ключ'"
    echo "5. Вставьте публичный ключ и сохраните"
    echo
    
    # Настройка SSH конфигурации
    cat >> ~/.ssh/config << EOF

# NORMALDANCE VPS
Host normaldance-vps
    HostName ВАШ_IP_АДРЕС
    User root
    Port 22
    IdentityFile ~/.ssh/id_rsa_normaldance
    StrictHostKeyChecking no
EOF
    
    log_success "SSH конфигурация обновлена"
    pause
}

# ==============================================================================
# ЧАСТЬ 4: БАЗОВАЯ НАСТРОЙКА СИСТЕМЫ
# ==============================================================================

setup_system() {
    log_info "Базовая настройка системы..."
    echo
    echo "=== БАЗОВАЯ НАСТРОЙКА СИСТЕМЫ ==="
    echo
    
    # Обновление системы
    log_info "Обновление системы..."
    apt update && apt upgrade -y
    log_success "Система обновлена"
    
    # Установка необходимых пакетов
    log_info "Установка необходимых пакетов..."
    apt install -y curl wget git htop vim unzip net-tools
    log_success "Пакеты установлены"
    
    # Настройка swap
    log_info "Настройка swap файла..."
    if ! swapon --show=NAME | grep -q /swapfile; then
        fallocate -l 2G /swapfile
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        
        # Добавление swap в fstab
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
        
        # Настройка swappiness
        sysctl vm.swappiness=10
        echo 'vm.swappiness=10' >> /etc/sysctl.conf
        
        log_success "Swap файл настроен (2GB)"
    else
        log_warning "Swap уже настроен"
    fi
    
    # Настройка часового пояса
    log_info "Настройка часового пояса..."
    timedatectl set-timezone Europe/Moscow
    log_success "Часовой пояс установлен: Europe/Moscow"
    
    # Настройка hostname
    log_info "Настройка hostname..."
    hostnamectl set-hostname normaldance-vps
    echo "127.0.0.1   normaldance-vps" >> /etc/hosts
    log_success "Hostname настроен"
    
    # Настройка firewall
    log_info "Настройка firewall..."
    ufw allow ssh
    ufw allow http
    ufw allow https
    ufw --force enable
    log_success "Firewall настроен"
    
    pause
}

# ==============================================================================
# ЧАСТЬ 5: УСТАНОВКА NODE.JS И NGINX
# ==============================================================================

install_nodejs_nginx() {
    log_info "Установка Node.js и Nginx..."
    echo
    echo "=== УСТАНОВКА NODE.JS И NGINX ==="
    echo
    
    # Установка Node.js
    log_info "Установка Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    apt install -y nodejs
    log_success "Node.js установлен"
    
    # Проверка версии
    node --version
    npm --version
    
    # Установка Nginx
    log_info "Установка Nginx..."
    apt install -y nginx
    log_success "Nginx установлен"
    
    # Настройка Nginx для NORMALDANCE
    log_info "Настройка Nginx..."
    cat > /etc/nginx/sites-available/normaldance << 'EOF'
server {
    listen 80;
    server_name _;
    
    root /var/www/normaldance;
    index index.html index.htm;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    location /api {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
    
    location /socket.io/ {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF
    
    # Создание символической ссылки
    ln -sf /etc/nginx/sites-available/normaldance /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # Создание директории для проекта
    mkdir -p /var/www/normaldance
    chown -R www-data:www-data /var/www/normaldance
    
    # Тестовая страница
    cat > /var/www/normaldance/index.html << 'EOF'
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>NORMALDANCE VPS</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        h1 { color: #333; }
        .status { color: #28a745; font-weight: bold; }
    </style>
</head>
<body>
    <h1>NORMALDANCE VPS Server</h1>
    <p class="status">✓ Сервер успешно настроен</p>
    <p>IP: $(hostname -I | awk '{print $1}')</p>
    <p>Дата: $(date)</p>
</body>
</html>
EOF
    
    # Перезапуск Nginx
    systemctl restart nginx
    systemctl enable nginx
    
    log_success "Nginx настроен для NORMALDANCE"
    pause
}

# ==============================================================================
# ЧАСТЬ 6: СОЗДАНИЕ ПОЛЬЗОВАТЕЛЯ normaldance
# ==============================================================================

create_user() {
    log_info "Создание пользователя normaldance..."
    echo
    echo "=== СОЗДАНИЕ ПОЛЬЗОВАТЕЛЯ normaldance ==="
    echo
    
    # Проверка существования пользователя
    if id "normaldance" &>/dev/null; then
        log_warning "Пользователь normaldance уже существует"
        read -p "Хотите пересоздать пользователя? (y/n): " recreate_user
        if [[ $recreate_user == "y" ]]; then
            userdel -r normaldance 2>/dev/null || true
        else
            log_success "Пользователь normaldance уже существует"
            pause
            return
        fi
    fi
    
    # Создание пользователя
    useradd -m -s /bin/bash normaldance
    log_success "Пользователь normaldance создан"
    
    # Установка пароля
    echo "Установка пароля для пользователя normaldance:"
    passwd normaldance
    
    # Добавление в sudo группу
    usermod -aG sudo normaldance
    log_success "Пользователь добавлен в sudo группу"
    
    # Настройка SSH для пользователя
    mkdir -p /home/normaldance/.ssh
    cp ~/.ssh/id_rsa_normaldance.pub /home/normaldance/.ssh/authorized_keys
    chown -R normaldance:normaldance /home/normaldance/.ssh
    chmod 700 /home/normaldance/.ssh
    chmod 600 /home/normaldance/.ssh/authorized_keys
    
    log_success "SSH доступ настроен для normaldance"
    
    # Настройка .bashrc
    cat >> /home/normaldance/.bashrc << 'EOF'
# NORMALDANCE aliases
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias gs='git status'
alias gp='git pull'
alias gc='git commit'
alias gl='git log'
alias gb='git branch'
alias gd='git diff'
alias gco='git checkout'

# Цветной вывод
export PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
export CLICOLOR=1
export LSCOLORS=ExFxBxDxCxegedabagacad

# Node.js aliases
alias npm-list='npm list --depth=0'
alias npm-global='npm list -g --depth=0'
alias npm-outdated='npm outdated'
alias npm-update='npm update'

# Nginx aliases
alias nginx-start='sudo systemctl start nginx'
alias nginx-stop='sudo systemctl stop nginx'
alias nginx-restart='sudo systemctl restart nginx'
alias nginx-status='sudo systemctl status nginx'
alias nginx-test='sudo nginx -t'

# Project aliases
alias nd-start='cd /var/www/normaldance && npm start'
alias nd-dev='cd /var/www/normaldance && npm run dev'
alias nd-build='cd /var/www/normaldance && npm run build'
alias nd-log='tail -f /var/log/nginx/normaldance.access.log'

EOF
    
    chown normaldance:normaldance /home/normaldance/.bashrc
    
    log_success "Настройка .bashrc завершена"
    pause
}

# ==============================================================================
# ЧАСТЬ 7: ОТКЛЮЧЕНИЕ ROOT ДОСТУПА ПО SSH
# ==============================================================================

disable_root_ssh() {
    log_info "Отключение root доступа по SSH..."
    echo
    echo "=== ОТКЛЮЧЕНИЕ ROOT ДОСТУПА ПО SSH ==="
    echo
    
    # Создание резервной копии конфигурации SSH
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    
    # Редактирование конфигурации SSH
    sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
    
    # Перезапуск SSH сервиса
    systemctl restart sshd
    
    log_success "Root доступ по SSH отключен"
    echo
    echo "ВАЖНО: Теперь для доступа к серверу используйте:"
    echo "ssh normaldance@ВАШ_IP_АДРЕС"
    echo
    pause
}

# ==============================================================================
# ЧАСТЬ 8: ФИНАЛЬНАЯ НАСТРОЙКА И ПРОВЕРКА
# ==============================================================================

final_setup() {
    log_info "Финальная настройка и проверка..."
    echo
    echo "=== ФИНАЛЬНАЯ НАСТРОЙКА И ПРОВЕРКА ==="
    echo
    
    # Проверка статуса сервисов
    echo "Проверка статуса сервисов:"
    systemctl status nginx --no-pager
    systemctl status sshd --no-pager
    systemctl status node --no-pager || echo "Node.js сервис не найден"
    
    # Проверка портов
    echo
    echo "Проверка открытых портов:"
    netstat -tlnp | grep -E '22|80|443|3000'
    
    # Проверка дискового пространства
    echo
    echo "Дисковое пространство:"
    df -h
    
    # Проверка памяти
    echo
    echo "Использование памяти:"
    free -h
    
    # Проверка IP адреса
    echo
    echo "IP адрес сервера:"
    hostname -I
    
    # Проверка времени
    echo
    echo "Текущее время:"
    date
    
    # Создание отчета
    echo
    echo "=== ОТЧЕТ О НАСТРОЙКЕ ==="
    echo "Дата настройки: $(date)"
    echo "IP адрес: $(hostname -I | awk '{print $1}')"
    echo "Операционная система: $(lsb_release -si) $(lsb_release -sr)"
    echo "Версия Node.js: $(node --version)"
    echo "Версия Nginx: $(nginx -v 2>&1 | awk '{print $3}')"
    echo "Пользователь: normaldance"
    echo "Root SSH: отключен"
    echo "Swap: 2GB"
    echo "Firewall: активирован"
    
    log_success "Настройка сервера завершена!"
    echo
    echo "Следующие шаги:"
    echo "1. Подключитесь к серверу: ssh normaldance@$(hostname -I | awk '{print $1}')"
    echo "2. Клонируйте репозиторий NORMALDANCE: git clone https://github.com/normaldance/project.git"
    echo "3. Установите зависимости: cd project && npm install"
    echo "4. Запустите проект: npm start"
    echo "5. Настройте доменное имя и SSL сертификат"
    echo
}

# ==============================================================================
# ГЛАВНАЯ ФУНКЦИЯ
# ==============================================================================

main() {
    log_info "Начало настройки VPS для NORMALDANCE"
    echo
    echo "=============================================================================="
    echo "              НАСТРОЙКА VPS ДЛЯ ПРОЕКТА NORMALDANCE"
    echo "=============================================================================="
    echo
    
    # Проверка прав root
    check_root
    
    # Проверка интернет-соединения
    check_connection
    
    # Выполнение всех шагов
    research_tariffs
    order_vps_instructions
    setup_ssh_keys
    setup_system
    install_nodejs_nginx
    create_user
    disable_root_ssh
    final_setup
    
    log_success "Все шаги настройки завершены!"
}

# Запуск главной функции
main "$@"