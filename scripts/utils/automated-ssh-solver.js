#!/usr/bin/env node

/**
 * Автоматизированный скрипт для решения проблемы SSH-подключения к серверу 176.108.246.49
 * Обрабатывает все аспекты проблемы: создание ключей, конфигурацию, добавление на сервер
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const os = require('os');

class AutomatedSHHSolver {
    constructor() {
        this.serverIP = '176.108.246.49';
        this.sshUser = 'root';
        this.sshDir = path.join(os.homedir(), '.ssh');
        this.configFile = path.join(this.sshDir, 'config');
        this.ed25519Key = path.join(this.sshDir, 'id_ed25519');
        this.ed25519Pub = path.join(this.sshDir, 'id_ed25519.pub');
        this.rsaKey = path.join(this.sshDir, 'id_rsa');
        this.rsaPub = path.join(this.sshDir, 'id_rsa.pub');
        
        this.colors = {
            reset: '\x1b[0m',
            red: '\x1b[31m',
            green: '\x1b[32m',
            yellow: '\x1b[33m',
            blue: '\x1b[34m',
            magenta: '\x1b[35m',
            cyan: '\x1b[36m'
        };
    }

    log(message, color = 'reset') {
        console.log(`${this.colors[color]}${message}${this.colors.reset}`);
    }

    error(message) {
        this.log(`❌ ${message}`, 'red');
    }

    success(message) {
        this.log(`✅ ${message}`, 'green');
    }

    info(message) {
        this.log(`ℹ️  ${message}`, 'yellow');
    }

    debug(message) {
        this.log(`🔍 ${message}`, 'cyan');
    }

    // Проверка предпосылок
    checkPrerequisites() {
        this.info('Проверка предпосылок...');
        
        // Проверка SSH
        try {
            execSync('ssh -V', { stdio: 'ignore' });
            this.success('SSH клиент доступен');
        } catch (error) {
            this.error('SSH клиент не найден. Установите OpenSSH.');
            return false;
        }

        // Проверка директории .ssh
        if (!fs.existsSync(this.sshDir)) {
            fs.mkdirSync(this.sshDir, { mode: 0o700 });
            this.success(`Создана директория ${this.sshDir}`);
        }

        return true;
    }

    // Создание SSH-ключей
    createSSHKeys() {
        this.info('Создание SSH-ключей...');
        
        let keysCreated = false;

        // Ed25519 ключ
        if (!fs.existsSync(this.ed25519Key)) {
            try {
                execSync(`ssh-keygen -t ed25519 -f "${this.ed25519Key}" -N ""`, { stdio: 'ignore' });
                this.success('Создан Ed25519 ключ');
                keysCreated = true;
            } catch (error) {
                this.error('Не удалось создать Ed25519 ключ');
            }
        } else {
            this.success('Ed25519 ключ уже существует');
        }

        // RSA ключ (резервный)
        if (!fs.existsSync(this.rsaKey)) {
            try {
                execSync(`ssh-keygen -t rsa -b 4096 -f "${this.rsaKey}" -N ""`, { stdio: 'ignore' });
                this.success('Создан RSA ключ (резервный)');
                keysCreated = true;
            } catch (error) {
                this.error('Не удалось создать RSA ключ');
            }
        } else {
            this.success('RSA ключ уже существует');
        }

        return keysCreated;
    }

    // Создание SSH-конфигурации
    createSSHConfig() {
        this.info('Создание SSH-конфигурации...');
        
        const configContent = `# Конфигурация для сервера ${this.serverIP}
Host ${this.serverIP}
    HostName ${this.serverIP}
    User ${this.sshUser}
    Port 22
    IdentityFile ${this.ed25519Key}
    IdentitiesOnly yes
    StrictHostKeyChecking yes
    UserKnownHostsFile ${this.sshDir}/known_hosts
    PreferredAuthentications publickey
    ServerAliveInterval 60
    ServerAliveCountMax 3

# Алиасы для удобства
Host normaldance-server
    HostName ${this.serverIP}
    User ${this.sshUser}
    IdentityFile ${this.ed25519Key}
    IdentitiesOnly yes
    StrictHostKeyChecking yes
    UserKnownHostsFile ${this.sshDir}/known_hosts
    PreferredAuthentications publickey
    ServerAliveInterval 60
    ServerAliveCountMax 3

Host normaldance-server-rsa
    HostName ${this.serverIP}
    User ${this.sshUser}
    IdentityFile ${this.rsaKey}
    IdentitiesOnly yes
    StrictHostKeyChecking yes
    UserKnownHostsFile ${this.sshDir}/known_hosts
    PreferredAuthentications publickey
    ServerAliveInterval 60
    ServerAliveCountMax 3

# Отладочный хост
Host normaldance-server-debug
    HostName ${this.serverIP}
    User ${this.sshUser}
    IdentityFile ${this.ed25519Key}
    IdentitiesOnly yes
    StrictHostKeyChecking yes
    UserKnownHostsFile ${this.sshDir}/known_hosts
    PreferredAuthentications publickey
    ServerAliveInterval 60
    ServerAliveCountMax 3
    LogLevel DEBUG3

# Общие настройки
Host *
    Compression no
    ConnectTimeout 30`;

        try {
            fs.writeFileSync(this.configFile, configContent);
            fs.chmodSync(this.configFile, 0o600);
            this.success(`SSH конфигурация создана: ${this.configFile}`);
            return true;
        } catch (error) {
            this.error(`Не удалось создать конфигурацию: ${error.message}`);
            return false;
        }
    }

    // Тестирование подключения
    testConnection(identityFile = this.ed25519Key) {
        this.info(`Тестирование подключения с ${path.basename(identityFile)}...`);
        
        try {
            const result = execSync(`ssh -o BatchMode=yes -o ConnectTimeout=10 -i "${identityFile}" ${this.sshUser}@${this.serverIP} "echo 'Подключение успешно'"`, { 
                encoding: 'utf8',
                stdio: 'pipe'
            });
            
            if (result.includes('Подключение успешно')) {
                this.success('Подключение успешно!');
                return true;
            }
        } catch (error) {
            this.debug(`Ошибка подключения: ${error.message}`);
        }
        
        return false;
    }

    // Добавление ключа через ssh-copy-id
    addKeyWithSshCopyId() {
        this.info('Попытка добавления ключа через ssh-copy-id...');
        
        try {
            execSync(`ssh-copy-id -i "${this.ed25519Pub}" ${this.sshUser}@${this.serverIP}`, { 
                stdio: 'inherit',
                timeout: 30000
            });
            
            this.success('Ключ успешно добавлен через ssh-copy-id');
            return true;
        } catch (error) {
            this.debug('ssh-copy-id не сработал, пробуем альтернативные методы');
            return false;
        }
    }

    // Генерация инструкции для ручного добавления ключа
    generateManualAddInstructions() {
        this.info('Генерация инструкции для ручного добавления ключа...');
        
        if (!fs.existsSync(this.ed25519Pub)) {
            this.error('Публичный ключ не найден');
            return null;
        }

        const publicKey = fs.readFileSync(this.ed25519Pub, 'utf8').trim();
        
        const instructions = `
📋 ИНСТРУКЦИЯ ДЛЯ РУЧНОГО ДОБАВЛЕНИЯ КЛЮЧА НА СЕРВЕР

1. ПОДКЛЮЧЕНИЕ К СЕРВЕРУ (если есть доступ):
   ssh normaldance-server-rsa

2. ДОБАВЛЕНИЕ КЛЮЧА НА СЕРВЕРЕ:
   mkdir -p ~/.ssh
   chmod 700 ~/.ssh
   echo '${publicKey}' >> ~/.ssh/authorized_keys
   chmod 600 ~/.ssh/authorized_keys

3. ПРОВЕРКА ПОДКЛЮЧЕНИЯ:
   ssh normaldance-server

ИЛИ ИСПОЛЬЗУЙТЕ АВТОМАТИЧЕСКИЙ МЕТОД:
ssh-copy-id -i ~/.ssh/id_ed25519.pub ${this.sshUser}@${this.serverIP}

ПУБЛИЧНЫЙ КЛЮЧ ДЛЯ ДОБАВЛЕНИЯ:
${publicKey}
`;

        console.log(instructions);
        return publicKey;
    }

    // Основной процесс решения
    async solve() {
        this.log('=== АВТОМАТИЗИРОВАННОЕ РЕШЕНИЕ ПРОБЛЕМЫ SSH ===', 'blue');
        this.log(`Сервер: ${this.serverIP}`, 'blue');
        this.log(`Пользователь: ${this.sshUser}`, 'blue');
        console.log('');

        // Шаг 1: Проверка предпосылок
        if (!this.checkPrerequisites()) {
            this.error('Предпосылки не выполнены. Прерываю выполнение.');
            return false;
        }

        // Шаг 2: Создание ключей
        this.createSSHKeys();

        // Шаг 3: Создание конфигурации
        if (!this.createSSHConfig()) {
            this.error('Не удалось создать конфигурацию');
            return false;
        }

        // Шаг 4: Тестирование подключения
        if (this.testConnection()) {
            this.success('🎉 Проблема решена! Подключение работает.');
            this.showUsageInstructions();
            return true;
        }

        // Шаг 5: Пробуем добавить ключ через ssh-copy-id
        if (this.addKeyWithSshCopyId()) {
            if (this.testConnection()) {
                this.success('🎉 Ключ успешно добавлен! Проблема решена.');
                this.showUsageInstructions();
                return true;
            }
        }

        // Шаг 6: Генерация инструкций для ручного добавления
        const publicKey = this.generateManualAddInstructions();

        // Шаг 7: Тестирование с RSA ключом
        this.info('Тестирование с RSA ключом...');
        if (this.testConnection(this.rsaKey)) {
            this.success('✅ Подключение работает с RSA ключом!');
            this.log('');
            this.info('РЕШЕНИЕ:');
            this.log('1. Используйте RSA ключ для подключения: ssh normaldance-server-rsa', 'yellow');
            this.log('2. Добавьте Ed25519 ключ вручную по инструкции выше', 'yellow');
            this.log('3. После добавления используйте: ssh normaldance-server', 'yellow');
            return true;
        }

        // Шаг 8: Итог
        this.log('');
        this.error('Все автоматические методы не сработали');
        this.log('');
        this.info('АЛЬТЕРНАТИВНЫЕ РЕШЕНИЯ:');
        this.log('1. Свяжитесь с администратором сервера', 'yellow');
        this.log('2. Используйте парольную аутентификацию (если разрешена)', 'yellow');
        this.log('3. Добавьте ключ через панель управления сервером', 'yellow');
        this.log('4. Проверьте права доступа на сервере:', 'yellow');
        this.log('   - chmod 700 ~/.ssh', 'yellow');
        this.log('   - chmod 600 ~/.ssh/authorized_keys', 'yellow');
        this.log('   - chown $USER:$USER ~/.ssh -R', 'yellow');

        return false;
    }

    // Инструкции по использованию
    showUsageInstructions() {
        this.log('');
        this.info('ИНСТРУКЦИИ ПО ИСПОЛЬЗОВАНИЮ:');
        this.log('');
        this.log('Основные команды:', 'green');
        this.log('  ssh normaldance-server     # Основное подключение', 'cyan');
        this.log('  ssh normaldance-server-rsa # Резервное подключение', 'cyan');
        this.log('  ssh ${this.serverIP}         # Прямое подключение', 'cyan');
        this.log('');
        this.log('Для отладки:', 'green');
        this.log('  ssh -vvv normaldance-server   # Подробный вывод', 'cyan');
        this.log('  ssh -T normaldance-server     # Только проверка', 'cyan');
        this.log('');
        this.log('Проверка ключей:', 'green');
        this.log('  ssh-keygen -l -f ~/.ssh/id_ed25519.pub', 'cyan');
        this.log('  ssh-keygen -l -f ~/.ssh/id_rsa.pub', 'cyan');
    }
}

// Запуск скрипта
if (require.main === module) {
    const solver = new AutomatedSHHSolver();
    solver.solve().then(success => {
        process.exit(success ? 0 : 1);
    }).catch(error => {
        console.error('Критическая ошибка:', error);
        process.exit(1);
    });
}

module.exports = AutomatedSHHSolver;