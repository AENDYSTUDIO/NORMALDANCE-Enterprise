#!/usr/bin/env node

/**
 * GitHub Access Manager - Безопасное управление SSH ключами и MCP доступом
 * NORMALDANCE Enterprise Security System
 */

const crypto = require("crypto");
const fs = require("fs").promises;
const path = require("path");
const { execSync } = require("child_process");

class GitHubAccessManager {
  constructor() {
    this.sshDir = path.join(
      process.env.HOME || process.env.USERPROFILE,
      ".ssh"
    );
    this.keysDir = path.join(__dirname, "..", ".secure-keys");
    this.configFile = path.join(
      __dirname,
      "..",
      "config",
      "github-access.json"
    );
    this.auditLog = path.join(
      __dirname,
      "..",
      "logs",
      "github-access-audit.log"
    );
  }

  /**
   * Инициализация системы безопасности
   */
  async initialize() {
    console.log("🔐 Инициализация GitHub Access Manager...");

    try {
      // Создание защищённых директорий
      await this.createSecureDirectories();

      // Проверка существующих ключей
      await this.auditExistingKeys();

      // Настройка SSH конфигурации
      await this.setupSSHConfig();

      console.log("✅ GitHub Access Manager инициализирован");
    } catch (error) {
      console.error("❌ Ошибка инициализации:", error.message);
      throw error;
    }
  }

  /**
   * Создание защищённых директорий
   */
  async createSecureDirectories() {
    const dirs = [
      this.keysDir,
      path.join(this.keysDir, "active"),
      path.join(this.keysDir, "archived"),
      path.join(__dirname, "..", "logs"),
      path.join(__dirname, "..", "config"),
    ];

    for (const dir of dirs) {
      try {
        await fs.mkdir(dir, { recursive: true, mode: 0o700 });
        console.log(`📁 Создана директория: ${dir}`);
      } catch (error) {
        if (error.code !== "EEXIST") throw error;
      }
    }
  }

  /**
   * Аудит существующих ключей
   */
  async auditExistingKeys() {
    console.log("🔍 Проверка существующих SSH ключей...");

    try {
      const sshFiles = await fs.readdir(this.sshDir).catch(() => []);
      const keyFiles = sshFiles.filter(
        (file) =>
          file.endsWith(".pub") ||
          (file.startsWith("id_") && !file.includes("."))
      );

      if (keyFiles.length > 0) {
        console.log(`📋 Найдено ${keyFiles.length} SSH ключей:`);
        keyFiles.forEach((file) => {
          console.log(`   - ${file}`);
        });
      } else {
        console.log("⚠️  SSH ключи не найдены");
      }

      // Логирование аудита
      await this.logAuditEvent("KEY_AUDIT", {
        keysFound: keyFiles.length,
        keyFiles: keyFiles,
      });
    } catch (error) {
      console.error("❌ Ошибка аудита ключей:", error.message);
    }
  }

  /**
   * Генерация нового SSH ключа
   */
  async generateSSHKey(keyName = "normaldance-github", keyType = "ed25519") {
    console.log(`🔑 Генерация нового SSH ключа: ${keyName}`);

    try {
      const keyPath = path.join(this.keysDir, "active", keyName);
      const publicKeyPath = `${keyPath}.pub`;

      // Генерация ключа
      const command = `ssh-keygen -t ${keyType} -f "${keyPath}" -C "normaldance-github-${Date.now()}" -N ""`;
      execSync(command, { stdio: "inherit" });

      // Чтение публичного ключа
      const publicKey = await fs.readFile(publicKeyPath, "utf8");

      // Логирование
      await this.logAuditEvent("KEY_GENERATED", {
        keyName: keyName,
        keyType: keyType,
        keyPath: keyPath,
      });

      console.log("✅ SSH ключ успешно сгенерирован");
      console.log("📋 Публичный ключ:");
      console.log(publicKey);

      return {
        privateKeyPath: keyPath,
        publicKeyPath: publicKeyPath,
        publicKey: publicKey.trim(),
      };
    } catch (error) {
      console.error("❌ Ошибка генерации ключа:", error.message);
      throw error;
    }
  }

  /**
   * Добавление SSH ключа в GitHub
   */
  async addKeyToGitHub(publicKey, title = "NORMALDANCE-Access") {
    console.log("🚀 Добавление ключа в GitHub...");

    try {
      // Проверка GitHub CLI
      try {
        execSync("gh --version", { stdio: "pipe" });
      } catch {
        throw new Error(
          "GitHub CLI не установлен. Установите: https://cli.github.com/"
        );
      }

      // Аутентификация в GitHub
      try {
        execSync("gh auth status", { stdio: "pipe" });
      } catch {
        console.log("🔐 Требуется аутентификация в GitHub CLI...");
        execSync("gh auth login", { stdio: "inherit" });
      }

      // Добавление ключа
      const command = `echo "${publicKey}" | gh ssh-key add - -t "${title}"`;
      execSync(command, { stdio: "inherit" });

      await this.logAuditEvent("KEY_ADDED_TO_GITHUB", {
        title: title,
        keyFingerprint: this.getKeyFingerprint(publicKey),
      });

      console.log("✅ Ключ успешно добавлен в GitHub");
      return true;
    } catch (error) {
      console.error("❌ Ошибка добавления ключа в GitHub:", error.message);
      throw error;
    }
  }

