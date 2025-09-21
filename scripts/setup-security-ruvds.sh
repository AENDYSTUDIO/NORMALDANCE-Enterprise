
#!/bin/bash

# Скрипт для базовой настройки безопасности сервера на Ubuntu/Debian
# Автор: Roo AI Assistant
# Дата создания: 2025-09-21
# Версия: 2.0

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Переменные конфигурации
USERNAME="admin"
SSH_PORT="2222"
BACKUP_DIR="/root/security-backups"
LOG_DIR="/var/log/security"
SECURITY_REPORT="/root/security-report-$(date +%Y%m%d_%H%M%S).txt"
FAIL2BAN_JAIL="/etc/fail2ban/jail.local"
EMAIL_ADMIN="root"  # Email для уведомлений

# Функции для вывода сообщений
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

log_cyan() {
    echo -e "${CYAN}[NOTE]${NC} $1"
}

# Функция для проверки прав root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Этот скрипт должен быть запущен от имени root пользователя"
        log_info "Используйте: sudo ./setup-security-ruvds.sh"
        exit 1
    fi
}

# Функция проверки наличия необходимых пакетов
check_dependencies() {
    log_info "Проверка наличия необходимых пакетов..."
    
    local packages=("ufw" "fail2ban" "unattended-upgrades" "curl" "wget" "net-tools" "auditd")
    local missing_packages=()
    
    for package in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            missing_packages+=("$package")
        fi
    done
    
    if [[ ${#missing_packages[@]} -gt 0 ]]; then
        log_warning "Следующие пакеты отсутствуют: ${missing_packages[*]}"
        log_info "Установка отсутствующих пакетов..."
        apt-get update -qq
        apt-get install -y "${missing_packages[@]}"
        
        # Проверка успешной установки
        for package in "${missing_packages[@]}"; do
            if ! dpkg -l | grep -q "^ii  $package "; then
                log_error "Не удалось установить пакет: $package"
                return 1
            fi
        done
    fi
    
    log_success "Все необходимые пакеты установлены"
}

# Функция создания директорий
create_directories() {
    log_info "Создание необходимых директорий..."
    
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$LOG_DIR"
    mkdir -p "/root/.ssh"
    mkdir -p "/var/log/security"
    
    log_success "Директории созданы успешно"
}

# Функция резервного копирования конфигурационных файлов
backup_configs() {
    log_info "Создание резервных копий важных конфигурационных файлов..."
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/configs_backup_$timestamp.tar.gz"
    
    # Создаем архив с важными конфигурационными файлами
    local config_files=(
        "/etc/ssh/sshd_config"
        "/etc/fail2ban/jail.local"
        "/etc/fail2ban/jail.d"
        "/etc/ufw/before.rules"
        "/etc/ufw/before6.rules"
        "/etc/ufw/after.rules"
        "/etc/ufw/after6.rules"
        "/etc/ufw/applications.d"
        "/etc/unattended-upgrades"
        "/etc/apt/apt.conf.d/50unattended-upgrades"
        "/etc/audit/rules.d/audit.rules"
        "/etc/logrotate.d/security-logs"
        "/etc/sysctl.conf"
        "/etc/sysctl.d/"
    )
    
    # Фильтруем существующие файлы
    local existing_configs=()
    for config in "${config_files[@]}"; do
        if [[ -f "$config" ]] || [[ -d "$config" ]]; then
            existing_configs+=("$config")
        fi
    done
    
    if [[ ${#existing_configs[@]} -gt 0 ]]; then
        if tar -czf "$backup_file" -C "${existing_configs[0]%/*}" "${existing_configs[@]#*/}"; then
            log_success "Резервная копия конфигураций создана: $backup_file"
            echo "$backup_file" > "$BACKUP_DIR/latest_configs_backup.txt"
        else
            log_error "Не удалось создать резервную копию конфигураций"
            return 1
        fi
    else
        log_warning "Не найдено конфигурационных файлов для резервного копирования"
    fi
}

# Функция настройки UFW
setup_ufw() {
    log_info "Настройка UFW (Uncomplicated Firewall)..."
    
    # Сброс правил по умолчанию
    ufw --force reset
    
    # Установка политик по умолчанию
    ufw default deny incoming
    ufw default allow outgoing
    
    # Открытие необходимых портов
    ufw allow "$SSH_PORT"/tcp comment "SSH Custom Port"
    ufw allow 80/tcp comment "HTTP"
    ufw allow 443/tcp comment "HTTPS"
    
    # Дополнительные порты по необходимости
    ufw allow 22/tcp comment "SSH Default (для временного доступа)"
    
    # Включение UFW
    ufw --force enable
    
    if ufw status | grep -q "Status: active"; then
        log_success "UFW настроен и активирован"
        log_cyan "Открытые порты:"
        ufw status numbered | grep -E "^[0-9]+"
    else
        log_error "Не удалось активировать UFW"
        return 1
    fi
}

# Функция установки и настройки Fail2Ban
setup_fail2ban() {
    log_info "Установка и настройка Fail2Ban..."
    
    # Стартуем и включаем Fail2Ban
    systemctl start fail2ban
    systemctl enable fail2ban
    
    # Создаем конфигурацию Fail2Ban
    cat > "$FAIL2BAN_JAIL" << EOF
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5
banaction = ufw
backend = auto
destemail = $EMAIL_ADMIN
sender = fail2ban@$(hostname)
mta = sendmail

[sshd]
enabled = true
port = $SSH_PORT
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 24h
findtime = 15m

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
port = http,https
logpath = /var/log/nginx/error.log

[nginx-botsearch]
enabled = true
filter = nginx-botsearch
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 2

[apache-http-auth]
enabled = true
filter = apache-http-auth
port = http,https
logpath = /var/log/apache2/error.log
EOF

    # Перезапускаем Fail2Ban
    systemctl restart fail2ban
    
    if systemctl is-active --quiet fail2ban; then
        log_success "Fail2Ban настроен и запущен"
        log_cyan "Статус Fail2Ban:"
        fail2ban-client status
    else
        log_error "Не удалось запустить Fail2Ban"
        return 1
    fi
}

# Функция создания пользователя и отключения root
setup_user_ssh() {
    log_info "Настройка пользователей и SSH..."
    
    # Запрашиваем имя пользователя
    read -p "Введите имя нового пользователя (по умолчанию: $USERNAME): " input_username
    USERNAME="${input_username:-$USERNAME}"
    
    # Создаем пользователя
    if ! id "$USERNAME" &>/dev/null; then
        useradd -m -s /bin/bash "$USERNAME"
        log_success "Пользователь $USERNAME создан"
    else
        log_info "Пользователь $USERNAME уже существует"
    fi
    
    # Запрашиваем пароль для пользователя
    while true; do
        read -s -p "Введите пароль для пользователя $USERNAME: " password
        echo
        read -s -p "Повторите пароль: " password2
        echo
        
        if [[ "$password" == "$password2" && -n "$password" ]]; then
            echo "$USERNAME:$password" | chpasswd
            log_success "Пароль установлен для пользователя $USERNAME"
            break
        else
            log_error "Пароли не совпадают или пустые. Попробуйте снова."
        fi
    done
    
    # Добавляем пользователя в sudo группу
    usermod -aG sudo "$USERNAME"
    log_success "Пользователь $USERNAME добавлен в группу sudo"
    
    # Запрашиваем SSH ключ
    log_info "Настройка SSH ключей..."
    read -p "Введите ваш публичный SSH ключ (оставьте пустым для использования паролей): " ssh_key
    
    if [[ -n "$ssh_key" ]]; then
        # Создаем директорию .ssh для пользователя
        mkdir -p "/home/$USERNAME/.ssh"
        chmod 700 "/home/$USERNAME/.ssh"
        
        # Добавляем публичный ключ
        echo "$ssh_key" > "/home/$USERNAME/.ssh/authorized_keys"
        chmod 600 "/home/$USERNAME/.ssh/authorized_keys"
        chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.ssh"
        
        log_success "SSH ключ настроен для пользователя $USERNAME"
        USE_SSH_KEY=true
    else
        log_warning "SSH ключ не указан, будет использоваться парольная аутентификация"
        USE_SSH_KEY=false
    fi
}

# Функция настройки SSH
setup_ssh_config() {
    log_info "Настройка SSH сервера..."
    
    # Создаем резервную копию текущей конфигурации SSH
    cp /etc/ssh/sshd_config "$BACKUP_DIR/sshd_config.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Настраиваем SSH
    cat > /etc/ssh/sshd_config << EOF
# Отключаем вход для root пользователя
PermitRootLogin no

# Используем кастомный порт
Port $SSH_PORT

# Запрещаем парольную аутентификацию, если указан SSH ключ
PasswordAuthentication $([[ "$USE_SSH_KEY" == true ]] && echo "no" || echo "yes")

# Разрешаем аутентификацию по ключу
PubkeyAuthentication $([[ "$USE_SSH_KEY" == true ]] && echo "yes" || echo "yes")

# Запрещаем пустые пароли
PermitEmptyPasswords no

# Ограничиваем доступ к SSH
AllowUsers $USERNAME

# Настройки безопасности
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_dsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Отключаем X11 forwarding
X11Forwarding no

# Ограничиваем количество попыток аутентификации
MaxAuthTries 3

# Таймаут аутентификации
LoginGraceTime 60

# Запрещаем TCP forwarding
AllowTcpForwarding no
GatewayPorts no

# Запрещаем agent forwarding
PermitTunnel no

# Запрещаем использование rhosts
IgnoreRhosts yes
HostbasedAuthentication no

# Запрещаем доступ для пользователей без пароля
DenyUsers *
AllowUsers $USERNAME

# Устанавливаем уровень отладки
LogLevel INFO
EOF

    # Перезапускаем SSH
    systemctl restart sshd
    
    if systemctl is-active --quiet sshd; then
        log_success "SSH сервер настроен успешно"
        log_warning "Внимание! SSH доступ изменен на порт $SSH_PORT"
        log_info "Используйте: ssh -p $SSH_PORT $USERNAME@ваш_сервер"
    else
        log_error "Не удалось перезапустить SSH сервер"
        return 1
    fi
}

# Функция настройки автоматического обновления
setup_automatic_updates() {
    log_info "Настройка автоматического обновления системы..."
    
    # Устанавливаем unattended-upgrades
    apt-get install -y unattended-upgrades
    
    # Создаем конфигурацию для автоматических обновлений
    cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
// Автоматическое обновление пакетов
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}:${distro_codename}-updates";
    "${distro_id}:${distro_codename}-proposed";
    "${distro_id}:${distro_codename}-backports";
};

// Настройки обновления
Unattended-Upgrade::Package-Blacklist {
    // Исключить пакеты из обновления, если необходимо
    // "package-name";
};

// Автоматическая очистка старых пакетов
Unattended-Upgrade::AutoCleanInterval "7";

// Включаем автоматическое исправление уязвимостей
Unattended-Upgrade::MinimalUpgrade "true";

// Логирование
Unattended-Upgrade::Verbose "2";

// Отключаем перезагрузку автоматически
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";

// Включаем автоматическое обновление безопасности
Unattended-Upgrade::Automatic-Reboot-WithUsers "false";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
EOF

    # Включаем автоматические обновления
    cat > /etc/apt/apt.conf.d/02periodic << 'EOF'
APT::Periodic::Enable "1";
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Verbose "1";
EOF

    # Перезапускаем сервис
    systemctl restart unattended-upgrades
    
    log_success "Автоматическое обновление системы настроено"
}

# Функция настройки sysctl для повышения безопасности
setup_sysctl() {
    log_info "Настройка sysctl для повышения безопасности..."
    
    # Создаем резервную копию текущего конфига
    cp /etc/sysctl.conf "$BACKUP_DIR/sysctl.conf.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Добавляем настройки безопасности
    cat >> /etc/sysctl.conf << EOF

# Настройки безопасности ядра
# Защита от SYN атак
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.tcp_synack_retries = 2

# Защита от IP spoofing
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Отключаем ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0

# Защита от DoS атак
net.ipv4.tcp_max_tw_buckets = 1440000
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 15

# Отключаем IPv6 если не используется
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1

# Ограничиваем доступ к ядру
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 1

# Защита от атак с использованием core dumps
fs.suid_dumpable = 0

# Ограничение размера core dump'ов
* soft core 0
* hard core 0

# Защита от brute force атак
sysctl net.ipv4.conf.all.log_martians = 1
EOF

    # Применяем настройки
    sysctl -p
    
    log_success "Настройки sysctl применены"
}

# Функция настройки логирования безопасности
setup_security_logging() {
    log_info "Настройка логирования безопасности..."
    
    # Настраиваем аудит логи
    cat > /etc/audit/rules.d/audit.rules << 'EOF'
# Логирование всех failed login attempts
-w /var/log/auth.log -p wa -k auth
-w /var/log/secure -p wa -k auth

# Логирование изменений в конфигурационных файлах
-w /etc/ssh/sshd_config -p wa -k ssh_config
-w /etc/fail2ban/jail.local -p wa -k fail2ban_config
-w /etc/ufw/before.rules -p wa -k ufw_config
-w /etc/sysctl.conf -p wa -k sysctl_config

# Логирование использования sudo
-w /var/log/auth.log -p wa -k sudo_usage
-w /var/log/secure -p wa -k sudo_usage

# Логирование изменений в системных файлах
-w /etc/passwd -p wa -k passwd
-w /etc/group -p wa -k group
-w /etc/shadow -p wa -k shadow
-w /etc/gshadow -p wa -k gshadow

# Логирование сетевых настроек
-w /etc/network/ -p wa -k network
-w /etc/sysconfig/network-scripts/ -p wa -k network

# Логирование процессов
-a exit,always -F arch=b64 -S execve -k exec
-a exit,always -F arch=b32 -S execve -k exec

# Логирование модулей ядра
-w /sbin/insmod -p x -k modules
-w /sbin/rmmod -p x -k modules
-w /sbin/modprobe -p x -k modules

# Логирование событий времени
-a always,exit -F arch=b64 -S clock_settime -k time_change
-a always,exit -F arch=b32 -S clock_settime -k time_change
-a always,exit -F arch=b64 -S settimeofday -k time_change
-a always,exit -F arch=b32 -S settimeofday -k time_change
-a always,exit -F arch=b64 -S stime -k time_change
-a always,exit -F arch=b32 -S stime -k time_change
EOF

    # Перезапускаем auditd
    systemctl restart auditd
    systemctl enable auditd
    
    # Настраиваем лог ротацию для security логов
    cat > /etc/logrotate.d/security-logs << 'EOF'
/var/log/security/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 root root
    postrotate
        systemctl restart auditd >/dev/null 2>&1 || true
    endscript
}

/var/log/auth.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 root root
    sharedscripts
    postrotate
        systemctl restart sshd >/dev/null 2>&1 || true
    endscript
}
EOF

    log_success "Логирование безопасности настроено"
}

# Функция настройки email уведомлений
setup_email_notifications() {
    log_info "Настройка email уведомлений..."
    
    # Устанавливаем mailutils для отправки email
    apt-get install -y mailutils
    
    # Настраиваем cron для отправки отчетов
    cat > /etc/cron.daily/security-report << 'EOF'
#!/bin/bash

# Отправка ежедневного отчета о безопасности
SECURITY_LOG="/var/log/security/daily-$(date +%Y%m%d).log"
AUTH_LOG="/var/log/auth.log"

# Создаем отчет
echo "Ежедневный отчет о безопасности - $(date)" > "$SECURITY_LOG"
echo "" >> "$SECURITY_LOG"
echo "=== Последние входы в систему ===" >> "$SECURITY_LOG"
last -n 10 >> "$SECURITY_LOG"
echo "" >> "$SECURITY_LOG"
echo "=== Последние ошибки аутентификации ===" >> "$SECURITY_LOG"
grep "Failed password" "$AUTH_LOG" | tail -n 5 >> "$SECURITY_LOG" || echo "Не найдено" >> "$SECURITY_LOG"
echo "" >> "$SECURITY_LOG"
echo "=== Статус системы ===" >> "$SECURITY_LOG"
uptime >> "$SECURITY_LOG"
df -h >> "$SECURITY_LOG"
echo "" >> "$SECURITY_LOG"
echo "=== Открытые порты ===" >> "$SECURITY_LOG"
ss -tulnp | grep LISTEN | awk '{print $4}' | cut -d: -f2 | sort -u >> "$SECURITY_LOG"

# Отправляем email
if command -v mail &> /dev/null; then
    mail -s "Ежедневный отчет о безопасности - $(hostname)" root < "$SECURITY_LOG"
fi

# Удаляем старые логи (более 30 дней)
find /var/log/security -name "*.log" -mtime +30 -delete
EOF

    chmod +x /etc/cron.daily/security-report
    
    log_success "Email уведомления настроены"
}

# Функция проверки безопасности
security_check() {
    log_info "Проверка безопасности системы..."
    
    local issues=0
    
    # Проверка UFW
    if ! ufw status | grep -q "Status: active"; then
        log_error "UFW не активен"
        ((issues++))
    else
        log_success "UFW активен"
    fi
    
    # Проверка Fail2Ban
    if ! systemctl is-active --quiet fail2ban; then
        log_error "Fail2Ban не запущен"
        ((issues++))
    else
        log_success "Fail2Ban активен"
    fi
    
    # Проверка SSH конфигурации
    if grep -q "PermitRootLogin yes" /etc/ssh/sshd_config; then
        log_error "Root доступ по SSH разрешен"
        ((issues++))
    else
        log_success "Root доступ по SSH отключен"
    fi
    
    # Проверка паролей в SSH ключах
    if [[ "$USE_SSH_KEY" == true ]] && grep -q "PasswordAuthentication yes" /etc/ssh/sshd_config; then
        log_warning "Парольная аутентификация включена, хотя SSH ключ настроен"
        log_info "Рекомендуется отключить парольную аутентификацию"
        ((issues++))
    fi
    
    # Проверка открытых портов
    local open_ports=$(ss -tulnp | grep LISTEN | awk '{print $5}' | cut -d: -f2 | sort -u)
    log_cyan "Открытые порты: $open_ports"
    
    # Проверка обновлений системы
    if apt list --upgradable 2>/dev/null | grep -q "upgradable"; then
        log_warning "Доступны обновления системы"
        log_info "Запустите: apt upgrade -y"
        ((issues++))
    else
        log_success "Система обновлена"
    fi
    
    # Проверка auditd
    if ! systemctl is-active --quiet auditd; then
        log_error "auditd не запущен"
        ((issues++))
    else
        log_success "auditd активен"
    fi
    
    # Проверка sysctl настроек
    if ! sysctl net.ipv4.tcp_syncookies | grep -q "1"; then
        log_warning "Настройки безопасности sysctl не применены"
        ((issues++))
    else
        log_success "Настройки безопасности sysctl применены"
    fi
    
    if [[ $issues -eq 0 ]]; then
        log_success "Проверка безопасности пройдена, критических проблем не обнаружено"
    else
        log_warning "Обнаружено $issues потенциальных проблем безопасности"
    fi
    
    return $issues
}

# Функция создания отчета о безопасности
create_security_report() {
    log_info "Создание отчета о безопасности..."
    
    local ip_address=$(curl -s ifconfig.me 2>/dev/null || echo "Не определен")
    local os_info=$(lsb_release -sd 2>/dev/null || echo "Не определена")
    
    cat > "$SECURITY_REPORT" << EOF
Отчет о безопасности сервера
===========================
Дата создания: $(date)
Сервер: $(hostname)
IP адрес: $ip_address
ОС: $os_info
Ядро: $(uname -r)
Время работы: $(uptime -p)

Системная информация:
- Хостнейм: $(hostname)
- Домен: $(domainname 2>/dev/null || echo "Не определен")
- Архитектура: $(uname -m)
- Нагрузка: $(uptime | awk -F'load average:' '{ print $2 }')
- Доступная память: $(free -h | grep Mem | awk '{print $3 "/" $2}')
- Диск: $(df -h / | tail -1 | awk '{print $3 "/" $2 " (" $5 ")"}')

Настройки безопасности:
- UFW статус: $(ufw status | grep "Status" || echo "Не активен")
- Fail2Ban статус: $(systemctl is-active fail2ban 2>/dev/null || echo "Не активен")
- SSH порт: $(grep "^Port" /etc/ssh/sshd_config | awk '{print $2}' || echo "22")
- Root доступ: $(grep "^PermitRootLogin" /etc/ssh/sshd_config | awk '{print $2}' || echo "разрешен")
- SSH ключи: $([[ "$USE_SSH_KEY" == true ]] && echo "включены" || echo "не настроены")
- Пароли: $([[ "$USE_SSH_KEY" == true ]] && echo "отключены" || echo "разрешены")

Открытые порты:
$(ss -tulnp | grep LISTEN | awk '{print $4}' | cut -d: -f2 | sort -u | xargs -I {} echo "- {}")

Пользователи системы:
$(cut -d: -f1 /etc/passwd | grep -vE "^(nobody|systemd-|messagebus|syslog|sshd|ftp|mail|root)" | sort)

Последние входы в систему:
$(last -n 10 | head -n 10)

Последние ошибки аутентификации:
$(grep "Failed password" /var/log/auth.log | tail -n 5 || echo "Не найдено")

Сетевые интерфейсы:
$(ip addr show | grep -E "^[0-9]+:" | awk '{print $2}' | tr -d ':')

Рекомендации:
1. Регулярно проверяйте логи безопасности: tail -f /var/log/auth.log
2. Обновляйте систему регулярно: apt update && apt upgrade -y
3. Мониторьте активные соединения: ss -tulnp
4. Проверяйте права пользователей: ls -la /home
5. Используйте сложные пароли и SSH ключи
6. Регулярно создавайте резервные копии важных данных
7. Мониторьте использование диска: df -h
8. Проверяйте логи Fail2Ban: fail2ban-client status
9. Обновляйте пароли пользователей регулярно
10. Ограничьте доступ к серверу только доверенным IP

Контакты для поддержки:
- Email: $EMAIL_ADMIN
- Логи безопасности: /var/log/security/
- Резервные копии: $BACKUP_DIR
EOF

    log_success "Отчет о безопасности создан: $SECURITY_REPORT"
    
    # Отправляем email с отчетом
    if command -v mail &> /dev/null; then
        mail -s "Отчет о безопасности - $(hostname)" "$EMAIL_ADMIN" < "$SECURITY_REPORT"
        log_success "Отчет отправлен на email: $EMAIL_ADMIN"
    fi
}

# Функция очистки
cleanup() {
    log_info "Очистка временных файлов..."
    
    # Удаляем временные файлы
    rm -f /tmp/security*.log
    rm -f /tmp/fail2ban*.log
    rm -f /tmp/sysctl*.log
    
    log_success "Очистка завершена"
}

# Функция справки
show_help() {
    echo "Использование: sudo ./setup-security-ruvds.sh [опции]"
    echo ""
    echo "Опции:"
    echo "  --help              Показать эту справку"
    echo "  --check             Проверить текущий статус безопасности"
    echo "  --report            Создать отчет о безопасности"
    echo "  --ufw-only          Только настройка UFW"
    echo "  --ssh-only          Только настройка SSH"
    echo "  --fail2ban-only     Только настройка Fail2Ban"
    echo "  --auto-updates-only Только настройка автоматических обновлений"
    echo "  --sysctl-only       Только настройка sysctl"
    echo "  --email-only        Только настройка email уведомлений"
    echo ""
    echo "Примеры:"
    echo "  sudo ./setup-security-ruvds.sh              # Полная настройка безопасности"
    echo "  sudo ./setup-security-ruvds.sh --check     # Проверить безопасность"
    echo "  sudo ./setup-security-ruvds.sh --report    # Создать отчет"
}

# Функция проверки безопасности
check_security_status() {
    log_info "Проверка текущего статуса безопасности..."
    
    echo "=== Текущий статус безопасности ==="
    echo ""
    
    # UFW статус
    echo "UFW Firewall:"
    ufw status 2>/dev/null || echo "UFW не установлен или не активен"
    echo ""
    
    # Fail2Ban статус
    echo "Fail2Ban:"
    systemctl is-active --quiet fail2ban && echo "Активен" || echo "Не активен"
    if command -v fail2ban-client &> /dev/null; then
        fail2ban-client status 2>/dev/null || echo "Не удалось получить статус Fail2Ban"
    fi
    echo ""
    
    # SSH статус
    echo "SSH конфигурация:"
    grep -E "^Port|^PermitRootLogin|^PasswordAuthentication" /etc/ssh/sshd_config 2>/dev/null || echo "Не удалось прочитать SSH конфигурацию"
    echo ""
    
    # Обновления системы
    echo "Обновления системы:"
    if apt list --upgradable 2>/dev/null | grep -q "upgradable"; then
        echo "Доступны обновления"
    else
        echo "Система обновлена"
    fi
    echo ""
    
    # Открытые порты
    echo "Открытые порты:"
    ss -tulnp | grep LISTEN | awk '{print $4}' | cut -d: -f2 | sort -u | xargs -I {} echo "- {}"
    echo ""
    
    # Auditd статус
    echo "Auditd:"
    systemctl is-active --quiet auditd && echo "Активен" || echo "Не активен"
    echo ""
    
    # Sysctl настройки
    echo "Настройки безопасности sysctl:"
    sysctl net.ipv4.tcp_syncookies 2>/dev/null || echo "Не применены"
    echo ""
    
   
    log_success "Проверка статуса безопасности завершена"
}

# Функция основной установки
main() {
    log_info "Начало базовой настройки безопасности сервера"
    log_info "================================================"
    
    # Проверяем права root
    check_root
    
    # Обработка аргументов командной строки
    case "${1:-}" in
        --help)
            show_help
            exit 0
            ;;
        --check)
            check_security_status
            exit 0
            ;;
        --report)
            create_security_report
            exit 0
            ;;
        --ufw-only)
            setup_ufw
            exit 0
            ;;
        --ssh-only)
            setup_user_ssh
            setup_ssh_config
            exit 0
            ;;
        --fail2ban-only)
            setup_fail2ban
            exit 0
            ;;
        --auto-updates-only)
            setup_automatic_updates
            exit 0
            ;;
        --sysctl-only)
            setup_sysctl
            exit 0
            ;;
        --email-only)
            setup_email_notifications
            exit 0
            ;;
    esac
    
    # Проверяем зависимости
    check_dependencies
    
    # Создаем необходимые директории
    create_directories
    
    # Создаем резервные копии
    backup_configs
    
    # Настраиваем UFW
    setup_ufw
    
    # Устанавливаем и настраиваем Fail2Ban
    setup_fail2ban
    
    # Настраиваем пользователей и SSH
    setup_user_ssh
    setup_ssh_config
    
    # Настраиваем автоматические обновления
    setup_automatic_updates
    
    # Настраиваем sysctl для повышения безопасности
    setup_sysctl
    
    # Настраиваем логирование
    setup_security_logging
    
    # Настраиваем email уведомления
    setup_email_notifications
    
    # Проверяем безопасность
    security_check
    
    # Создаем отчет
    create_security_report
    
    # Очищаем временные файлы
    cleanup
    
    log_info "================================================"
    log_success "Настройка безопасности сервера завершена успешно!"
    log_cyan "Важная информация:"
    log_cyan "- SSH доступ изменен на порт: $SSH_PORT"
    log_cyan "- Пользователь для доступа: $USERNAME"
    log_cyan "- Отчет о безопасности: $SECURITY_REPORT"
    log_cyan "- Резервные копии: $BACKUP_DIR"
    log_cyan "- Email уведомления: $EMAIL_ADMIN"
    
    # Предупреждение о перезагрузке
    log_warning "Для применения некоторых изменений может потребоваться перезагрузка сервера"
    read -p "Перезагрузить сервер сейчас? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Перезагрузка сервера..."
        reboot
    fi
}

# Запуск основной функции
main "$@"
