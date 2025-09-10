#!/usr/bin/env node

/**
 * Secret Rotation Script for NORMALDANCE
 * 
 * This script automatically rotates secrets for all environments,
 * generating new values and updating both Vercel and GitHub.
 * 
 * Usage:
 *   node scripts/rotate-secrets.js [options]
 * 
 * Options:
 *   --env <env>      Environment to rotate (dev, staging, production, all)
 *   --force          Force rotation without confirmation
 *   --dry-run        Show what would be rotated without actually rotating
 *   --notify         Send notifications after rotation
 *   --backup         Create backup before rotation
 *   --help          Show help message
 */

const fs = require('fs').promises;
const path = require('path');
const { execSync } = require('child_process');
const { SecretsTemplateManager } = require('../config/secrets-templates');
const crypto = require('crypto');

class SecretRotator {
  constructor() {
    this.templateManager = new SecretsTemplateManager();
    this.environments = ['dev', 'staging', 'production'];
    this.githubToken = process.env.GITHUB_TOKEN;
    this.owner = 'normaldance';
    this.repo = 'normaldance';
    this.notificationWebhook = process.env.SLACK_WEBHOOK;
    this.backupDir = path.join(__dirname, '../backups');
  }

  async run() {
    const args = process.argv.slice(2);
    
    if (args.length === 0) {
      this.showHelp();
      return;
    }

    const options = this.parseOptions(args);
    
    if (options.help) {
      this.showHelp();
      return;
    }

    try {
      console.log('🔄 Starting secret rotation...');
      
      // Validate environment
      if (options.environment !== 'all' && !this.environments.includes(options.environment)) {
        throw new Error(`Invalid environment: ${options.environment}`);
      }

      // Create backup directory if it doesn't exist
      await fs.mkdir(this.backupDir, { recursive: true });

      // Rotate secrets for specified environment(s)
      const environments = options.environment === 'all' ? this.environments : [options.environment];
      
      for (const env of environments) {
        await this.rotateEnvironmentSecrets(env, options);
      }

      console.log('✅ Secret rotation completed successfully!');
      
      // Send notifications
      if (options.notify) {
        await this.sendNotification(environments, options);
      }
    } catch (error) {
      console.error(`❌ Rotation failed: ${error.message}`);
      if (options.verbose) {
        console.error(error.stack);
      }
      process.exit(1);
    }
  }

  parseOptions(args) {
    const options = {
      environment: 'all',
      force: false,
      dryRun: false,
      notify: false,
      backup: true,
      verbose: false,
      help: false
    };

    for (let i = 0; i < args.length; i++) {
      const arg = args[i];
      
      switch (arg) {
        case '--env':
        case '-e':
          if (i + 1 < args.length) {
            const env = args[i + 1];
            if (env === 'all' || this.environments.includes(env)) {
              options.environment = env;
              i++;
            } else {
              console.error(`❌ Invalid environment: ${env}`);
              console.error(`Valid environments: all, ${this.environments.join(', ')}`);
              process.exit(1);
            }
          }
          break;
        case '--force':
        case '-f':
          options.force = true;
          break;
        case '--dry-run':
          options.dryRun = true;
          break;
        case '--notify':
          options.notify = true;
          break;
        case '--backup':
          options.backup = true;
          break;
        case '--verbose':
        case '-v':
          options.verbose = true;
          break;
        case '--help':
        case '-h':
          options.help = true;
          break;
        default:
          console.error(`❌ Unknown option: ${arg}`);
          process.exit(1);
      }
    }

    return options;
  }

  async rotateEnvironmentSecrets(environment, options) {
    console.log(`\n🔧 Rotating secrets for ${environment} environment...`);
    
    const template = this.templateManager.getTemplate(environment);
    if (!template) {
      throw new Error(`Template not found for environment: ${environment}`);
    }

    // Get current secrets
    const currentSecrets = await this.getCurrentSecrets(environment);
    
    // Create backup if requested
    if (options.backup) {
      await this.createBackup(environment, currentSecrets);
    }

    // Generate new secrets
    const newSecrets = await this.generateNewSecrets(environment, currentSecrets);
    
    // Show what will be rotated
    if (options.dryRun) {
      console.log('\n[DRY RUN] Secrets that would be rotated:');
      for (const [key, newValue] of Object.entries(newSecrets)) {
        const oldValue = currentSecrets[key] || 'Not set';
        console.log(`  ${key}: ${this.maskSecretValue(key, oldValue)} → ${this.maskSecretValue(key, newValue)}`);
      }
      return;
    }

    // Update Vercel secrets
    await this.updateVercelSecrets(environment, newSecrets);
    
    // Update GitHub secrets
    if (this.githubToken) {
      await this.updateGitHubSecrets(environment, newSecrets);
    }

    // Log the rotation
    await this.logRotation(environment, currentSecrets, newSecrets);
    
    console.log(`✅ Rotated ${Object.keys(newSecrets).length} secrets in ${environment}`);
  }

  async getCurrentSecrets(environment) {
    try {
      const output = execSync(`vercel env pull ${environment}`, { encoding: 'utf8' });
      return this.parseSecretsOutput(output);
    } catch (error) {
      // If no secrets exist, return empty object
      return {};
    }
  }

  async generateNewSecrets(environment, currentSecrets) {
    const template = this.templateManager.getTemplate(environment);
    const newSecrets = {};
    
    for (const [key, config] of Object.entries(template.secrets)) {
      if (config.generator) {
        // Use generator to create new secret
        newSecrets[key] = config.generator();
      } else if (config.default) {
        // Use default value
        newSecrets[key] = config.default;
      } else {
        // Keep current value if no generator or default
        newSecrets[key] = currentSecrets[key] || '';
      }
    }
    
    return newSecrets;
  }

