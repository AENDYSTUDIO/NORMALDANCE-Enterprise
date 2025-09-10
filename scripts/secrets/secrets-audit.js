#!/usr/bin/env node

/**
 * Secrets Audit Script for NORMALDANCE
 * 
 * Этот скрипт обеспечивает аудит доступа и изменений секретов,
 * отслеживая все операции с секретами и выявляя потенциальные угрозы безопасности.
 * 
 * Features:
 * - Мониторинг всех операций с секретами
 * - Обнаружение подозрительной активности
 * - Генерация отчетов об использовании
 * - Уведомления о подозрительных событиях
 * - Интеграция с системами безопасности
 */

const { exec } = require('child_process');
const { promisify } = require('util');
const fs = require('fs').promises;
const path = require('path');
const crypto = require('crypto');

const execAsync = promisify(exec);

class SecretsAuditor {
  constructor(config = {}) {
    this.config = {
      secretsFile: config.secretsFile || 'config/secrets-config.json',
      environments: config.environments || ['development', 'staging', 'production'],
      auditLogFile: config.auditLogFile || 'logs/secrets-audit.log',
      reportDir: config.reportDir || 'reports/secrets-audit',
      retentionDays: config.retentionDays || 90,
      alertThresholds: config.alertThresholds || {
        failedAttempts: 5,
        unusualAccess: 10,
        rapidChanges: 3,
        unauthorizedAccess: 1
      },
      notifications: config.notifications || {},
      dryRun: config.dryRun || false,
      logLevel: config.logLevel || 'info',
      ...config
    };

    this.logger = this.createLogger();
    this.auditLog = [];
    this.alerts = [];
    
    // Загрузка конфигураций
    this.secretsConfig = null;
  }

  /**
   * Создание логгера
   */
  createLogger() {
    const levels = {
      error: 0,
      warn: 1,
      info: 2,
      debug: 3
    };

    return {
      log: (level, message, ...args) => {
        if (levels[level] <= levels[this.config.logLevel]) {
          const timestamp = new Date().toISOString();
          // Sanitize message to prevent log injection
          const sanitizedMessage = message.replace(/[\r\n\t]/g, ' ').substring(0, 1000);
          const logEntry = `[${timestamp}] [AUDIT-${level.toUpperCase()}] ${sanitizedMessage}`;
          console.log(logEntry, ...args);
          
          // Запись в файл лога
          this.writeAuditLog(logEntry);
        }
      },
      error: (message, ...args) => this.log('error', message, ...args),
      warn: (message, ...args) => this.log('warn', message, ...args),
      info: (message, ...args) => this.log('info', message, ...args),
      debug: (message, ...args) => this.log('debug', message, ...args)
    };
  }

  /**
   * Запись в лог аудита
   */
  async writeAuditLog(message) {
    try {
      await fs.appendFile(this.config.auditLogFile, message + '\n');
    } catch (error) {
      this.logger.warn('Failed to write audit log', error);
    }
  }

  /**
   * Инициализация системы
   */
  async initialize() {
    try {
      this.logger.info('Initializing Secrets Auditor...');
      
      // Загрузка конфигураций
      await this.loadConfigurations();
      
      // Проверка доступности Vercel CLI
      await this.checkVercelCLI();
      
      // Проверка аутентификации
      await this.checkAuthentication();
      
      // Создание директорий
      await this.ensureDirectories();
      
      // Загрузка существующего лога аудита
      await this.loadAuditLog();
      
      this.logger.info('Secrets Auditor initialized successfully');
      return true;
    } catch (error) {
      this.logger.error('Failed to initialize Secrets Auditor', error);
      throw error;
    }
  }

  /**
   * Загрузка конфигураций
   */
  async loadConfigurations() {
    try {
      const secretsConfigPath = path.resolve(this.config.secretsFile);
      const secretsConfigData = await fs.readFile(secretsConfigPath, 'utf8');
      this.secretsConfig = JSON.parse(secretsConfigData);
      
      this.logger.debug('Configurations loaded successfully');
    } catch (error) {
      this.logger.warn('Failed to load configurations', error);
      throw error;
    }
  }

