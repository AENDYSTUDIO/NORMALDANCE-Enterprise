#!/usr/bin/env node

/**
 * Hardcoded Secrets Checker for NORMALDANCE
 * 
 * This script scans the codebase for hardcoded secrets, API keys, passwords,
 * and other sensitive information that should be moved to environment variables.
 * 
 * Usage:
 *   node scripts/check-hardcoded-secrets.js [options]
 * 
 * Options:
 *   --env <env>      Environment to check against (dev, staging, production)
 *   --output <file>  Output file for results
 *   --format <fmt>   Output format (json, text, csv)
 *   --verbose        Enable verbose output
 *   --help          Show help message
 */

const fs = require('fs').promises;
const path = require('path');
const { execSync } = require('child_process');
const { SecretsTemplateManager } = require('../config/secrets-templates');

class HardcodedSecretsChecker {
  constructor() {
    this.templateManager = new SecretsTemplateManager();
    this.environments = ['dev', 'staging', 'production'];
    this.secretsPatterns = [
      // API Keys
      /(?:api[_-]?key|apikey|apikey|access[_-]?key|accesskey)\s*[:=]\s*['"]([a-zA-Z0-9_-]{20,})['"]/gi,
      /(?:api[_-]?secret|apisecret|secret[_-]?key|secretkey)\s*[:=]\s*['"]([a-zA-Z0-9_-]{20,})['"]/gi,
      /(?:bearer[_-]?token|bearertoken|auth[_-]?token|authtoken)\s*[:=]\s*['"]([a-zA-Z0-9_-]{20,})['"]/gi,
      
      // Database URLs
      /(?:database[_-]?url|dburl|databaseurl)\s*[:=]\s*['"](postgresql:\/\/|mysql:\/\/|mongodb:\/\/|sqlite:\/\/)([^'"]+)['"]/gi,
      /(?:database[_-]?connection|dbconnection|databaseconnection)\s*[:=]\s*['"](postgresql:\/\/|mysql:\/\/|mongodb:\/\/|sqlite:\/\/)([^'"]+)['"]/gi,
      
      // Passwords
      /(?:password|pwd|pass)\s*[:=]\s*['"]([^'"]{8,})['"]/gi,
      /(?:secret|pwd|pass)\s*[:=]\s*['"]([^'"]{8,})['"]/gi,
      
      // JWT Tokens
      /(?:jwt[_-]?secret|jwtsecret|token[_-]?secret|tokensecret)\s*[:=]\s*['"]([a-zA-Z0-9_-]{20,})['"]/gi,
      
      // AWS Credentials
      /(?:aws[_-]?access[_-]?key|awsaccesskey|aws[_-]?secret[_-]?access[_-]?key|awssecretaccesskey)\s*[:=]\s*['"]([A-Z0-9]{20,})['"]/gi,
      /(?:aws[_-]?secret[_-]?key|awssecretkey|aws[_-]?secret[_-]?access[_-]?key|awssecretaccesskey)\s*[:=]\s*['"]([a-zA-Z0-9\/+=]{20,})['"]/gi,
      
      // Generic patterns
      /['"]([a-zA-Z0-9\/+=]{20,})['"]/gi,
      /([A-Z0-9]{20,})/g,
      
      // Common secret prefixes
      /(?:sk_|pk_|whsec_|whsec|pk_test|pk_live|sk_test|sk_live)[a-zA-Z0-9\/+=_-]{20,}/g,
      
      // Hexadecimal secrets
      /(?:0x)?[a-fA-F0-9]{32,}/g,
      
      // Base64 encoded strings
      /(?:[A-Za-z0-9+\/]{4}){2,}(?:[A-Za-z0-9+\/]{3}=|[A-Za-z0-9+\/]{2}==)?/g
    ];
    
    this.fileExtensions = [
      '.js', '.ts', '.jsx', '.tsx', '.json', '.env', '.config.js', '.config.ts',
      '.env.example', '.env.local', '.env.development', '.env.staging', '.env.production'
    ];
    
    this.excludePatterns = [
      /node_modules/,
      /dist/,
      /build/,
      /\.git/,
      /coverage/,
      /\.next/,
      /vercel/
    ];
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
      console.log('🔍 Starting hardcoded secrets check...');
      
      // Scan the codebase
      const results = await this.scanCodebase();
      
      // Filter results by environment
      const filteredResults = this.filterByEnvironment(results, options.environment);
      
      // Generate report
      const report = this.generateReport(filteredResults, options.format);
      
      // Output results
      if (options.output) {
        await this.writeReport(report, options.output);
        console.log(`✅ Report saved to: ${options.output}`);
      } else {
        console.log(report);
      }
      
      // Exit with appropriate code
      if (filteredResults.length > 0) {
        console.log(`\n❌ Found ${filteredResults.length} potential hardcoded secrets`);
        process.exit(1);
      } else {
        console.log('\n✅ No hardcoded secrets found');
        process.exit(0);
      }
    } catch (error) {
      console.error(`❌ Check failed: ${error.message}`);
      if (options.verbose) {
        console.error(error.stack);
      }
      process.exit(1);
    }
  }

  parseOptions(args) {
    const options = {
      environment: 'production',
      output: null,
      format: 'text',
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
            if (this.environments.includes(env)) {
              options.environment = env;
              i++;
            } else {
              console.error(`❌ Invalid environment: ${env}`);
              console.error(`Valid environments: ${this.environments.join(', ')}`);
              process.exit(1);
            }
          }
          break;
        case '--output':
        case '-o':
          if (i + 1 < args.length) {
            options.output = args[i + 1];
            i++;
          }
          break;
        case '--format':
        case '-f':
          if (i + 1 < args.length) {
            const format = args[i + 1].toLowerCase();
            if (['json', 'text', 'csv'].includes(format)) {
              options.format = format;
              i++;
            } else {
              console.error(`❌ Invalid format: ${format}`);
              console.error(`Valid formats: json, text, csv`);
              process.exit(1);
            }
          }
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

  async scanCodebase() {
    const results = [];
    const rootDir = process.cwd();
    
    // Get all files to scan
    const files = await this.getFilesToScan(rootDir);
    
    console.log(`📁 Scanning ${files.length} files...`);
    
    for (const file of files) {
      try {
        const content = await fs.readFile(file, 'utf8');
        const fileResults = this.scanFile(file, content);
        results.push(...fileResults);
      } catch (error) {
        if (options.verbose) {
          console.log(`⚠️  Could not read file: ${file}`);
        }
      }
    }
    
    return results;
  }

  async getFilesToScan(rootDir) {
    const files = [];
    
    async function scanDirectory(dir) {
      try {
        const items = await fs.readdir(dir, { withFileTypes: true });
        
        for (const item of items) {
          const fullPath = path.join(dir, item.name);
          
          // Skip excluded directories
          if (this.excludePatterns.some(pattern => pattern.test(fullPath))) {
            continue;
          }
          
          if (item.isDirectory()) {
            await scanDirectory(fullPath);
          } else if (item.isFile() && this.fileExtensions.includes(path.extname(fullPath))) {
            files.push(fullPath);
          }
        }
      } catch (error) {
        // Skip directories we can't read
      }
    }
    
    await scanDirectory(rootDir);
    return files;
  }

  scanFile(filePath, content) {
    const results = [];
    const relativePath = path.relative(process.cwd(), filePath);
    
    for (const pattern of this.secretsPatterns) {
      const matches = content.matchAll(pattern);
      
      for (const match of matches) {
        const secret = match[0] || match[1];
        const line = content.substring(0, content.lastIndexOf('\n', match.index)).split('\n').length;
        const column = match.index - content.lastIndexOf('\n', match.index - 1);
        
        // Skip common false positives
        if (this.isFalsePositive(secret)) {
          continue;
        }
        
        results.push({
          file: relativePath,
          line,
          column,
          secret: this.maskSecret(secret),
          secretType: this.identifySecretType(secret),
          confidence: this.calculateConfidence(secret, relativePath),
          suggestion: this.generateSuggestion(secret, relativePath)
        });
      }
    }
    
    return results;
  }

  isFalsePositive(secret) {
    const falsePositives = [
      // Common strings that look like secrets but aren't
      'undefined',
      'null',
      'true',
      'false',
      'localhost',
      '127.0.0.1',
      '0.0.0.0',
      'example.com',
      'test.com',
      'localhost:3000',
      'http://localhost',
      'https://localhost',
      'webpack',
      'babel',
      'eslint',
      'prettier',
      'node_modules',
      'package.json',
      'README',
      'TODO',
      'FIXME',
      'DEBUG',
      'INFO',
      'WARN',
      'ERROR',
      // Common hex values
      'ffffffff',
      '00000000',
      '1234567890abcdef',
      'abcdef1234567890',
      // Common base64 strings
      'YmFzZTY0IGVuY29kZWQg',
      'dGVzdCBzdHJpbmc=',
      'c2VjcmV0IGRhdGE=',
      // Common JWT patterns
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9',
      'eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ'
    ];
    
    return falsePositives.some(fp => secret.toLowerCase().includes(fp.toLowerCase()));
  }

  identifySecretType(secret) {
    const lowerSecret = secret.toLowerCase();
    
    if (lowerSecret.includes('api') && lowerSecret.includes('key')) return 'API Key';
    if (lowerSecret.includes('secret') || lowerSecret.includes('token')) return 'Secret Token';
    if (lowerSecret.includes('password') || lowerSecret.includes('pwd')) return 'Password';
    if (lowerSecret.includes('database') || lowerSecret.includes('db')) return 'Database URL';
    if (lowerSecret.includes('aws') && lowerSecret.includes('key')) return 'AWS Credential';
    if (lowerSecret.includes('jwt') || lowerSecret.includes('token')) return 'JWT Token';
    if (lowerSecret.includes('solana') || lowerSecret.includes('rpc')) return 'Solana RPC';
    if (lowerSecret.includes('redis') || lowerSecret.includes('cache')) return 'Redis URL';
    if (lowerSecret.includes('email') || lowerSecret.includes('smtp')) return 'Email Credential';
    if (lowerSecret.includes('cloudflare') || lowerSecret.includes('cdn')) return 'Cloudflare Token';
    if (lowerSecret.includes('pinata') || lowerSecret.includes('ipfs')) return 'IPFS Token';
    if (lowerSecret.includes('google') && lowerSecret.includes('analytics')) return 'Google Analytics';
    if (lowerSecret.includes('mixpanel')) return 'Mixpanel Token';
    if (lowerSecret.includes('sentry')) return 'Sentry DSN';
    if (lowerSecret.includes('datadog')) return 'Datadog API Key';
    
    return 'Unknown';
  }

  calculateConfidence(secret, filePath) {
    let confidence = 0;
    
    // Higher confidence for longer secrets
    if (secret.length > 32) confidence += 30;
    if (secret.length > 64) confidence += 20;
    
    // Higher confidence for secrets in config files
    if (filePath.includes('config') || filePath.includes('env')) confidence += 25;
    
    // Higher confidence for secrets in source files
    if (filePath.includes('src') && !filePath.includes('test')) confidence += 15;
    
    // Higher confidence for secrets with specific patterns
    if (secret.match(/^[a-zA-Z0-9\/+=_-]{20,}$/)) confidence += 20;
    if (secret.match(/^[A-Z0-9]{20,}$/)) confidence += 15;
    
    // Lower confidence for secrets in test files
    if (filePath.includes('test')) confidence -= 20;
    
    return Math.min(100, Math.max(0, confidence));
  }

  generateSuggestion(secret, filePath) {
    const template = this.templateManager.getTemplate('production');
    const secretType = this.identifySecretType(secret);
    
    // Find matching environment variable
    for (const [key, config] of Object.entries(template.secrets)) {
      if (config.description.toLowerCase().includes(secretType.toLowerCase())) {
        return `Replace with environment variable: ${key}`;
      }
    }
    
    // Generic suggestions
    const suggestions = {
      'API Key': 'Use environment variable: API_KEY or create appropriate secret variable',
      'Secret Token': 'Use environment variable: SECRET_TOKEN or create appropriate secret variable',
      'Password': 'Use environment variable: PASSWORD or create appropriate secret variable',
      'Database URL': 'Use environment variable: DATABASE_URL',
      'AWS Credential': 'Use environment variables: AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY',
      'JWT Token': 'Use environment variable: JWT_SECRET',
      'Solana RPC': 'Use environment variable: SOLANA_RPC_URL',
      'Redis URL': 'Use environment variable: REDIS_URL',
      'Email Credential': 'Use environment variables: EMAIL_HOST, EMAIL_USER, EMAIL_PASS',
      'Cloudflare Token': 'Use environment variable: CLOUDFLARE_API_TOKEN',
      'IPFS Token': 'Use environment variables: PINATA_API_KEY and PINATA_SECRET_API_KEY',
      'Google Analytics': 'Use environment variable: GOOGLE_ANALYTICS_ID',
      'Mixpanel Token': 'Use environment variable: MIXPANEL_TOKEN',
      'Sentry DSN': 'Use environment variable: SENTRY_DSN',
      'Datadog API Key': 'Use environment variable: DATADOG_API_KEY'
    };
    
    return suggestions[secretType] || 'Move to environment variable';
  }

  maskSecret(secret) {
    const sensitiveTypes = ['Password', 'Secret Token', 'API Key', 'AWS Credential'];
    const secretType = this.identifySecretType(secret);
    
    if (sensitiveTypes.includes(secretType)) {
      return secret.substring(0, 8) + '*'.repeat(Math.max(4, secret.length - 8));
    }
    
    return secret;
  }

  filterByEnvironment(results, environment) {
    const template = this.templateManager.getTemplate(environment);
    if (!template) return results;
    
    const requiredSecrets = this.templateManager.getRequiredSecrets(environment);
    
    return results.filter(result => {
      // Keep results that don't match any environment variable
      const matchesEnvVar = requiredSecrets.some(secret => 
        result.secret.toLowerCase().includes(secret.toLowerCase())
      );
      
      return !matchesEnvVar;
    });
  }

  generateReport(results, format) {
    switch (format) {
      case 'json':
        return JSON.stringify(results, null, 2);
      case 'csv':
        return this.generateCSVReport(results);
      case 'text':
      default:
        return this.generateTextReport(results);
    }
  }

  generateTextReport(results) {
    if (results.length === 0) {
      return '✅ No hardcoded secrets found';
    }
    
    let report = `🔍 Hardcoded Secrets Report\n`;
    report += `============================\n\n`;
    report += `Found ${results.length} potential hardcoded secrets:\n\n`;
    
    // Group by file
    const files = {};
    for (const result of results) {
      if (!files[result.file]) {
        files[result.file] = [];
      }
      files[result.file].push(result);
    }
    
    for (const [file, fileResults] of Object.entries(files)) {
      report += `📁 ${file}\n`;
      report += `${'─'.repeat(file.length + 2)}\n`;
      
      for (const result of fileResults) {
        report += `  Line ${result.line}, Column ${result.column}\n`;
        report += `    Type: ${result.secretType}\n`;
        report += `    Confidence: ${result.confidence}%\n`;
        report += `    Secret: ${result.secret}\n`;
        report += `    Suggestion: ${result.suggestion}\n`;
        report += `    \n`;
      }
    }
    
    return report;
  }

  generateCSVReport(results) {
    const headers = ['File', 'Line', 'Column', 'Secret Type', 'Confidence', 'Secret', 'Suggestion'];
    const rows = results.map(result => [
      result.file,
      result.line,
      result.column,
      result.secretType,
      result.confidence,
      result.secret,
      result.suggestion
    ]);
    
    return [headers, ...rows]
      .map(row => row.map(cell => `"${cell}"`).join(','))
      .join('\n');
  }

  async writeReport(report, outputPath) {
    const dir = path.dirname(outputPath);
    await fs.mkdir(dir, { recursive: true });
    await fs.writeFile(outputPath, report);
  }

  showHelp() {
    console.log(`
Hardcoded Secrets Checker for NORMALDANCE

Usage: node scripts/check-hardcoded-secrets.js [options]

Options:
  --env, -e <env>      Environment to check against (dev, staging, production)
  --output, -o <file>  Output file for results
  --format, -f <fmt>   Output format (json, text, csv)
  --verbose, -v        Enable verbose output
  --help, -h          Show help message

Examples:
  node scripts/check-hardcoded-secrets.js --env production
  node scripts/check-hardcoded-secrets.js --env staging --output report.json --format json
  node scripts/check-hardcoded-secrets.js --env dev --output report.csv --format csv
    `);
  }
}

// Run the script
if (require.main === module) {
  const checker = new HardcodedSecretsChecker();
  checker.run();
}

module.exports = HardcodedSecretsChecker;