  async updateVercelSecrets(environment, secrets) {
    for (const [key, value] of Object.entries(secrets)) {
      try {
        // Remove existing secret
        execSync(`vercel env rm ${environment} ${key}`, { stdio: 'ignore' });
        
        // Add new secret
        execSync(`vercel env add ${environment} ${key}`, { 
          stdio: 'pipe',
          input: `${value}\n`,
          encoding: 'utf8'
        });
        
        console.log(`  ✅ Updated ${key} in Vercel ${environment}`);
      } catch (error) {
        console.error(`  ❌ Failed to update ${key}: ${error.message}`);
      }
    }
  }

  async updateGitHubSecrets(environment, secrets) {
    if (!this.githubToken) {
      console.log('  ⚠️  GitHub token not available, skipping GitHub secret update');
      return;
    }

    for (const [key, value] of Object.entries(secrets)) {
      try {
        const encryptedValue = this.encryptSecretValue(value);
        
        const response = await axios.put(
          `https://api.github.com/repos/${this.owner}/${this.repo}/actions/secrets/${key}`,
          {
            encrypted_value: encryptedValue,
            key_id: process.env.GITHUB_SECRET_KEY_ID
          },
          {
            headers: {
              'Authorization': `token ${this.githubToken}`,
              'Accept': 'application/vnd.github.v3+json',
              'Content-Type': 'application/json'
            }
          }
        );
        
        console.log(`  ✅ Updated ${key} in GitHub`);
      } catch (error) {
        console.error(`  ❌ Failed to update GitHub secret ${key}: ${error.message}`);
      }
    }
  }

  async createBackup(environment, secrets) {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const backupFile = path.join(this.backupDir, `secrets-${environment}-${timestamp}.json`);
    
    const backup = {
      environment,
      timestamp,
      secrets: secrets,
      checksum: this.calculateChecksum(secrets)
    };
    
    await fs.writeFile(backupFile, JSON.stringify(backup, null, 2));
    console.log(`  💾 Created backup: ${backupFile}`);
  }

  encryptSecretValue(value) {
    const crypto = require('crypto');
    const algorithm = 'aes-256-cbc';
    const key = crypto.createHash('sha256').update(process.env.GITHUB_SECRET_KEY || 'default-key').digest('base64').substr(0, 32);
    const iv = crypto.randomBytes(16);
    
    const cipher = crypto.createCipher(algorithm, key);
    let encrypted = cipher.update(value, 'utf8', 'hex');
    encrypted += cipher.final('hex');
    
    return encrypted;
  }

  calculateChecksum(data) {
    const crypto = require('crypto');
    const stringData = typeof data === 'string' ? data : JSON.stringify(data);
    return crypto.createHash('sha256').update(stringData).digest('hex');
  }

  async logRotation(environment, oldSecrets, newSecrets) {
    const logEntry = {
      timestamp: new Date().toISOString(),
      environment,
      action: 'rotate',
      secrets: Object.keys(newSecrets).map(key => ({
        key,
        oldValue: this.maskSecretValue(key, oldSecrets[key]),
        newValue: this.maskSecretValue(key, newSecrets[key])
      }))
    };
    
    const logFile = path.join(__dirname, '../secrets-rotation.log');
    await fs.appendFile(logFile, JSON.stringify(logEntry) + '\n');
  }

  async sendNotification(environments, options) {
    if (!this.notificationWebhook) {
      console.log('  ⚠️  No notification webhook configured');
      return;
    }

    const message = {
      text: '🔄 Secret Rotation Completed',
      attachments: [
        {
          color: 'good',
          fields: [
            {
              title: 'Environments',
              value: environments.join(', '),
              short: true
            },
            {
              title: 'Status',
              value: '✅ Completed successfully',
              short: true
            },
            {
              title: 'Timestamp',
              value: new Date().toISOString(),
              short: false
            }
          ]
        }
      ]
    };

    try {
      await axios.post(this.notificationWebhook, message);
      console.log('  ✅ Notification sent');
    } catch (error) {
      console.error(`  ❌ Failed to send notification: ${error.message}`);
    }
  }

  maskSecretValue(key, value) {
    const sensitiveKeys = ['password', 'secret', 'key', 'token', 'dsn'];
    const isSensitive = sensitiveKeys.some(sensitive => key.toLowerCase().includes(sensitive));
    return isSensitive ? '***' : value;
  }

  parseSecretsOutput(output) {
    const secrets = {};
    const lines = output.split('\n');
    
    for (const line of lines) {
      const match = line.match(/^(\w+)=(.+)$/);
      if (match) {
        secrets[match[1]] = match[2];
      }
    }
    
    return secrets;
  }

  showHelp() {
    console.log(`
Secret Rotation Script for NORMALDANCE

Usage: node scripts/rotate-secrets.js [options]

Options:
  --env, -e <env>      Environment to rotate (dev, staging, production, all)
  --force, -f          Force rotation without confirmation
  --dry-run           Show what would be rotated without actually rotating
  --notify            Send notifications after rotation
  --backup            Create backup before rotation
  --verbose, -v        Enable verbose output
  --help, -h          Show help message

Examples:
  node scripts/rotate-secrets.js --env production
  node scripts/rotate-secrets.js --env all --force --notify
  node scripts/rotate-secrets.js --env staging --dry-run
  node scripts/rotate-secrets.js --env dev --backup --notify
    `);
  }
}

// Run the script
if (require.main === module) {
  const rotator = new SecretRotator();
  rotator.run();
}

module.exports = SecretRotator;