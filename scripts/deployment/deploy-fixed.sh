#!/bin/bash

# Скрипт для автоматического развертывания инфраструктуры на Cloud.ru
set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Проверка наличия Terraform
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Ошибка: Terraform не установлен${NC}"
    exit 1
fi

# Функция для вывода сообщений
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Основная функция развертывания
deploy_infrastructure() {
    log_info "Начало развертывания инфраструктуры"
    
    # Проверяем существование директории terraform
    if [ ! -d "terraform" ]; then
        log_error "Директория terraform не найдена"
        exit 1
    fi
    
    # Переходим в директорию с Terraform
    cd terraform || { log_error "Не удалось перейти в директорию terraform"; exit 1; }
    
    # Инициализация Terraform
    log_info "Инициализация Terraform"
    terraform init || { log_error "Ошибка инициализации Terraform"; exit 1; }
    
    # Проверка конфигурации
    log_info "Проверка конфигурации"
    terraform validate || { log_error "Ошибка валидации конфигурации"; exit 1; }
    
    # Просмотр плана
    log_info "Просмотр плана развертывания"
    terraform plan -var-file=terraform.tfvars -out=tfplan || { log_error "Ошибка создания плана"; exit 1; }
    
    # Запрос подтверждения
    echo -e "${YELLOW}Будет развернута инфраструктура. Продолжить? (y/n)${NC}"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        # Применение конфигурации
        log_info "Применение конфигурации"
        terraform apply -auto-approve -var-file=terraform.tfvars || { log_error "Ошибка применения конфигурации"; exit 1; }
        
        # Сохранение выходных данных
        log_info "Сохранение выходных данных"
        terraform output -json > ../infrastructure.json || log_warn "Не удалось сохранить выходные данные"
        
        # Создание бэкапа конфигурации
        log_info "Создание бэкапа конфигурации"
        mkdir -p ../backups
        cp *.tf ../backups/ 2>/dev/null || log_warn "Не удалось скопировать .tf файлы"
        cp *.tfvars ../backups/ 2>/dev/null || log_warn "Не удалось скопировать .tfvars файлы"
        tar -czf ../backups/infrastructure-backup-$(date +%Y%m%d-%H%M%S).tar.gz ../backups/ || log_warn "Не удалось создать архив"
        
        log_info "Инфраструктура успешно развернута!"
        log_info "Файл с выходными данными: infrastructure.json"
    else
        log_info "Развертывание отменено"
    fi
}

# Функция для удаления инфраструктуры
destroy_infrastructure() {
    log_info "Начало удаления инфраструктуры"
    
    # Проверяем существование директории terraform
    if [ ! -d "terraform" ]; then
        log_error "Директория terraform не найдена"
        exit 1
    fi
    
    cd terraform || { log_error "Не удалось перейти в директорию terraform"; exit 1; }
    
    # Запрос подтверждения
    echo -e "${RED}Будет удалена вся инфраструктура. Продолжить? (y/n)${NC}"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        # Удаление инфраструктуры
        log_info "Удаление инфраструктуры"
        terraform destroy -auto-approve -var-file=terraform.tfvars || { log_error "Ошибка удаления инфраструктуры"; exit 1; }
        
        # Очистка
        log_info "Очистка временных файлов"
        rm -f tfplan
        rm -f .terraform.lock.hcl
        rm -rf .terraform
        
        log_info "Инфраструктура успешно удалена!"
    else
        log_info "Удаление отменено"
    fi
}

# Функция для просмотра состояния
show_status() {
    log_info "Просмотр состояния инфраструктуры"
    
    # Проверяем существование директории terraform
    if [ ! -d "terraform" ]; then
        log_error "Директория terraform не найдена"
        exit 1
    fi
    
    cd terraform || { log_error "Не удалось перейти в директорию terraform"; exit 1; }
    
    if [ -f "terraform.tfstate" ]; then
        echo -e "${GREEN}Текущее состояние инфраструктуры:${NC}"
        terraform state list || log_warn "Не удалось получить список состояний"
        echo ""
        echo -e "${GREEN}Выходные данные:${NC}"
        terraform output || log_warn "Не удалось получить выходные данные"
    else
        log_warn "Файл состояния не найден. Инфраструктура не развернута."
    fi
}

# Основная логика скрипта
case "${1:-}" in
    "deploy")
        deploy_infrastructure
        ;;
    "destroy")
        destroy_infrastructure
        ;;
    "status")
        show_status
        ;;
    *)
        echo "Использование: $0 {deploy|destroy|status}"
        echo ""
        echo "  deploy    - Развернуть инфраструктуру"
        echo "  destroy   - Удалить инфраструктуру"
        echo "  status    - Показать состояние инфраструктуры"
        exit 1
        ;;
esac