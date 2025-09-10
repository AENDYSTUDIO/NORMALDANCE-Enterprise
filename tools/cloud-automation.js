#!/usr/bin/env node

const { execSync } = require('child_process');

class CloudAutomation {
  static async setupEnvironment(env = 'production') {
    console.log(`🔧 Setting up ${env} environment...`);
    execSync(`kubectl create namespace ${env} --dry-run=client -o yaml | kubectl apply -f -`);
    execSync(`kubectl apply -f k8s/sealed-secrets.yaml -n ${env}`);
    console.log(`✅ ${env} environment ready`);
  }

  static async scaleApplication(replicas = 3) {
    console.log(`📈 Scaling to ${replicas} replicas...`);
    execSync(`kubectl scale deployment normaldance-app --replicas=${replicas}`);
    console.log('✅ Scaling complete');
  }

  static async backup() {
    const timestamp = new Date().toISOString().slice(0, 19).replace(/:/g, '-');
    console.log(`💾 Creating backup ${timestamp}...`);
    execSync(`kubectl exec deployment/postgres -- pg_dump normaldance > backup-${timestamp}.sql`);
    console.log('✅ Backup complete');
  }

  static async healthCheck() {
    try {
      execSync('kubectl get pods -l app=normaldance');
      console.log('✅ Health check passed');
    } catch (error) {
      console.error('❌ Health check failed');
      process.exit(1);
    }
  }
}

const command = process.argv[2];
const args = process.argv.slice(3);

switch (command) {
  case 'setup': CloudAutomation.setupEnvironment(args[0]); break;
  case 'scale': CloudAutomation.scaleApplication(parseInt(args[0])); break;
  case 'backup': CloudAutomation.backup(); break;
  case 'health': CloudAutomation.healthCheck(); break;
  default: console.log('Usage: node cloud-automation.js [setup|scale|backup|health]');
}