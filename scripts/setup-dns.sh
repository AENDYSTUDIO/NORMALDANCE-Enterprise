#!/bin/bash

# Скрипт для настройки DNS записей домена normaldance.ru
# Для NORMALDANCE Enterprise

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}🌐 Настройка DNS записей для normaldance.ru${NC}"
echo -e "${GREEN}=========================================${NC}"

# Переменные
DOMAIN="normaldance.ru"
SERVER_IP=""
SERVER_IPV6=""
REGISTRAR=""
RECORD_TYPE="A"

# Функция для получения IP адреса сервера
get_server_ip() {
    echo -e "${YELLOW}🌐 Введите IP адрес вашего VPS сервера:${NC}"
    read -p "IPv4 адрес: " SERVER_IP
    
    if [[ ! $SERVER_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}❌ Неверный формат IPv4 адреса${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}🌐 Введите IPv6 адрес вашего VPS сервера (если есть):${NC}"
    read -p "IPv6 адрес (оставьте пустым, если нет): " SERVER_IPV6
    
    if [ -n "$SERVER_IPV6" ] && [[ ! $SERVER_IPV6 =~ ^([0-9a-fA-F:]+:+)+[0-9a-fA-F]+$ ]]; then
        echo -e "${RED}❌ Неверный формат IPv6 адреса${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ IPv4 адрес: $SERVER_IP${NC}"
    if [ -n "$SERVER_IPV6" ]; then
        echo -e "${GREEN}✅ IPv6 адрес: $SERVER_IPV6${NC}"
    fi
}

# Функция для определения регистратора домена
detect_registrar() {
    echo -e "${YELLOW}🏢 Определение регистратора домена${NC}"
    
    # Получение информации о домене
    if command -v whois &> /dev/null; then
        REGISTRAR_INFO=$(whois $DOMAIN | grep -i "Registrar\|Registrar:")
        echo "$REGISTRAR_INFO"
        
        # Определение регистратора
        if echo "$REGISTRAR_INFO" | grep -qi "reg.ru"; then
            REGISTRAR="reg.ru"
        elif echo "$REGISTRAR_INFO" | grep -qi "nic.ru"; then
            REGISTRAR="nic.ru"
        elif echo "$REGISTRAR_INFO" | grep -qi "cloudflare"; then
            REGISTRAR="cloudflare"
        elif echo "$REGISTRAR_INFO" | grep -qi "namecheap"; then
            REGISTRAR="namecheap"
        elif echo "$REGISTRAR_INFO" | grep -qi "godaddy"; then
            REGISTRAR="godaddy"
        elif echo "$REGISTRAR_INFO" | grep -qi "porkbun"; then
            REGISTRAR="porkbun"
        else
            echo -e "${YELLOW}⚠️  Регистратор не определен автоматически${NC}"
            echo -e "${YELLOW}🏢 Выберите ваш регистратор домена:${NC}"
            echo "1. Reg.ru"
            echo "2. Nic.ru"
            echo "3. Cloudflare"
            echo "4. Namecheap"
            echo "5. GoDaddy"
            echo "6. Porkbun"
            echo "7. Другой"
            
            read -p "Выберите номер: " choice
            
            case $choice in
                1) REGISTRAR="reg.ru" ;;
                2) REGISTRAR="nic.ru" ;;
                3) REGISTRAR="cloudflare" ;;
                4) REGISTRAR="namecheap" ;;
                5) REGISTRAR="godaddy" ;;
                6) REGISTRAR="porkbun" ;;
                7) REGISTRAR="other" ;;
                *) echo -e "${RED}❌ Неверный выбор${NC}"; exit 1 ;;
            esac
        fi
    else
        echo -e "${RED}❌ whois не установлен${NC}"
        echo -e "${YELLOW}🏢 Выберите ваш регистратор домена:${NC}"
        echo "1. Reg.ru"
        echo "2. Nic.ru"
        echo "3. Cloudflare"
        echo "4. Namecheap"
        echo "5. GoDaddy"
        echo "6. Porkbun"
        echo "7. Другой"
        
        read -p "Выберите номер: " choice
        
        case $choice in
            1) REGISTRAR="reg.ru" ;;
            2) REGISTRAR="nic.ru" ;;
            3) REGISTRAR="cloudflare" ;;
            4) REGISTRAR="namecheap" ;;
            5) REGISTRAR="godaddy" ;;
            6) REGISTRAR="porkbun" ;;
            7) REGISTRAR="other" ;;
            *) echo -e "${RED}❌ Неверный выбор${NC}"; exit 1 ;;
        esac
    fi
    
    echo -e "${GREEN}✅ Определен регистратор: $REGISTRAR${NC}"
}