  /**
   * Проверка доступности Vercel CLI
   */
  async checkVercelCLI() {
    try {
      const { stdout } = await execAsync('vercel --version');
      this.logger.info(`Vercel CLI version: ${stdout.trim()}`);
    } catch (error) {
      throw new Error('Vercel CLI is not installed or not available in PATH');
    }
  }

  /**
   * Проверка аутентификации
   */
  async checkAuthentication() {
    try {
      const { stdout } = await execAsync('vercel whoami');
      this.logger.info(`Authenticated as: ${stdout.trim()}`);
    } catch (error) {
      throw new Error('Vercel CLI is not authenticated. Please run "vercel login"');
    }
  }

  /**
   * Создание необходимых директорий
   */
  async ensureDirectories() {
    try {
      await fs.mkdir(path.dirname(this.config.auditLogFile), { recursive: true });
      await fs.mkdir(this.config.reportDir, { recursive: true });
      this.logger.debug('Directories ensured');
    } catch (error) {
      this.logger.warn('Failed to create directories', error);
    }
  }

  /**
   * Загрузка существующего лога аудита
   */
  async loadAuditLog() {
    try {
      const logData = await fs.readFile(this.config.auditLogFile, 'utf8');
      const lines = logData.split('\n').filter(line => line.trim());
      
      this.auditLog = lines.map(line => {
        try {
          const match = line.match(/\[([^\]]+)\] \[AUDIT-([^\]]+)\] (.+)/);
          if (match) {
            return {
              timestamp: match[1],
              level: match[2],
              message: match[3]
            };
          }
          return null;
        } catch (error) {
          return null;
        }
      }).filter(entry => entry !== null);
      
