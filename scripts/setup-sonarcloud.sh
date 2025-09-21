#!/bin/bash

# SonarCloud Setup Script for NORMALDANCE Enterprise

set -e

echo "🔍 Setting up SonarCloud for NORMALDANCE Enterprise..."

# Check if sonar-scanner is installed
if ! command -v sonar-scanner &> /dev/null; then
    echo "Installing SonarCloud Scanner..."
    
    # For macOS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install sonar-scanner
    # For Ubuntu/Debian
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        wget https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-4.8.0.2856-linux.zip
        unzip sonar-scanner-cli-4.8.0.2856-linux.zip
        sudo mv sonar-scanner-4.8.0.2856-linux /opt/sonar-scanner
        sudo ln -s /opt/sonar-scanner/bin/sonar-scanner /usr/local/bin/sonar-scanner
    fi
fi

# Create SonarCloud project configuration
echo "📝 Creating SonarCloud configuration..."

# Generate sonar-project.properties if it doesn't exist
if [ ! -f "sonar-project.properties" ]; then
    cat > sonar-project.properties << EOF
sonar.projectKey=AENDYSTUDIO_NORMALDANCE-Enterprise
sonar.organization=aendystudio
sonar.projectName=NORMALDANCE Enterprise
sonar.projectVersion=1.0.1

# Source code
sonar.sources=src
sonar.tests=tests
sonar.test.inclusions=**/*.test.ts,**/*.test.tsx,**/*.spec.ts,**/*.spec.tsx

# Exclusions
sonar.exclusions=**/node_modules/**,**/.next/**,**/coverage/**,**/dist/**,**/*.d.ts

# Coverage
sonar.javascript.lcov.reportPaths=coverage/lcov.info
sonar.typescript.lcov.reportPaths=coverage/lcov.info

# Language settings
sonar.typescript.node=node

# Quality gate
sonar.qualitygate.wait=true
EOF
fi

# Setup GitHub Action for SonarCloud
mkdir -p .github/workflows

cat > .github/workflows/sonarcloud.yml << 'EOF'
name: SonarCloud Analysis

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  sonarcloud:
    name: SonarCloud
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'pnpm'
      
      - name: Install pnpm
        run: npm install -g pnpm
      
      - name: Install dependencies
        run: pnpm install --frozen-lockfile
      
      - name: Run tests with coverage
        run: pnpm test:coverage
      
      - name: SonarCloud Scan
        uses: SonarSource/sonarcloud-github-action@master
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
EOF

echo "✅ SonarCloud setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Go to https://sonarcloud.io"
echo "2. Sign in with GitHub"
echo "3. Import your repository: AENDYSTUDIO/NORMALDANCE-Enterprise"
echo "4. Get your SONAR_TOKEN from SonarCloud"
echo "5. Add SONAR_TOKEN to GitHub Secrets"
echo "6. Push changes to trigger first analysis"
echo ""
echo "🔗 SonarCloud Project URL: https://sonarcloud.io/project/overview?id=AENDYSTUDIO_NORMALDANCE-Enterprise"