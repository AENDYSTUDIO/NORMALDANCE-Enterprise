#!/usr/bin/env node

/**
 * Скрипт для добавления SSH-ключа на удаленный сервер
 * Альтернативное решение для случаев, когда нет прямого доступа к серверу
 */

const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');
const { promisify } = require('util');

const execAsync = promisify(exec);

class SSHKeyAdder {
    constructor() {
        this.serverIP = '176.108.246.49';
        this.sshUser = 'root'; // Замените на вашего пользователя
        this.keyPath = path.join(process.env.HOME || require('os').homedir(), '.ssh', 'id_ed25519.pub');
    }

    async checkPrerequisites() {
        console.log('🔍 Проверка предпосылок...');
        
        if (!fs.existsSync(this.keyPath)) {
            throw new Error(`SSH ключ не найден: ${this.keyPath}`);
        }

        const publicKey = fs.readFileSync(this.keyPath, 'utf8');
        console.log('✅ SSH ключ найден:', this.keyPath);
        console.log('📋 Публичный ключ:', publicKey.trim());
        
        return publicKey;
    }

    async generateSSHConfig() {
        console.log('📝 Генерация SSH конфигурации...');
        
        const configContent = `# Конфигурация для сервера ${this.serverIP}
Host ${this.serverIP}
    HostName ${this.serverIP}
    User ${this.sshUser}
    Port 22
    IdentityFile ${path.join(process.env.HOME || require('os').homedir(), '.ssh', 'id_ed25519')}
    IdentitiesOnly yes
    StrictHostKeyChecking yes
    UserKnownHostsFile ~/.ssh/known_hosts
    PreferredAuthentications publickey
    ServerAliveInterval 60
    ServerAliveCountMax 3

# Алиас для удобства
Host normaldance-server
    HostName ${this.serverIP}
    User ${this.sshUser}
    IdentityFile ${path.join(process.env.HOME || require('os').homedir(), '.ssh', 'id_ed25519')}
    IdentitiesOnly yes
    StrictHostKeyChecking yes
    UserKnownHostsFile ~/.ssh/known_hosts
    PreferredAuthentications publickey
    ServerAliveInterval 60
    ServerAliveCountMax 3`;

        const configPath = path.join(process.env.HOME || require('os').homedir(), '.ssh', 'config');
        
        // Создаем директорию .ssh если не существует
        const sshDir = path.dirname(configPath);
        if (!fs.existsSync(sshDir)) {
            fs.mkdirSync(sshDir, { mode: 0o700 });
        }

        fs.writeFileSync(configPath, configContent);
        fs.chmodSync(configPath, 0o600);
        
        console.log('✅ SSH конфигурация создана:', configPath);
        return configPath;
    }

    async testConnection() {
        console.log('🔌 Тестирование подключения...');
        
        try {
            const { stdout } = await execAsync(`ssh -o BatchMode=yes -o ConnectTimeout=10 ${this.serverIP} "echo 'SSH подключение успешно'"`);
            console.log('✅ Подключение успешно:', stdout.trim());
            return true;
        } catch (error) {
            console.log('❌ Подключение не удалось:', error.message);
            return false;
        }
    }

    async addKeyWithSshCopyId(publicKey) {
        console.log('🔑 Попытка добавления ключа через ssh-copy-id...');
        
        try {
            await execAsync(`echo "${publicKey}" | ssh-copy-id -i "${this.keyPath}" ${this.sshUser}@${this.serverIP}`);
            console.log('✅ Ключ успешно добавлен через ssh-copy-id');
            return true;
        } catch (error) {
            console.log('❌ ssh-copy_id не сработал:', error.message);
            return false;
        }
    }

    async addKeyManual(publicKey) {
        console.log('🔧 Ручное добавление ключа...');
        
        const tempScript = `#!/bin/bash
mkdir -p ~/.ssh
echo '${publicKey}' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
echo 'Ключ успешно добавлен'
echo 'Текущее содержимое authorized_keys:'
cat ~/.ssh/authorized_keys`;

        try {
            // Для Windows используем sshpass, для Linux можно использовать expect
            if (process.platform === 'win32') {
                console.log('🪟 Windows обнаружен, требуется ручное добавление ключа');
                console.log('Пожалуйста, выполните эти команды на сервере:');
                console.log('1. ssh root@176.108.246.49');
                console.log('2. mkdir -p ~/.ssh');
                console.log('3. echo "' + publicKey.trim() + '" >> ~/.ssh/authorized_keys');
                console.log('4. chmod 600 ~/.ssh/authorized_keys');
                console.log('5. exit');
                return false;
            } else {
                // Для Linux/Mac можно использовать expect или запросить пароль
                console.log('🐧 Linux/Mac обнаружен');
                console.log('Пожалуйста, выполните:');
                console.log(`ssh ${this.sshUser}@${this.serverIP} "${tempScript}"`);
                return false;
            }
        } catch (error) {
            console.log('❌ Ручное добавление не удалось:', error.message);
            return false;
        }
    }

    async generateBackupKey() {
        console.log('🔄 Создание резервного RSA ключа...');
        
        const rsaKeyPath = path.join(process.env.HOME || require('os').homedir(), '.ssh', 'id_rsa');
        
        try {
            await execAsync(`ssh-keygen -t rsa -b 4096 -f "${rsaKeyPath}" -N ""`);
            console.log('✅ Резервный RSA ключ создан:', rsaKeyPath);
            return rsaKeyPath;
        } catch (error) {
            console.log('❌ Создание RSA ключа не удалось:', error.message);
            return null;
        }
    }

    async run() {
        console.log('🚀 Запуск SSH Key Adder...');
        console.log('=====================================');
        
        try {
            // Проверяем предпосылки
            const publicKey = await this.checkPrerequisites();
            
            // Генерируем конфигурацию
            await this.generateSSHConfig();
            
            // Тестируем подключение
            if (await this.testConnection()) {
                console.log('🎉 Подключение уже работает!');
                return true;
            }
            
            console.log('⚠️ Основное подключение не работает, пробуем альтернативные методы...');
            
            // Пробуем добавить ключ через ssh-copy-id
            if (await this.addKeyWithSshCopyId(publicKey)) {
                if (await this.testConnection()) {
                    console.log('🎉 Ключ успешно добавлен и подключение работает!');
                    return true;
                }
            }
            
            // Ручное добавление
            await this.addKeyManual(publicKey);
            
            // Создаем резервный ключ
            await this.generateBackupKey();
            
            console.log('=====================================');
            console.log('📋 Итог:');
            console.log('1. SSH конфигурация создана');
            console.log('2. Публичный ключ готов к добавлению');
            console.log('3. Резервный RSA ключ создан');
            console.log('');
            console.log('🔧 Следующие шаги:');
            console.log('1. Добавьте ваш Ed25519 ключ в ~/.ssh/authorized_keys на сервере');
            console.log('2. Или используйте RSA ключ: ssh -i ~/.ssh/id_rsa root@176.108.246.49');
            console.log('3. Проверьте права доступа: chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys');
            
            return false;
        } catch (error) {
            console.error('❌ Ошибка:', error.message);
            return false;
        }
    }
}

// Запуск скрипта
if (require.main === module) {
    const adder = new SSHKeyAdder();
    adder.run().then(success => {
        process.exit(success ? 0 : 1);
    }).catch(error => {
        console.error('Критическая ошибка:', error);
        process.exit(1);
    });
}

module.exports = SSHKeyAdder;