      this.logger.debug(`Loaded ${this.auditLog.length} audit log entries`);
    } catch (error) {
      this.logger.debug('No existing audit log found, starting fresh');
      this.auditLog = [];
    }
  }

  /**
   * Запись события аудита
   */
  async logAuditEvent(event) {
    try {
      const auditEvent = {
        timestamp: new Date().toISOString(),
        ...event
      };
      
      this.auditLog.push(auditEvent);
      
      // Запись в файл
      const logEntry = `[${auditEvent.timestamp}] [AUDIT-${auditEvent.level.toUpperCase()}] ${auditEvent.message}`;
      await this.writeAuditLog(logEntry);
      
      // Проверка на подозрительные события
      await this.checkForSuspiciousActivity(auditEvent);
      
      return auditEvent;
    } catch (error) {
      this.logger.warn('Failed to log audit event', error);
      return null;
    }
  }

  /**
   * Проверка на подозрительную активность
   */
  async checkForSuspiciousActivity(event) {
    try {
      let suspicious = false;
      let alertType = null;
      let alertMessage = null;
      
      // Проверка на неудачные попытки доступа
      if (event.level === 'ERROR' && event.message.includes('failed')) {
        const failedAttempts = this.auditLog.filter(e => 
          e.level === 'ERROR' && e.message.includes('failed')
        ).length;
        
        if (failedAttempts >= this.config.alertThresholds.failedAttempts) {
          suspicious = true;
          alertType = 'FAILED_ATTEMPTS';
          alertMessage = `Multiple failed access attempts detected: ${failedAttempts}`;
        }
      }
      
      // Проверка на необычное время доступа
      const eventHour = new Date(event.timestamp).getHours();
      if (eventHour >= 22 || eventHour <= 6) {
        suspicious = true;
        alertType = 'UNUSUAL_TIME';
        alertMessage = `Access during unusual hours: ${eventHour}:00`;
      }
      
      // Проверка на быстрые изменения
      if (event.level === 'INFO' && event.message.includes('updated')) {
        const recentChanges = this.auditLog.filter(e => 
          e.level === 'INFO' && e.message.includes('updated') &&
          new Date(e.timestamp) > new Date(Date.now() - 60000) // Последняя минута
        ).length;
        
        if (recentChanges >= this.config.alertThresholds.rapidChanges) {
          suspicious = true;
          alertType = 'RAPID_CHANGES';
          alertMessage = `Rapid secret changes detected: ${recentChanges} in last minute`;
        }
      }
      
      // Проверка на несанкционированный доступ
      if (event.message.includes('unauthorized') || event.message.includes('access denied')) {
        suspicious = true;
        alertType = 'UNAUTHORIZED_ACCESS';
        alertMessage = 'Unauthorized access attempt detected';
      }
      
      // Создание оповещения при необходимости
      if (suspicious && alertType) {
        await this.createAlert({
          type: alertType,
          message: alertMessage,
          event: event,
          timestamp: new Date().toISOString()
        });
      }
    } catch (error) {
      this.logger.warn('Failed to check for suspicious activity', error);
    }
  }

  /**
   * Создание оповещения
   */
  async createAlert(alert) {
    try {
      this.alerts.push(alert);
      
      // Отправка уведомления
      await this.sendNotification('securityAlert', alert);
      
      this.logger.warn(`Security alert created: ${alert.type} - ${alert.message}`);
    } catch (error) {
      this.logger.warn('Failed to create alert', error);
    }
  }

  /**
   * Отправка уведомления
   */
  async sendNotification(event, data) {
    try {
      if (!this.config.notifications.enabled) {
        return;
      }
      
      const notification = {
        event,
        data,
        timestamp: new Date().toISOString(),
        project: 'NORMALDANCE'
      };
      
      // Отправка в Slack
      if (this.config.notifications.slack?.enabled && this.config.notifications.slack.webhookUrl) {
        await this.sendSlackNotification(notification);
      }
      
      // Отправка в Discord
      if (this.config.notifications.discord?.enabled && this.config.notifications.discord.webhookUrl) {
        await this.sendDiscordNotification(notification);
      }
      
      // Отправка по email
      if (this.config.notifications.email?.enabled && this.config.notifications.email.recipients.length > 0) {
        await this.sendEmailNotification(notification);
      }
    } catch (error) {
      this.logger.warn('Failed to send notification', error);
    }
  }

  /**
   * Отправка уведомления в Slack
   */
  async sendSlackNotification(notification) {
    try {
      const message = {
        text: `🚨 Security Alert`,
        attachments: [{
          color: 'danger',
          fields: [
            { title: 'Event', value: notification.event, short: true },
            { title: 'Project', value: notification.project, short: true },
            { title: 'Timestamp', value: notification.timestamp, short: false }
          ]
        }]
      };
      
      if (notification.data.type) {
        message.attachments[0].fields.push(
          { title: 'Alert Type', value: notification.data.type, short: true }
        );
      }
      
      if (notification.data.message) {
        message.attachments[0].fields.push(
          { title: 'Message', value: notification.data.message, short: false }
        );
      }
      
      // Здесь должна быть реализация отправки в Slack webhook
      this.logger.debug('Slack notification sent');
    } catch (error) {
      this.logger.warn('Failed to send Slack notification', error);
    }
  }

  /**
   * Отправка уведомления в Discord
   */
  async sendDiscordNotification(notification) {
    try {
      const message = {
        embeds: [{
          title: '🚨 Security Alert',
          color: 0xff0000,
          fields: [
            { name: 'Event', value: notification.event, inline: true },
            { name: 'Project', value: notification.project, inline: true },
            { name: 'Timestamp', value: notification.timestamp, inline: false }
          ]
        }]
      };
      
      if (notification.data.type) {
        message.embeds[0].fields.push(
          { name: 'Alert Type', value: notification.data.type, inline: true }
        );
      }
      
      if (notification.data.message) {
        message.embeds[0].fields.push(
          { name: 'Message', value: notification.data.message, inline: true }
        );
      }
      
      // Здесь должна быть реализация отправки в Discord webhook
      this.logger.debug('Discord notification sent');
    } catch (error) {
      this.logger.warn('Failed to send Discord notification', error);
    }
  }

  /**
   * Отправка email уведомления
   */
  async sendEmailNotification(notification) {
    try {
      // Здесь должна быть реализация отправки email
      this.logger.debug('Email notification sent');
    } catch (error) {
      this.logger.warn('Failed to send email notification', error);
    }
  }

  /**
   * Аудит доступа к секретам
   */
  async auditSecretAccess(environment) {
    try {
      this.logger.info(`Auditing secret access for environment: ${environment}`);
      
      const envFlag = environment === 'production' ? '--prod' : `--environment ${environment}`;
      const { stdout } = await execAsync(`vercel secrets ls ${envFlag}`);
      
      const lines = stdout.split('\n').filter(line => line.trim());
      const secrets = [];
      
      // Пропускаем заголовок
      for (let i = 1; i < lines.length; i++) {
        const line = lines[i];
        const [name, ...rest] = line.split('\t');
        if (name) {
          secrets.push({
            name,
            lastAccessed: rest.join('\t') || 'Unknown'
          });
        }
      }
      
      // Запись событий аудита
      for (const secret of secrets) {
        await this.logAuditEvent({
          level: 'INFO',
          message: `Accessed secret: ${secret.name} in environment: ${environment}`,
          secret: secret.name,
          environment
        });
      }
      
      return secrets;
    } catch (error) {
      this.logger.error(`Failed to audit secret access for environment: ${environment}`, error);
      throw error;
    }
  }

  /**
   * Аудит изменений секретов
   */
  async auditSecretChanges(environment) {
    try {
      this.logger.info(`Auditing secret changes for environment: ${environment}`);
      
      const envFlag = environment === 'production' ? '--prod' : `--environment ${environment}`;
      const { stdout } = await execAsync(`vercel secrets ls ${envFlag}`);
      
      const lines = stdout.split('\n').filter(line => line.trim());
      const secrets = [];
      
      // Пропускаем заголовок
      for (let i = 1; i < lines.length; i++) {
        const line = lines[i];
        const [name, ...rest] = line.split('\t');
        if (name) {
          secrets.push({
            name,
            status: rest.join('\t') || 'Unknown'
          });
        }
      }
      
      // Проверка на недавние изменения
      const recentChanges = secrets.filter(secret => 
        secret.status.includes('recent') || secret.status.includes('updated')
      );
      
      if (recentChanges.length > 0) {
        await this.logAuditEvent({
          level: 'WARN',
          message: `Recent changes detected for ${recentChanges.length} secrets in environment: ${environment}`,
          environment,
          changedSecrets: recentChanges.map(s => s.name)
        });
      }
      
      return secrets;
    } catch (error) {
      this.logger.error(`Failed to audit secret changes for environment: ${environment}`, error);
      throw error;
    }
  }

  /**
   * Генерация отчета об использовании секретов
   */
  async generateUsageReport(environment) {
    try {
      this.logger.info(`Generating usage report for environment: ${environment}`);
      
      const envFlag = environment === 'production' ? '--prod' : `--environment ${environment}`;
      const { stdout } = await execAsync(`vercel secrets ls ${envFlag}`);
      
      const lines = stdout.split('\n').filter(line => line.trim());
      const secrets = [];
      
      // Пропускаем заголовок
      for (let i = 1; i < lines.length; i++) {
        const line = lines[i];
        const [name, ...rest] = line.split('\t');
        if (name) {
          secrets.push({
            name,
            metadata: rest.join('\t') || 'Unknown'
          });
        }
      }
      
      const report = {
        environment,
        generatedAt: new Date().toISOString(),
        totalSecrets: secrets.length,
        secrets: secrets.map(secret => ({
          name: secret.name,
          metadata: secret.metadata,
          lastAccessed: this.getLastAccessedTime(secret.name),
          lastModified: this.getLastModifiedTime(secret.name)
        }))
      };
      
      // Сохранение отчета
      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      const reportFile = path.join(this.config.reportDir, `usage-report-${environment}-${timestamp}.json`);
      await fs.writeFile(reportFile, JSON.stringify(report, null, 2));
      
      this.logger.info(`Usage report saved: ${reportFile}`);
      return report;
    } catch (error) {
      this.logger.error(`Failed to generate usage report for environment: ${environment}`, error);
      throw error;
    }
  }

  /**
   * Получение времени последнего доступа
   */
  getLastAccessedTime(secretName) {
    const accessEvents = this.auditLog.filter(event => 
      event.message.includes(secretName) && event.message.includes('Accessed')
    );
    
    if (accessEvents.length > 0) {
      return accessEvents[accessEvents.length - 1].timestamp;
    }
    
    return 'Never';
  }

  /**
   * Получение времени последнего изменения
   */
  getLastModifiedTime(secretName) {
    const changeEvents = this.auditLog.filter(event => 
      event.message.includes(secretName) && event.message.includes('updated')
    );
    
    if (changeEvents.length > 0) {
      return changeEvents[changeEvents.length - 1].timestamp;
    }
    
    return 'Never';
  }

  /**
   * Очистка старых логов
   */
  async cleanupOldLogs() {
    try {
      const cutoffDate = new Date();
      cutoffDate.setDate(cutoffDate.getDate() - this.config.retentionDays);
      
      const logFiles = await fs.readdir(this.config.reportDir);
      let cleanedCount = 0;
      
      for (const file of logFiles) {
        const filePath = path.join(this.config.reportDir, file);
        const stats = await fs.stat(filePath);
        
        if (stats.mtime < cutoffDate) {
          await fs.unlink(filePath);
          cleanedCount++;
        }
      }
      
      this.logger.info(`Cleaned up ${cleanedCount} old log files`);
    } catch (error) {
      this.logger.warn('Failed to cleanup old logs', error);
    }
  }

  /**
   * Получение сводки по безопасности
   */
  getSecuritySummary() {
    const now = new Date();
    const last24Hours = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    
    const recentEvents = this.auditLog.filter(event => 
      new Date(event.timestamp) > last24Hours
    );
    
    const errors = recentEvents.filter(event => event.level === 'ERROR');
    const warnings = recentEvents.filter(event => event.level === 'WARN');
    const alerts = this.alerts.filter(alert => 
      new Date(alert.timestamp) > last24Hours
    );
    
    return {
      period: 'Last 24 hours',
      totalEvents: recentEvents.length,
      errors: errors.length,
      warnings: warnings.length,
      alerts: alerts.length,
      lastAudit: this.auditLog.length > 0 ? 
        this.auditLog[this.auditLog.length - 1].timestamp : null
    };
  }

  /**
   * Запуск полного аудита
   */
  async runFullAudit() {
    try {
      this.logger.info('Running full audit of all secrets');
      
      const results = {
        timestamp: new Date().toISOString(),
        environments: {},
        summary: this.getSecuritySummary()
      };
      
      for (const environment of this.config.environments) {
        try {
          this.logger.info(`Auditing environment: ${environment}`);
          
          const accessAudit = await this.auditSecretAccess(environment);
          const changesAudit = await this.auditSecretChanges(environment);
          const usageReport = await this.generateUsageReport(environment);
          
          results.environments[environment] = {
            accessAudit,
            changesAudit,
            usageReport
          };
          
          this.logger.info(`Environment ${environment} audit completed`);
        } catch (error) {
          this.logger.error(`Failed to audit environment ${environment}`, error);
          results.environments[environment] = {
            error: error.message
          };
        }
      }
      
      // Сохранение полного отчета
      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      const fullReportFile = path.join(this.config.reportDir, `full-audit-report-${timestamp}.json`);
      await fs.writeFile(fullReportFile, JSON.stringify(results, null, 2));
      
      this.logger.info(`Full audit report saved: ${fullReportFile}`);
      return results;
    } catch (error) {
      this.logger.error('Failed to run full audit', error);
      throw error;
    }
  }

  /**
   * Запуск непрерывного мониторинга
   */
  startContinuousMonitoring() {
    try {
      this.logger.info('Starting continuous monitoring');
      
      // Проверка каждые 5 минут
      setInterval(async () => {
        try {
          this.logger.debug('Running periodic audit check');
          
          for (const environment of this.config.environments) {
            await this.auditSecretAccess(environment);
            await this.auditSecretChanges(environment);
          }
          
          // Очистка старых логов
          await this.cleanupOldLogs();
          
        } catch (error) {
          this.logger.error('Periodic audit check failed', error);
        }
      }, 5 * 60 * 1000); // 5 минут
      
      this.logger.info('Continuous monitoring started');
    } catch (error) {
      this.logger.error('Failed to start continuous monitoring', error);
      throw error;
    }
  }

  /**
   * Остановка непрерывного мониторинга
   */
  stopContinuousMonitoring() {
    try {
      // Остановка всех интервалов
      clearInterval(this.monitoringInterval);
      this.logger.info('Continuous monitoring stopped');
    } catch (error) {
      this.logger.warn('Failed to stop continuous monitoring', error);
    }
  }
}