  /**
   * Настройка SSH конфигурации
   */
  async setupSSHConfig() {
    const sshConfigPath = path.join(this.sshDir, "config");
    const configContent = `
# NORMALDANCE GitHub Access Configuration
Host github.com
    HostName github.com
    User git
    IdentityFile ${path.join(this.keysDir, "active", "normaldance-github")}
    IdentitiesOnly yes
    AddKeysToAgent yes
    UseKeychain yes

Host github-normaldance
    HostName github.com
    User git
    IdentityFile ${path.join(this.keysDir, "active", "normaldance-github")}
    IdentitiesOnly yes
    AddKeysToAgent yes
    UseKeychain yes
`;

    try {
      await fs.writeFile(sshConfigPath, configContent, { mode: 0o600 });
      console.log("✅ SSH конфигурация обновлена");
    } catch (error) {
      console.error("❌ Ошибка настройки SSH:", error.message);
    }
  }

  /**
   * Настройка MCP для GitHub
   */
  async setupMCPGitHub() {
    console.log("🔧 Настройка MCP для GitHub...");

    const mcpConfig = {
      mcpServers: {
        github: {
          command: "npx",
          args: ["-y", "@modelcontextprotocol/server-github"],
          env: {
            GITHUB_PERSONAL_ACCESS_TOKEN: process.env.GITHUB_TOKEN || "",
          },
        },
      },
    };

    const mcpConfigPath = path.join(
      process.env.HOME || process.env.USERPROFILE,
      ".config",
      "mcp",
      "config.json"
    );

    try {
      await fs.mkdir(path.dirname(mcpConfigPath), { recursive: true });
      await fs.writeFile(mcpConfigPath, JSON.stringify(mcpConfig, null, 2));

      console.log("✅ MCP конфигурация создана");
      console.log(
        "📝 Установите GITHUB_TOKEN в переменные окружения для полного доступа"
      );
    } catch (error) {
      console.error("❌ Ошибка настройки MCP:", error.message);
    }
  }

  /**
   * Получение отпечатка ключа
   */
  getKeyFingerprint(publicKey) {
    try {
      const keyData = publicKey.split(" ")[1];
      const keyBuffer = Buffer.from(keyData, "base64");
      const hash = crypto.createHash("sha256").update(keyBuffer).digest("hex");
      return `SHA256:${hash}`;
    } catch (error) {
      return "unknown";
    }
  }

  /**
   * Логирование событий аудита
   */
  async logAuditEvent(event, data) {
    const logEntry = {
      timestamp: new Date().toISOString(),
      event: event,
      data: data,
      user: process.env.USER || process.env.USERNAME || "unknown",
    };

    try {
      await fs.appendFile(this.auditLog, JSON.stringify(logEntry) + "\n");
    } catch (error) {
      console.error("❌ Ошибка логирования:", error.message);
    }
  }

  /**
   * Проверка безопасности ключей
   */
  async securityCheck() {
    console.log("🛡️  Проверка безопасности...");

    const issues = [];

    // Проверка прав доступа к ключам
    try {
      const keyFiles = await fs.readdir(path.join(this.keysDir, "active"));
      for (const file of keyFiles) {
        const filePath = path.join(this.keysDir, "active", file);
        const stats = await fs.stat(filePath);

        if (stats.mode & 0o077) {
          issues.push(`Небезопасные права доступа к файлу: ${file}`);
        }
      }
    } catch (error) {
      issues.push(`Ошибка проверки прав доступа: ${error.message}`);
    }

    // Проверка устаревших ключей
    try {
      const archivedKeys = await fs.readdir(
        path.join(this.keysDir, "archived")
      );
      if (archivedKeys.length > 10) {
        issues.push("Слишком много архивных ключей. Рекомендуется очистка.");
      }
    } catch (error) {
      // Директория может не существовать
    }

    if (issues.length > 0) {
      console.log("⚠️  Обнаружены проблемы безопасности:");
      issues.forEach((issue) => console.log(`   - ${issue}`));
    } else {
      console.log("✅ Проверка безопасности пройдена");
    }

    return issues;
  }

  /**
   * Интерактивное меню
   */
  async interactiveMenu() {
    const readline = require("readline");
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
    });

    const question = (prompt) =>
      new Promise((resolve) => rl.question(prompt, resolve));

    console.log("\n🎵 NORMALDANCE GitHub Access Manager");
    console.log("=====================================");
    console.log("1. Генерировать новый SSH ключ");
    console.log("2. Добавить ключ в GitHub");
    console.log("3. Настроить MCP для GitHub");
    console.log("4. Проверить безопасность");
    console.log("5. Показать существующие ключи");
    console.log("6. Выход");

    const choice = await question("\nВыберите действие (1-6): ");

    switch (choice) {
      case "1":
        const keyName =
          (await question("Имя ключа (по умолчанию: normaldance-github): ")) ||
          "normaldance-github";
        const keyType =
          (await question(
            "Тип ключа (ed25519/rsa, по умолчанию: ed25519): "
          )) || "ed25519";
        await this.generateSSHKey(keyName, keyType);
        break;

      case "2":
        const publicKey = await question("Введите публичный ключ: ");
        const title =
          (await question("Название ключа в GitHub: ")) || "NORMALDANCE-Access";
        await this.addKeyToGitHub(publicKey, title);
        break;

      case "3":
        await this.setupMCPGitHub();
        break;

      case "4":
        await this.securityCheck();
        break;

      case "5":
        await this.auditExistingKeys();
        break;

      case "6":
        console.log("👋 До свидания!");
        break;

      default:
        console.log("❌ Неверный выбор");
    }

    rl.close();
  }
}

// Запуск менеджера
if (require.main === module) {
  const manager = new GitHubAccessManager();

  manager
    .initialize()
    .then(() => manager.interactiveMenu())
    .catch((error) => {
      console.error("❌ Критическая ошибка:", error.message);
      process.exit(1);
    });
}

module.exports = GitHubAccessManager;

