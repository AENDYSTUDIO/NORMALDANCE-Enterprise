#!/usr/bin/env node

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Configuration
const config = {
  environments: {
    development: {
      dockerCompose: 'docker-compose.dev.yml',
      namespace: 'normaldance-dev',
      replicas: 1
    },
    staging: {
      dockerCompose: 'docker-compose.staging.yml',
      namespace: 'normaldance-staging',
      replicas: 2
    },
    production: {
      dockerCompose: 'docker-compose.prod.yml',
      namespace: 'normaldance-prod',
      replicas: 3
    }
  },
  kubernetes: {
    configPath: './k8s',
    manifests: {
      app: 'app-deployment.yaml',
      api: 'api-deployment.yaml',
      websocket: 'websocket-deployment.yaml',
      database: 'database-deployment.yaml',
      redis: 'redis-deployment.yaml',
      ingress: 'ingress.yaml',
      monitoring: 'monitoring.yaml'
    }
  },
  docker: {
    registry: 'ghcr.io',
    image: 'normaldance/app',
    tags: {
      latest: 'latest',
      development: 'dev',
      staging: 'staging',
      production: 'prod'
    }
  }
};

// Ensure directories exist
const ensureDirectories = () => {
  const dirs = [config.kubernetes.configPath];
  dirs.forEach(dir => {
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
  });
};

// Build Docker images
const buildDockerImages = (environment) => {
  console.log(`Building Docker images for ${environment} environment...`);
  
  // Validate environment parameter to prevent injection
  if (!/^[a-zA-Z0-9_-]+$/.test(environment)) {
    throw new Error('Invalid environment name');
  }
  
  try {
    // Build main application with safe parameters
    const dockerfileEnv = `Dockerfile.${environment}`;
    const imageTag = `${config.docker.registry}/${config.docker.image}:${config.docker.tags[environment]}`;
    
    execSync('docker', ['build', '-f', dockerfileEnv, '-t', imageTag, '.'], {
      stdio: 'inherit'
    });
    
    // Build API service
    const apiImageTag = `${config.docker.registry}/${config.docker.image}-api:${config.docker.tags[environment]}`;
    execSync('docker', ['build', '-f', 'Dockerfile.api', '-t', apiImageTag, '.'], {
      stdio: 'inherit'
    });
    
    // Build WebSocket service
    const wsImageTag = `${config.docker.registry}/${config.docker.image}-websocket:${config.docker.tags[environment]}`;
    execSync('docker', ['build', '-f', 'Dockerfile.websocket', '-t', wsImageTag, '.'], {
      stdio: 'inherit'
    });
    
    console.log('Docker images built successfully');
    return true;
  } catch (error) {
    console.error('Failed to build Docker images:', error.message);
    return false;
  }
};

// Push Docker images
const pushDockerImages = (environment) => {
  console.log(`Pushing Docker images for ${environment} environment...`);
  
  try {
    // Push main application
    execSync(`docker push ${config.docker.registry}/${config.docker.image}:${config.docker.tags[environment]}`, {
      stdio: 'inherit'
    });
    
    // Push API service
    execSync(`docker push ${config.docker.registry}/${config.docker.image}-api:${config.docker.tags[environment]}`, {
      stdio: 'inherit'
    });
    
    // Push WebSocket service
    execSync(`docker push ${config.docker.registry}/${config.docker.image}-websocket:${config.docker.tags[environment]}`, {
      stdio: 'inherit'
    });
    
    console.log('Docker images pushed successfully');
    return true;
  } catch (error) {
    console.error('Failed to push Docker images:', error.message);
    return false;
  }
};

// Deploy to Kubernetes
const deployToKubernetes = (environment) => {
  console.log(`Deploying to ${environment} environment...`);
  
  try {
    // Set kubectl context
    execSync(`kubectl config use-context ${environment}`, {
      stdio: 'inherit'
    });
    
    // Create namespace
    execSync(`kubectl create namespace ${config.environments[environment].namespace} --dry-run=client -o yaml | kubectl apply -f -`, {
      stdio: 'inherit'
    });
    
    // Apply manifests
    Object.values(config.kubernetes.manifests).forEach(manifest => {
      const manifestPath = path.join(config.kubernetes.configPath, manifest);
      if (fs.existsSync(manifestPath)) {
        execSync(`kubectl apply -f ${manifestPath} -n ${config.environments[environment].namespace}`, {
          stdio: 'inherit'
        });
      }
    });
    
    // Wait for deployments to be ready
    execSync(`kubectl wait --for=condition=ready pod -l app=app -n ${config.environments[environment].namespace} --timeout=300s`, {
      stdio: 'inherit'
    });
    
    console.log(`Deployment to ${environment} completed successfully`);
    return true;
  } catch (error) {
    console.error(`Failed to deploy to ${environment}:`, error.message);
    return false;
  }
};

// Run health checks
const runHealthChecks = (environment) => {
  console.log(`Running health checks for ${environment} environment...`);
  
  try {
    // Check application health
    execSync(`curl -f https://normaldance.com/health || curl -f http://localhost:3000/health`, {
      stdio: 'inherit',
      timeout: 30000
    });
    
    // Check API health
    execSync(`curl -f https://api.normaldance.com/health || curl -f http://localhost:8080/health`, {
      stdio: 'inherit',
      timeout: 30000
    });
    
    // Check WebSocket health
    execSync(`curl -f https://ws.normaldance.com/health || curl -f http://localhost:3001/health`, {
      stdio: 'inherit',
      timeout: 30000
    });
    
    console.log('Health checks passed');
    return true;
  } catch (error) {
    console.error('Health checks failed:', error.message);
    return false;
  }
};