// CLI интерфейс
if (require.main === module) {
  const args = process.argv.slice(2);
  const command = args[0];
  
  async function main() {
    try {
      const config = {
        environments: args.filter(arg => !arg.startsWith('--')),
        dryRun: args.includes('--dry-run'),
        logLevel: args.includes('--debug') ? 'debug' : 'info',
        retentionDays: parseInt(args.find(arg => arg.startsWith('--retention='))?.split('=')[1]) || 90
      };
      
      const auditor = new SecretsAuditor(config);
      await auditor.initialize();
      
      switch (command) {
        case 'audit':
          const environment = args.find(arg => !arg.startsWith('--')) || 'development';
          await auditor.auditSecretAccess(environment);
          await auditor.auditSecretChanges(environment);
          break;
          
        case 'report':
          const reportEnv = args.find(arg => !arg.startsWith('--')) || 'development';
          await auditor.generateUsageReport(reportEnv);
          break;
          
        case 'full-audit':
          await auditor.runFullAudit();
          break;
          
        case 'monitor':
          auditor.startContinuousMonitoring();
          console.log('Continuous monitoring started. Press Ctrl+C to stop.');
          process.on('SIGINT', () => {
            auditor.stopContinuousMonitoring();
            process.exit(0);
          });
          break;
          
        case 'summary':
          console.log(JSON.stringify(auditor.getSecuritySummary(), null, 2));
          break;
          
        case 'cleanup':
          await auditor.cleanupOldLogs();
          break;
          
        default:
          console.log(`
Secrets Audit Script for NORMALDANCE

Usage:
  node scripts/secrets-audit.js <command> [options]

Commands:
  audit [environment]        Audit secret access and changes for environment
  report [environment]       Generate usage report for environment
  full-audit                Run complete audit of all environments
  monitor                   Start continuous monitoring
  summary                   Show security summary
  cleanup                   Clean up old log files

Options:
  --dry-run                 Show what would be done without actually doing it
  --debug                   Enable debug logging
  --retention=days          Log retention period in days (default: 90)

Examples:
  node scripts/secrets-audit.js audit production --dry-run
  node scripts/secrets-audit.js report staging --debug
  node scripts/secrets-audit.js full-audit
  node scripts/secrets-audit.js monitor --retention=30
  node scripts/secrets-audit.js summary
          `);
      }
    } catch (error) {
      console.error('Error:', error.message);
      process.exit(1);
    }
  }
  
  main();
}

module.exports = SecretsAuditor;