# Функция для создания DNS записей
create_dns_records() {
    echo -e "${YELLOW}📝 Создание DNS записей${NC}"
    
    case $REGISTRAR in
        "reg.ru")
            echo -e "${BLUE}📋 Инструкции для Reg.ru:${NC}"
            echo "1. Зайдите в личный кабинет Reg.ru"
            echo "2. Перейдите в раздел 'Управление доменами'"
            echo "3. Выберите домен $DOMAIN"
            echo "4. Перейдите в раздел 'Дисковая утилита'"
            echo "5. Создайте файл с DNS записями:"
            echo ""
            echo "$DOMAIN. 3600 IN A $SERVER_IP"
            if [ -n "$SERVER_IPV6" ]; then
                echo "$DOMAIN. 3600 IN AAAA $SERVER_IPV6"
            fi
            echo "www.$DOMAIN. 3600 IN A $SERVER_IP"
            if [ -n "$SERVER_IPV6" ]; then
                echo "www.$DOMAIN. 3600 IN AAAA $SERVER_IPV6"
            fi
            echo ""
            echo "6. Загрузите файл в дисковую утилиту"
            echo "7. Дождитесь обновления DNS (обычно 10-60 минут)"
            ;;
            
        "nic.ru")
            echo -e "${BLUE}📋 Инструкции для Nic.ru:${NC}"
            echo "1. Зайдите в личный кабинет Nic.ru"
            echo "2. Перейдите в раздел 'Мои домены'"
            echo "3. Выберите домен $DOMAIN"
            echo "4. Перейдите в раздел 'Управление DNS'"
            echo "5. Добавьте следующие записи:"
            echo ""
            echo "Type: A, Name: @, Value: $SERVER_IP, TTL: 3600"
            echo "Type: A, Name: www, Value: $SERVER_IP, TTL: 3600"
            if [ -n "$SERVER_IPV6" ]; then
                echo "Type: AAAA, Name: @, Value: $SERVER_IPV6, TTL: 3600"
                echo "Type: AAAA, Name: www, Value: $SERVER_IPV6, TTL: 3600"
            fi
            echo ""
            echo "6. Сохраните изменения"
            echo "7. Дождитесь обновления DNS (обычно 10-60 минут)"
            ;;
            
        "cloudflare")
            echo -e "${BLUE}📋 Инструкции для Cloudflare:${NC}"
            echo "1. Зайдите в личный кабинет Cloudflare"
            echo "2. Выберите домен $DOMAIN"
            echo "3. Перейдите в раздел 'DNS'"
            echo "4. Добавьте следующие записи:"
            echo ""
            echo "Type: A, Name: @, Value: $SERVER_IP, Proxy status: Proxied (облако)"
            echo "Type: A, Name: www, Value: $SERVER_IP, Proxy status: Proxied (облако)"
            if [ -n "$SERVER_IPV6" ]; then
                echo "Type: AAAA, Name: @, Value: $SERVER_IPV6, Proxy status: Proxied (облако)"
                echo "Type: AAAA, Name: www, Value: $SERVER_IPV6, Proxy status: Proxied (облако)"
            fi
            echo ""
            echo "5. Сохраните изменения"
            echo "6. Дождитесь обновления DNS (обычно 1-5 минут)"
            ;;
            
        "namecheap")
            echo -e "${BLUE}📋 Инструкции для Namecheap:${NC}"
            echo "1. Зайдите в личный кабинет Namecheap"
            echo "2. Перейдите в раздел 'Domain List'"
            echo "3. Выберите домен $DOMAIN"
            echo "4. Перейдите в раздел 'Advanced DNS'"
            echo "5. Добавьте следующие записи:"
            echo ""
            echo "Host: @, Type: A, Value: $SERVER_IP, TTL: Automatic"
            echo "Host: www, Type: A, Value: $SERVER_IP, TTL: Automatic"
            if [ -n "$SERVER_IPV6" ]; then
                echo "Host: @, Type: AAAA, Value: $SERVER_IPV6, TTL: Automatic"
                echo "Host: www, Type: AAAA, Value: $SERVER_IPV6, TTL: Automatic"
            fi
            echo ""
            echo "6. Сохраните изменения"
            echo "7. Дождитесь обновления DNS (обычно 10-60 минут)"
            ;;
            
        "godaddy")
            echo -e "${BLUE}📋 Инструкции для GoDaddy:${NC}"
            echo "1. Зайдите в личный кабинет GoDaddy"
            echo "2. Перейдите в раздел 'Domains'"
            echo "3. Выберите домен $DOMAIN"
            echo "4. Перейдите в раздел 'DNS Management'"
            echo "5. Добавьте следующие записи:"
            echo ""
            echo "Type: A, Host: @, Points to: $SERVER_IP, TTL: 1 Hour"
            echo "Type: A, Host: @, Points to: $SERVER_IP, TTL: 1 Hour"
            if [ -n "$SERVER_IPV6" ]; then
                echo "Type: AAAA, Host: @, Points to: $SERVER_IPV6, TTL: 1 Hour"
                echo "Type: AAAA, Host: @, Points to: $SERVER_IPV6, TTL: 1 Hour"
            fi
            echo ""
            echo "6. Сохраните изменения"
            echo "7. Дождитесь обновления DNS (обычно 10-60 минут)"
            ;;
            
        "porkbun")
            echo -e "${BLUE}📋 Инструкции для Porkbun:${NC}"
            echo "1. Зайдите в личный кабинет Porkbun"
            echo "2. Перейдите в раздел 'DNS'"
            echo "3. Выберите домен $DOMAIN"
            echo "4. Добавьте следующие записи:"
            echo ""
            echo "Type: A, Name: @, Content: $SERVER_IP, TTL: 3600"
            echo "Type: A, Name: www, Content: $SERVER_IP, TTL: 3600"
            if [ -n "$SERVER_IPV6" ]; then
                echo "Type: AAAA, Name: @, Content: $SERVER_IPV6, TTL: 3600"
                echo "Type: AAAA, Name: www, Content: $SERVER_IPV6, TTL: 3600"
            fi
            echo ""
            echo "5. Сохраните изменения"
            echo "6. Дождитесь обновления DNS (обычно 1-5 минут)"
            ;;
            
        *)
            echo -e "${BLUE}📋 Общие инструкции для настройки DNS:${NC}"
            echo "1. Зайдите в панель управления вашего регистратора доменов"
            echo "2. Найдите раздел управления DNS записями"
            echo "3. Добавьте следующие записи:"
            echo ""
            echo "Type: A, Name: @, Value: $SERVER_IP, TTL: 3600"
            echo "Type: A, Name: www, Value: $SERVER_IP, TTL: 3600"
            if [ -n "$SERVER_IPV6" ]; then
                echo "Type: AAAA, Name: @, Value: $SERVER_IPV6, TTL: 3600"
                echo "Type: AAAA, Name: www, Value: $SERVER_IPV6, TTL: 3600"
            fi
            echo ""
            echo "4. Сохраните изменения"
            echo "5. Дождитесь обновления DNS (обычно 10-60 минут)"
            ;;
    esac
}

