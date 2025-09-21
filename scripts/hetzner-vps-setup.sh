#!/bin/bash

# Скрипт для заказа VPS на Hetzner и базовой настройки системы
# Для NORMALDANCE Enterprise

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Начинаю настройку VPS для NORMALDANCE${NC}"
echo -e "${GREEN}=========================================${NC}"

# Проверка наличия необходимых инструментов
check_requirements() {
    echo -e "${YELLOW}🔍 Проверка необходимых инструментов...${NC}"
    
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}❌ curl не установлен${NC}"
        exit 1
    fi
    
    if ! command -v wget &> /dev/null; then
        echo -e "${RED}❌ wget не установлен${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Все необходимые инструменты установлены${NC}"
}

# Создание SSH ключа (если отсутствует)
create_ssh_key() {
    echo -e "${YELLOW}🔑 Проверка SSH ключей...${NC}"
    
    if [ ! -f ~/.ssh/id_rsa ]; then
        echo -e "${YELLOW}🔑 Создание нового SSH ключа...${NC}"
        ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
        echo -e "${GREEN}✅ SSH ключ создан${NC}"
    else
        echo -e "${GREEN}✅ SSH ключ уже существует${NC}"
    fi
    
    echo -e "${YELLOW}📋 Публичный SSH ключ:${NC}"
    cat ~/.ssh/id_rsa.pub
    echo ""
}

# Регистрация на Hetzner (если нужно)
register_hetzner() {
    echo -e "${YELLOW}📝 Регистрация на Hetzner${NC}"
    echo "Если у вас еще нет аккаунта на Hetzner:"
    echo "1. Перейдите на: https://www.hetzner.com/"
    echo "2. Зарегистрируйтесь"
    echo "3. Добавьте платежный метод"
    echo "4. Пополните баланс минимум на $5"
    echo ""
    read -p "Нажмите Enter после регистрации..."
}

# Создание сервера через Hetzner API (требуется API токен)
create_server() {
    echo -e "${YELLOW}🖥️ Создание сервера на Hetzner${NC}"
    
    echo "Пожалуйста, выполните следующие шаги вручную:"
    echo "1. Зайдите в панель управления Hetzner"
    echo "2. Перейдите в раздел 'Servers'"
    echo "3. Нажмите 'Add Server'"
    echo "4. Выберите:"
    echo "   - Location: Nuremberg (NUE1) или Falkenstein (FSN1)"
    echo "   - Server type: CX11"
    echo "   - Image: Ubuntu 22.04 LTS"
    echo "   - SSH ключ: выберите ваш ключ (~/.ssh/id_rsa.pub)"
    echo "   - Enable IPv6: ✅"
    echo "5. Нажмите 'Create & Buy'"
    echo ""
    
    read -p "Нажмите Enter после создания сервера..."
}

# Получение IP адреса сервера
get_server_ip() {
    echo -e "${YELLOW}🌐 Получение IP адреса сервера${NC}"
    
    echo "Пожалуйста, введите IP адрес вашего нового сервера:"
    read -p "IP адрес: " SERVER_IP
    
    if [[ ! $SERVER_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}❌ Неверный формат IP адреса${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ IP адрес: $SERVER_IP${NC}"
}

# Базовая настройка сервера
setup_server() {
    echo -e "${YELLOW}⚙️ Базовая настройка сервера${NC}"
    
    # Создание файла inventory для Ansible
    cat > inventory.ini << EOF
[servers]
server ansible_host=$SERVER_IP ansible_user=root
EOF
    
    # Создание playbook для базовой настройки
    cat > setup-server.yml << EOF
---
- name: Базовая настройка сервера
  hosts: servers
  become: yes
  tasks:
    - name: Обновление системы
      apt:
        update: yes
        upgrade: dist
        
    - name: Установка необходимых пакетов
      apt:
        name:
          - git
          - curl
          - wget
          - htop
          - unzip
          - nginx
          - python3-certbot-nginx
        state: present
        
    - name: Установка Node.js 20
      shell: |
        curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
        apt-get install -y nodejs
        
    - name: Настройка swap-файла
      shell: |
        fallocate -l 2G /swapfile
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
        
    - name: Создание пользователя для приложения
      user:
        name: normaldance
        shell: /bin/bash
        create_home: yes
        
    - name: Настройка SSH для normaldance
      authorized_key:
        user: normaldance
        key: "{{ lookup('file', '~/.ssh/id_rsa.pub') }}"
        
    - name: Отключение root SSH доступа
      lineinfile:
        path: /etc/ssh/sshd_config
        regexp: '^PermitRootLogin'
        line: 'PermitRootLogin no'
        state: present
      notify: Restart SSH
        
    - name: Создание директорий для приложения
      file:
        path: "{{ item }}"
        state: directory
        owner: normaldance
        group: normaldance
      with_items:
        - /var/www/normaldance.ru
        - /var/backups/normaldance
        - /etc/nginx/sites-available
        - /etc/nginx/sites-enabled
        
  handlers:
    - name: Restart SSH
      service:
        name: sshd
        state: restarted
EOF
    
    echo -e "${GREEN}✅ Playbook для базовой настройки создан${NC}"
}

# Тестирование подключения к серверу
test_connection() {
    echo -e "${YELLOW}🔌 Тестирование подключения к серверу${NC}"
    
    # Проверка доступности сервера
    echo "Проверка доступности сервера..."
    timeout 30 bash -c "until ping -c 1 $SERVER_IP &> /dev/null; do sleep 1; done"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Сервер доступен${NC}"
    else
        echo -e "${RED}❌ Сервер недоступен${NC}"
        exit 1
    fi
    
    # Проверка SSH подключения
    echo "Проверка SSH подключения..."
    if ssh -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=5 root@$SERVER_IP "exit" 2>/dev/null; then
        echo -e "${GREEN}✅ SSH подключение работает${NC}"
    else
        echo -e "${RED}❌ SSH подключение не работает${NC}"
        exit 1
    fi
}

# Основной процесс
main() {
    echo -e "${GREEN}🚀 Запуск процесса настройки VPS для NORMALDANCE${NC}"
    echo -e "${GREEN}===============================================${NC}"
    echo ""
    
    check_requirements
    create_ssh_key
    register_hetzner
    create_server
    get_server_ip
    setup_server
    test_connection
    
    echo -e "${GREEN}🎉 Базовая настройка VPS завершена!${NC}"
    echo ""
    echo "Следующие шаги:"
    echo "1. Настройте DNS записи в панели управления домена"
    echo "2. Запустите ansible-playbook setup-server.yml для настройки сервера"
    echo "3. Разверните Next.js приложение"
    echo ""
    echo -e "${YELLOW}📋 Важная информация:${NC}"
    echo "IP адрес сервера: $SERVER_IP"
    echo "SSH ключ: ~/.ssh/id_rsa"
    echo "Пользователь: normaldance"
}

# Запуск основного процесса
main "$@"