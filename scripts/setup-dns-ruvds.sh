#!/bin/bash

# Скрипт для настройки DNS записей домена normaldance.ru через панель управления RUVDS
# Автор: Roo AI Assistant
# Дата: 2025-09-21

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Конфигурация
DOMAIN="normaldance.ru"
WWW_DOMAIN="www.normaldance.ru"
BACKUP_FILE="dns-backup-$(date +%Y%m%d-%H%M%S).txt"
LOG_FILE="dns-setup-$(date +%Y%m%d-%H%M%S).log"

# Переменные для IP адресов
SERVER_IP=""
SERVER_IPV6=""
REGISTRAR=""

# Функция логирования
log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

# Функция проверки прав
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log "${RED}[ОШИБКА] Этот скрипт должен быть запущен с правами root${NC}"
        exit 1
    fi
}

# Функция проверки зависимостей
check_dependencies() {
    log "${BLUE}[ИНФОРМАЦИЯ] Проверка зависимостей...${NC}"
    
    local missing_deps=()
    
    # Проверка необходимых утилит
    for cmd in dig nslookup whois curl; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log "${YELLOW}[ПРЕДУПРЕЖДЕНИЕ] Отсутствуют следующие утилиты: ${missing_deps[*]}${NC}"
        log "${YELLOW}[ПРЕДУПРЕЖДЕНИЕ] Некоторые функции могут работать некорректно${NC}"
    else
        log "${GREEN}[ОК] Все необходимые утилиты установлены${NC}"
    fi
}

# Функция автоматического определения регистратора домена
detect_registrar() {
    log "${BLUE}[ИНФОРМАЦИЯ] Определение регистратора домена $DOMAIN...${NC}"
    
    local registrar_info
    registrar_info=$(whois "$DOMAIN" 2>/dev/null | grep -i "registrar\|registrar:")
    
    if [[ $registrar_info =~ "registrar:" ]]; then
        REGISTRAR=$(echo "$registrar_info" | sed 's/.*registrar:[[:space:]]*//i' | head -1)
    elif [[ $registrar_info =~ "Registrar:" ]]; then
        REGISTRAR=$(echo "$registrar_info" | sed 's/.*Registrar:[[:space:]]*//i' | head -1)
    else
        REGISTRAR="Не определен"
    fi
    
    # Очистка от лишних символов
    REGISTRAR=$(echo "$REGISTRAR" | sed 's/[[:space:]]*$//' | sed 's/^.*://')
    
    log "${GREEN}[ОК] Определен регистратор: $REGISTRAR${NC}"
    
    # Определение панели управления на основе регистратора
    case "$REGISTRAR" in
        *reg.ru*|*REG.RU*)
            REGISTRAR_PANEL="reg.ru"
            ;;
        *nic.ru*|*NIC.RU*)
            REGISTRAR_PANEL="nic.ru"
            ;;
        *cloudflare*|*CLOUDFLARE*)
            REGISTRAR_PANEL="cloudflare"
            ;;
        *ruvds*|*RUVDS*)
            REGISTRAR_PANEL="ruvds"
            ;;
        *)
            REGISTRAR_PANEL="other"
            ;;
    esac
    
    log "${GREEN}[ОК] Панель управления: $REGISTRAR_PANEL${NC}"
}