# Функция для проверки DNS записей
check_dns_records() {
    echo -e "${YELLOW}🔍 Проверка DNS записей${NC}"
    
    # Проверка A записей
    if nslookup $DOMAIN | grep -q "$SERVER_IP"; then
        echo -e "${GREEN}✅ A запись для $DOMAIN настроена правильно${NC}"
    else
        echo -e "${RED}❌ A запись для $DOMAIN не найдена или неверна${NC}"
    fi
    
    if nslookup www.$DOMAIN | grep -q "$SERVER_IP"; then
        echo -e "${GREEN}✅ A запись для www.$DOMAIN настроена правильно${NC}"
    else
        echo -e "${RED}❌ A запись для www.$DOMAIN не найдена или неверна${NC}"
    fi
    
    # Проверка AAAA записей
    if [ -n "$SERVER_IPV6" ]; then
        if nslookup $DOMAIN | grep -q "$SERVER_IPV6"; then
            echo -e "${GREEN}✅ AAAA запись для $DOMAIN настроена правильно${NC}"
        else
            echo -e "${RED}❌ AAAA запись для $DOMAIN не найдена или неверна${NC}"
        fi
        
        if nslookup www.$DOMAIN | grep -q "$SERVER_IPV6"; then
            echo -e "${GREEN}✅ AAAA запись для www.$DOMAIN настроена правильно${NC}"
        else
            echo -e "${RED}❌ AAAA запись для www.$DOMAIN не найдена или неверна${NC}"
        fi
    fi
    
    # Проверка propagation
    echo -e "${YELLOW}🔄 Проверка распространения DNS по всему миру${NC}"
    echo "Используйте следующие инструменты для проверки:"
    echo "1. https://dnschecker.org"
    echo "2. https://whatsmydns.net"
    echo "3. https://www.ultratools.com/tools/dnsLookupResult"
    echo ""
    echo "Введите 'done' когда DNS записи обновятся по всему миру:"
    read -p "Статус: " status
    
    while [ "$status" != "done" ]; do
        echo -e "${YELLOW}🔄 Ожидание обновления DNS...${NC}"
        read -p "Статус: " status
    done
}