// Rollback deployment
const rollbackDeployment = (environment) => {
  console.log(`Rolling back deployment for ${environment} environment...`);
  
  try {
    // Get previous deployment revision
    const revision = execSync(`kubectl rollout history deployment/app -n ${config.environments[environment].namespace} --revision=2`).toString().trim();
    
    // Rollback to previous revision
    execSync(`kubectl rollout undo deployment/app -n ${config.environments[environment].namespace} --to-revision=${revision}`, {
      stdio: 'inherit'
    });
    
    // Wait for rollback to complete
    execSync(`kubectl rollout status deployment/app -n ${config.environments[environment].namespace}`, {
      stdio: 'inherit'
    });
    
    console.log(`Rollback to ${environment} completed successfully`);
    return true;
  } catch (error) {
    console.error(`Failed to rollback ${environment}:`, error.message);
    return false;
  }
};

// Scale deployment
const scaleDeployment = (environment, replicas) => {
  console.log(`Scaling deployment for ${environment} environment to ${replicas} replicas...`);
  
  try {
    execSync(`kubectl scale deployment/app --replicas=${replicas} -n ${config.environments[environment].namespace}`, {
      stdio: 'inherit'
    });
    
    console.log(`Deployment scaled to ${replicas} replicas`);
    return true;
  } catch (error) {
    console.error(`Failed to scale ${environment}:`, error.message);
    return false;
  }
};

// Monitor deployment
const monitorDeployment = (environment) => {
  console.log(`Monitoring deployment for ${environment} environment...`);
  
  try {
    // Monitor pod status
    execSync(`kubectl get pods -n ${config.environments[environment].namespace} -w`, {
      stdio: 'inherit',
      timeout: 60000
    });
    
    return true;
  } catch (error) {
    console.error(`Monitoring failed for ${environment}:`, error.message);
    return false;
  }
};

// Safe JSON serialization to prevent deserialization attacks
const safeStringify = (obj) => {
  return JSON.stringify(obj, (key, value) => {
    // Only allow safe data types
    if (typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean' || value === null) {
      return value;
    }
    if (typeof value === 'object' && value !== null && !Array.isArray(value)) {
      return value;
    }
    return String(value);
  }, 2);
};

// Generate deployment report
const generateDeploymentReport = (environment, success) => {
  console.log(`Generating deployment report for ${environment} environment...`);
  
  // Validate inputs
  if (!/^[a-zA-Z0-9_-]+$/.test(environment)) {
    throw new Error('Invalid environment name');
  }
  
  const report = {
    timestamp: new Date().toISOString(),
    environment: String(environment),
    success: Boolean(success),
    details: {
      build: Boolean(success),
      push: Boolean(success),
      deploy: Boolean(success),
      healthCheck: Boolean(success)
    }
  };
  
  const reportPath = path.join('./reports', `deployment-${environment}-${Date.now()}.json`);
  fs.writeFileSync(reportPath, safeStringify(report));
  
  console.log(`Deployment report generated: ${reportPath}`);
  return reportPath;
};

// Main function
const main = async (environment = 'production') => {
  console.log(`Starting deployment process for ${environment} environment...`);
  
  ensureDirectories();
  
  // Validate environment
  if (!config.environments[environment]) {
    console.error(`Invalid environment: ${environment}`);
    process.exit(1);
  }
  
  const results = {
    build: false,
    push: false,
    deploy: false,
    healthCheck: false
  };
  
  try {
    // Build Docker images
    results.build = buildDockerImages(environment);
    if (!results.build) throw new Error('Build failed');
    
    // Push Docker images
    results.push = pushDockerImages(environment);
    if (!results.push) throw new Error('Push failed');
    
    // Deploy to Kubernetes
    results.deploy = deployToKubernetes(environment);
    if (!results.deploy) throw new Error('Deployment failed');
    
    // Run health checks
    results.healthCheck = runHealthChecks(environment);
    if (!results.healthCheck) throw new Error('Health checks failed');
    
    // Generate deployment report
    const reportPath = generateDeploymentReport(environment, true);
    
    console.log(`\n🎉 Deployment to ${environment} completed successfully!`);
    console.log(`Report: ${reportPath}`);
    
    // Scale deployment if production
    if (environment === 'production') {
      scaleDeployment(environment, config.environments[environment].replicas);
    }
    
    process.exit(0);
  } catch (error) {
    console.error(`\n❌ Deployment to ${environment} failed:`, error.message);
    
    // Generate failure report
    generateDeploymentReport(environment, false);
    
    // Attempt rollback
    console.log('Attempting rollback...');
    rollbackDeployment(environment);
    
    process.exit(1);
  }
};

// Handle command line arguments
if (require.main === module) {
  const args = process.argv.slice(2);
  const environment = args[0] || 'production';
  
  main(environment).catch(error => {
    console.error('Deployment failed:', error);
    process.exit(1);
  });
}

module.exports = {
  buildDockerImages,
  pushDockerImages,
  deployToKubernetes,
  runHealthChecks,
  rollbackDeployment,
  scaleDeployment,
  monitorDeployment,
  generateDeploymentReport
};