# Функция получения IP адреса сервера
get_server_ip() {
    log "${BLUE}[ИНФОРМАЦИЯ] Определение IP адреса сервера...${NC}"
    
    # Получение IPv4
    SERVER_IP=$(curl -s4 https://api.ipify.io 2>/dev/null)
    if [ -z "$SERVER_IP" ]; then
        SERVER_IP=$(hostname -I | awk '{print $1}')
    fi
    
    # Получение IPv6
    SERVER_IPV6=$(curl -s6 https://api6.ipify.io 2>/dev/null)
    
    if [ -n "$SERVER_IP" ]; then
        log "${GREEN}[ОК] IPv4 адрес сервера: $SERVER_IP${NC}"
    else
        log "${RED}[ОШИБКА] Не удалось определить IPv4 адрес${NC}"
        return 1
    fi
    
    if [ -n "$SERVER_IPV6" ]; then
        log "${GREEN}[ОК] IPv6 адрес сервера: $SERVER_IPV6${NC}"
    else
        log "${YELLOW}[ПРЕДУПРЕЖДЕНИЕ] IPv6 адрес не определен${NC}"
    fi
}

# Функция создания резервной копии текущих DNS записей
backup_dns_records() {
    log "${BLUE}[ИНФОРМАЦИЯ] Создание резервной копии DNS записей...${NC}"
    
    {
        echo "=== Резервная копия DNS записей для $DOMAIN ==="
        echo "Дата создания: $(date)"
        echo "Регистратор: $REGISTRAR"
        echo ""
        echo "=== Текущие DNS записи ==="
        dig "$DOMAIN" ANY +short
        echo ""
        echo "=== NS записи ==="
        dig "$DOMAIN" NS +short
        echo ""
        echo "=== A записи ==="
        dig "$DOMAIN" A +short
        echo ""
        echo "=== AAAA записи ==="
        dig "$DOMAIN" AAAA +short 2>/dev/null || echo "AAAA записи не найдены"
        echo ""
        echo "=== WWW A записи ==="
        dig "$WWW_DOMAIN" A +short 2>/dev/null || echo "WWW A записи не найдены"
        echo ""
        echo "=== WWW AAAA записи ==="
        dig "$WWW_DOMAIN" AAAA +short 2>/dev/null || echo "WWW AAAA записи не найдены"
        echo ""
        echo "=== MX записи ==="
        dig "$DOMAIN" MX +short
        echo ""
        echo "=== TXT записи ==="
        dig "$DOMAIN" TXT +short
    } > "$BACKUP_FILE"
    
    log "${GREEN}[ОК] Резервная копия сохранена в файл: $BACKUP_FILE${NC}"
}

# Функция проверки текущих DNS записей
check_current_dns() {
    log "${BLUE}[ИНФОРМАЦИЯ] Проверка текущих DNS записей...${NC}"
    
    local ns_records
    ns_records=$(dig "$DOMAIN" NS +short | tr '\n' ' ')
    log "${GREEN}[ОК] NS записи: $ns_records${NC}"
    
    local a_records
    a_records=$(dig "$DOMAIN" A +short | tr '\n' ' ')
    log "${GREEN}[ОК] A записи: $a_records${NC}"
    
    local aaaa_records
    aaaa_records=$(dig "$DOMAIN" AAAA +short 2>/dev/null | tr '\n' ' ')
    if [ -n "$aaaa_records" ]; then
        log "${GREEN}[ОК] AAAA записи: $aaaa_records${NC}"
    else
        log "${YELLOW}[ПРЕДУПРЕЖДЕНИЕ] AAAA записи не найдены${NC}"
    fi
    
    local www_a_records
    www_a_records=$(dig "$WWW_DOMAIN" A +short 2>/dev/null | tr '\n' ' ')
    if [ -n "$www_a_records" ]; then
        log "${GREEN}[ОК] WWW A записи: $www_a_records${NC}"
    else
        log "${YELLOW}[ПРЕДУПРЕЖДЕНИЕ] WWW A записи не найдены${NC}"
    fi
}

# Функция пошаговых инструкций для настройки DNS в RUVDS
show_ruvs_instructions() {
    log "${BLUE}[ИНФОРМАЦИЯ] Пошаговые инструкции по настройке DNS в панели RUVDS${NC}"
    log "${YELLOW}=========================================${NC}"
    log "${YELLOW}   ИНСТРУКЦИЯ ДЛЯ НАСТРОЙКИ DNS В RUVDS   ${NC}"
    log "${YELLOW}=========================================${NC}"
    echo ""
    
    log "${GREEN}Шаг 1: Вход в панель управления RUVDS${NC}"
    log "1. Перейдите на сайт https://cp.ruvds.com/"
    log "2. Введите ваш логин и пароль"
    log "3. Нажмите 'Войти'"
    echo ""
    
    log "${GREEN}Шаг 2: Переход в раздел управления DNS${NC}"
    log "1. В левом меню найдите раздел 'Домены' или 'DNS'"
    log "2. Выберите 'Управление DNS' или 'DNS-записи'"
    log "3. Если у вас несколько доменов, выберите $DOMAIN"
    echo ""
    
    log "${GREEN}Шаг 3: Настройка A-записи для основного домена${NC}"
    log "1. Нажмите 'Добавить запись' или 'Создать запись'"
    log "2. В поле 'Тип' выберите 'A'"
    log "3. В поле 'Имя' оставьте пустым (или @ для основного домена)"
    log "4. В поле 'Значение' введите: $SERVER_IP"
    log "5. В поле 'TTL' оставьте значение по умолчанию (обычно 3600)"
    log "6. Нажмите 'Сохранить'"
    echo ""
    
    log "${GREEN}Шаг 4: Настройка A-записи для www поддомена${NC}"
    log "1. Нажмите 'Добавить запись' или 'Создать запись'"
    log "2. В поле 'Тип' выберите 'A'"
    log "3. В поле 'Имя' введите: www"
    log "4. В поле 'Значение' введите: $SERVER_IP"
    log "5. В поле 'TTL' оставьте значение по умолчанию"
    log "6. Нажмите 'Сохранить'"
    echo ""
    
    if [ -n "$SERVER_IPV6" ]; then
        log "${GREEN}Шаг 5: Настройка AAAA-записи (IPv6)${NC}"
        log "1. Нажмите 'Добавить запись' или 'Создать запись'"
        log "2. В поле 'Тип' выберите 'AAAA'"
        log "3. В поле 'Имя' оставьте пустым (или @ для основного домена)"
        log "4. В поле 'Значение' введите: $SERVER_IPV6"
        log "5. В поле 'TTL' оставьте значение по умолчанию"
        log "6. Нажмите 'Сохранить'"
        echo ""
        
        log "${GREEN}Шаг 6: Настройка AAAA-записи для www поддомена${NC}"
        log "1. Нажмите 'Добавить запись' или 'Создать запись'"
        log "2. В поле 'Тип' выберите 'AAAA'"
        log "3. В поле 'Имя' введите: www"
        log "4. В поле 'Значение' введите: $SERVER_IPV6"
        log "5. В поле 'TTL' оставьте значение по умолчанию"
        log "6. Нажмите 'Сохранить'"
        echo ""
    fi
    
    log "${GREEN}Шаг 7: Настройка CNAME записи для www (альтернативный способ)${NC}"
    log "Примечание: Если вы уже настроили A-запись для www, этот шаг можно пропустить"
    log "1. Нажмите 'Добавить запись' или 'Создать запись'"
    log "2. В поле 'Тип' выберите 'CNAME'"
    log "3. В поле 'Имя' введите: www"
    log "4. В поле 'Значение' введите: $DOMAIN"
    log "5. В поле 'TTL' оставьте значение по умолчанию"
    log "6. Нажмите 'Сохранить'"
    echo ""
    
    log "${GREEN}Шаг 8: Проверка и сохранение${NC}"
    log "1. Убедитесь, что все записи добавлены корректно"
    log "2. Проверьте, что нет дублирующихся записей"
    log "3. Нажмите 'Сохранить' или 'Применить изменения'"
    log "4. Дождитесь применения изменений (обычно 15-60 минут)"
    echo ""
    
    log "${YELLOW}ВНИМАНИЕ!${NC}"
    log "DNS изменения могут распространяться по всему миру от 15 минут до 48 часов."
    log "Рекомендуется проверить DNS записи через 15-30 минут после сохранения."
    echo ""
}

# Функция проверки DNS записей после настройки
verify_dns_setup() {
    log "${BLUE}[ИНФОРМАЦИЯ] Проверка DNS записей после настройки...${NC}"
    
    local max_attempts=30
    local attempt=1
    local domain_resolved=false
    
    while [ $attempt -le $max_attempts ]; do
        log "${YELLOW}[ПОПЫТКА $attempt/$max_attempts] Проверка DNS записей...${NC}"
        
        # Проверка A записи основного домена
        local current_a_ip
        current_a_ip=$(dig "$DOMAIN" A +short | head -1)
        if [ "$current_a_ip" = "$SERVER_IP" ]; then
            log "${GREEN}[ОК] A запись для $DOMAIN корректна: $SERVER_IP${NC}"
            domain_resolved=true
        else
            log "${RED}[ОШИБКА] A запись для $DOMAIN некорректна. Ожидался: $SERVER_IP, Получен: $current_a_ip${NC}"
        fi
        
        # Проверка A записи www
        local current_www_ip
        current_www_ip=$(dig "$WWW_DOMAIN" A +short | head -1)
        if [ "$current_www_ip" = "$SERVER_IP" ]; then
            log "${GREEN}[ОК] A запись для $WWW_DOMAIN корректна: $SERVER_IP${NC}"
        else
            log "${RED}[ОШИБКА] A запись для $WWW_DOMAIN некорректна. Ожидался: $SERVER_IP, Получен: $current_www_ip${NC}"
        fi
        
        # Проверка AAAA записи если IPv6 доступен
        if [ -n "$SERVER_IPV6" ]; then
            local current_aaaa_ip
            current_aaaa_ip=$(dig "$DOMAIN" AAAA +short | head -1)
            if [ "$current_aaaa_ip" = "$SERVER_IPV6" ]; then
                log "${GREEN}[ОК] AAAA запись для $DOMAIN корректна: $SERVER_IPV6${NC}"
            else
                log "${RED}[ОШИБКА] AAAA запись для $DOMAIN некорректна. Ожидался: $SERVER_IPV6, Получен: $current_aaaa_ip${NC}"
            fi
        fi
        
        if [ "$domain_resolved" = true ]; then
            log "${GREEN}[ОК] DNS записи настроены корректно!${NC}"
            return 0
        fi
        
        attempt=$((attempt + 1))
        sleep 60 # Ожидание 1 минуту между попытками
    done
    
    log "${RED}[ОШИБКА] DNS записи не были настроены за $max_attempts попыток${NC}"
    log "${YELLOW}[ПРЕДУПРЕЖДЕНИЕ] Проверьте настройки в панели RUVDS и попробуйте снова${NC}"
    return 1
}

# Функция мониторинга распространения DNS
monitor_dns_propagation() {
    log "${BLUE}[ИНФОРМАЦИЯ] Мониторинг распространения DNS по всему миру...${NC}"
    
    local dns_servers=(
        "8.8.8.8"    # Google DNS
        "1.1.1.1"    # Cloudflare DNS
        "9.9.9.9"    # Quad9 DNS
        "208.67.222.222" # OpenDNS
        "8.26.56.26" # Comodo Secure DNS
    )
    
    log "${YELLOW}Проверка DNS распространения на различных серверах...${NC}"
    echo ""
    
    for dns_server in "${dns_servers[@]}"; do
        log "${BLUE}Проверка через DNS сервер: $dns_server${NC}"
        
        # Проверка A записи
        local a_result
        a_result=$(dig @"$dns_server" "$DOMAIN" A +short 2>/dev/null)
        if [ -n "$a_result" ]; then
            if [ "$a_result" = "$SERVER_IP" ]; then
                log "${GREEN}[ОК] A запись корректна: $a_result${NC}"
            else
                log "${RED}[ОШИБКА] A запись некорректна: $a_result (ожидалось: $SERVER_IP)${NC}"
            fi
        else
            log "${RED}[ОШИБКА] A запись не найдена${NC}"
        fi
        
        # Проверка AAAA записи
        if [ -n "$SERVER_IPV6" ]; then
            local aaaa_result
            aaaa_result=$(dig @"$dns_server" "$DOMAIN" AAAA +short 2>/dev/null)
            if [ -n "$aaaa_result" ]; then
                if [ "$aaaa_result" = "$SERVER_IPV6" ]; then
                    log "${GREEN}[ОК] AAAA запись корректна: $aaaa_result${NC}"
                else
                    log "${RED}[ОШИБКА] AAAA запись некорректна: $aaaa_result (ожидалось: $SERVER_IPV6)${NC}"
                fi
            else
                log "${YELLOW}[ПРЕДУПРЕЖДЕНИЕ] AAAA запись не найдена${NC}"
            fi
        fi
        
        echo ""
    done
    
    log "${GREEN}[ОК] Мониторинг DNS распространения завершен${NC}"
}

# Функция создания DNS конфигурационного файла
create_dns_config() {
    log "${BLUE}[ИНФОРМАЦИЯ] Создание конфигурационного файла DNS записей...${NC}"
    
    local config_file="dns-config-$DOMAIN.conf"
    
    {
        echo "# DNS конфигурация для $DOMAIN"
        echo "# Создано: $(date)"
        echo "# Сервер: $(hostname)"
        echo ""
        echo "# Основные настройки"
        echo "DOMAIN=$DOMAIN"
        echo "WWW_DOMAIN=$WWW_DOMAIN"
        echo "SERVER_IP=$SERVER_IP"
        if [ -n "$SERVER_IPV6" ]; then
            echo "SERVER_IPV6=$SERVER_IPV6"
        fi
        echo "REGISTRAR=$REGISTRAR"
        echo ""
        echo "# DNS записи"
        echo "# A запись для основного домена"
        echo "$DOMAIN. IN A $SERVER_IP"
        echo ""
        echo "# A запись для www поддомена"
        echo "www.$DOMAIN. IN A $SERVER_IP"
        echo ""
        if [ -n "$SERVER_IPV6" ]; then
            echo "# AAAA запись для основного домена"
            echo "$DOMAIN. IN AAAA $SERVER_IPV6"
            echo ""
            echo "# AAAA запись для www поддомена"
            echo "www.$DOMAIN. IN AAAA $SERVER_IPV6"
            echo ""
        fi
        echo "# CNAME запись для www (альтернативная)"
        echo "www.$DOMAIN. IN CNAME $DOMAIN."
        echo ""
        echo "# TTL значения"
        echo "DEFAULT_TTL=3600"
        echo ""
        echo "# Проверка через 24 часа"
        echo "CHECK_AFTER_24HOURS=1"
    } > "$config_file"
    
    log "${GREEN}[ОК] Конфигурационный файл создан: $config_file${NC}"
}

# Функция справки
show_help() {
    echo "Скрипт для настройки DNS записей домена через панель управления RUVDS"
    echo ""
    echo "Использование: sudo $0 [опции]"
    echo ""
    echo "Опции:"
    echo "  -h, --help          Показать эту справку"
    echo "  -d, --domain        Указать домен (по умолчанию: normaldance.ru)"
    echo "  -i, --ip            Указать IP адрес сервера"
    echo "  -6, --ipv6          Указать IPv6 адрес сервера"
    echo "  -r, --registrar     Указать регистратора домена"
    echo "  -v, --verify        Только проверить текущие DNS записи"
    echo "  -m, --monitor       Только мониторить DNS распространение"
    echo "  -b, --backup        Только создать резервную копию"
    echo ""
    echo "Примеры:"
    echo "  sudo $0                                      # Полная настройка"
    echo "  sudo $0 -d example.com -i 192.168.1.1      # Настройка для другого домена"
    echo "  sudo $0 -v                                  # Только проверка DNS"
    echo "  sudo $0 -m                                  # Только мониторинг"
    echo ""
}

# Основная функция
main() {
    log "${BLUE}=========================================${NC}"
    log "${BLUE}   НАСТРОЙКА DNS ДЛЯ $DOMAIN ЧЕРЕZ RUVDS   ${NC}"
    log "${BLUE}=========================================${NC}"
    echo ""
    
    # Проверка прав root
    check_root
    
    # Парсинг аргументов командной строки
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -d|--domain)
                DOMAIN="$2"
                WWW_DOMAIN="www.$DOMAIN"
                shift 2
                ;;
            -i|--ip)
                SERVER_IP="$2"
                shift 2
                ;;
            -6|--ipv6)
                SERVER_IPV6="$2"
                shift 2
                ;;
            -r|--registrar)
                REGISTRAR="$2"
                shift 2
                ;;
            -v|--verify)
                check_current_dns
                exit 0
                ;;
            -m|--monitor)
                monitor_dns_propagation
                exit 0
                ;;
            -b|--backup)
                backup_dns_records
                exit 0
                ;;
            *)
                log "${RED}[ОШИБКА] Неизвестный параметр: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Проверка зависимостей
    check_dependencies
    
    # Определение IP адреса сервера (если не указан в аргументах)
    if [ -z "$SERVER_IP" ]; then
        get_server_ip || exit 1
    fi
    
    # Определение регистратора домена (если не указан в аргументах)
    if [ -z "$REGISTRAR" ]; then
        detect_registrar
    fi
    
    # Создание резервной копии текущих DNS записей
    backup_dns_records
    
    # Проверка текущих DNS записей
    check_current_dns
    
    # Показ инструкций для настройки в RUVDS
    show_ruvs_instructions
    
    # Запрос подтверждения перед началом настройки
    read -p "${YELLOW}Вы готовы настроить DNS записи в панели RUVDS? (y/N):${NC}" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "${YELLOW}[ОТМЕНА] Настройка DNS отменена пользователем${NC}"
        exit 0
    fi
    
    log "${GREEN}[ПОДТВЕРЖДЕНО] Начинаем настройку DNS записей${NC}"
    
    # Ожидание завершения настройки пользователем
    log "${YELLOW}Пожалуйста, выполните инструкции выше в панели управления RUVDS${NC}"
    log "${YELLOW}После завершения настройки нажмите Enter для проверки...${NC}"
    read -r
    
    # Проверка DNS записей после настройки
    verify_dns_setup
    
    # Мониторинг распространения DNS
    monitor_dns_propagation
    
    # Создание конфигурационного файла
    create_dns_config
    
    log "${GREEN}=========================================${NC}"
    log "${GREEN}   НАСТРОЙКА DNS ЗАВЕРШЕНА УСПЕШНО!      ${NC}"
    log "${GREEN}=========================================${NC}"
    echo ""
    log "${GREEN}Резервная копия DNS записей: $BACKUP_FILE${NC}"
    log "${GREEN}Лог файл: $LOG_FILE${NC}"
    log "${GREEN}Конфигурационный файл: dns-config-$DOMAIN.conf${NC}"
    echo ""
    log "${YELLOW}Важные напоминания:${NC}"
    log "1. DNS изменения могут распространяться до 48 часов"
    log "2. Проверяйте работу сайта в разных регионах"
    log "3. Обновите SSL сертификат после настройки DNS"
    log "4. Регулярно проверяйте DNS записи"
    echo ""
}

# Запуск основной функции
main "$@"