# Функция для создания файла с DNS записями
create_dns_file() {
    echo -e "${YELLOW}📄 Создание файла с DNS записями${NC}"
    
    cat > dns-records.txt << EOF
DNS записи для домена $DOMAIN

IPv4 адрес сервера: $SERVER_IP
IPv6 адрес сервера: ${SERVER_IPV6:-"Не указан"}

Записи:
- A запись: $DOMAIN. -> $SERVER_IP
- A запись: www.$DOMAIN. -> $SERVER_IP
EOF
    
    if [ -n "$SERVER_IPV6" ]; then
        echo "- AAAA запись: $DOMAIN. -> $SERVER_IPV6" >> dns-records.txt
        echo "- AAAA запись: www.$DOMAIN. -> $SERVER_IPV6" >> dns-records.txt
    fi
    
    echo "TTL: 3600 секунд (1 час)"
    echo ""
    echo "Файл сохранен как: dns-records.txt"
    echo "Используйте этот файл для настройки DNS в панели управления вашего регистратора."
    
    echo -e "${GREEN}✅ Файл с DNS записями создан${NC}"
}

# Основной процесс
main() {
    echo -e "${GREEN}🚀 Запуск процесса настройки DNS для $DOMAIN${NC}"
    echo -e "${GREEN}===========================================${NC}"
    echo ""
    
    get_server_ip
    detect_registrar
    create_dns_records
    create_dns_file
    check_dns_records
    
    echo -e "${GREEN}🎉 Настройка DNS завершена!${NC}"
    echo ""
    echo -e "${BLUE}📋 Следующие шаги:${NC}"
    echo "1. Настройте VPS сервер согласно плану"
    echo "2. Разверните Next.js приложение"
    echo "3. Настройте SSL сертификат"
    echo "4. Проверьте работу сайта"
    echo ""
    echo -e "${YELLOW}⏱️  Время обновления DNS: 10-60 минут (иногда до 24 часов)${NC}"
    echo -e "${YELLOW}🔍 Проверяйте обновление через: https://dnschecker.org${NC}"
}

# Запуск основного процесса
main "$@"