#!/bin/bash
# Create Air-Gapped Deployment Bundle for NORMALDANCE

set -e

VERSION=${1:-"latest"}
BUNDLE_DIR="offline-bundle-${VERSION}"
IMAGES_DIR="${BUNDLE_DIR}/images"
CHARTS_DIR="${BUNDLE_DIR}/charts"
TERRAFORM_DIR="${BUNDLE_DIR}/terraform"

echo "🚀 Creating air-gapped bundle v${VERSION}"

# Create directory structure
mkdir -p ${IMAGES_DIR} ${CHARTS_DIR} ${TERRAFORM_DIR}

# Export Docker images
echo "📦 Exporting Docker images..."
docker save ghcr.io/normaldance/app:${VERSION} -o ${IMAGES_DIR}/normaldance-app.tar
docker save postgres:15-alpine -o ${IMAGES_DIR}/postgres.tar
docker save redis:alpine -o ${IMAGES_DIR}/redis.tar
docker save nginx:alpine -o ${IMAGES_DIR}/nginx.tar

# Generate checksums
echo "🔐 Generating checksums..."
cd ${IMAGES_DIR}
sha256sum *.tar > checksums.txt
cd ../..

# Package Helm charts
echo "📋 Packaging Helm charts..."
helm package helm/normaldance -d ${CHARTS_DIR}
helm repo index ${CHARTS_DIR}

# Copy Terraform modules
echo "🏗️ Copying Terraform modules..."
cp -r infrastructure/terraform/* ${TERRAFORM_DIR}/

# Create air-gap values
cat > ${CHARTS_DIR}/values-airgap.yaml << EOF
# Air-gapped deployment values
image:
  repository: localhost:5000/normaldance/app
  tag: ${VERSION}
  pullPolicy: IfNotPresent

postgresql:
  image:
    repository: localhost:5000/postgres
    tag: 15-alpine

redis:
  image:
    repository: localhost:5000/redis
    tag: alpine

nginx:
  image:
    repository: localhost:5000/nginx
    tag: alpine

# Disable external dependencies
externalServices:
  enabled: false

# Use local registry
imageRegistry:
  url: localhost:5000
  insecure: true
EOF

# Create installation script
cat > ${BUNDLE_DIR}/install.sh << 'EOF'
#!/bin/bash
# NORMALDANCE Air-Gapped Installation

set -e

echo "🚀 Installing NORMALDANCE in air-gapped environment"

# Load Docker images
echo "📦 Loading Docker images..."
docker load -i images/normaldance-app.tar
docker load -i images/postgres.tar
docker load -i images/redis.tar
docker load -i images/nginx.tar

# Verify checksums
echo "🔐 Verifying checksums..."
cd images && sha256sum -c checksums.txt && cd ..

# Tag images for local registry
echo "🏷️ Tagging images for local registry..."
docker tag ghcr.io/normaldance/app:${VERSION} localhost:5000/normaldance/app:${VERSION}
docker tag postgres:15-alpine localhost:5000/postgres:15-alpine
docker tag redis:alpine localhost:5000/redis:alpine
docker tag nginx:alpine localhost:5000/nginx:alpine

# Push to local registry
echo "📤 Pushing to local registry..."
docker push localhost:5000/normaldance/app:${VERSION}
docker push localhost:5000/postgres:15-alpine
docker push localhost:5000/redis:alpine
docker push localhost:5000/nginx:alpine

# Install Helm chart
echo "📋 Installing Helm chart..."
helm install normaldance charts/normaldance-*.tgz -f charts/values-airgap.yaml

echo "✅ Installation complete!"
echo "📊 Check status: kubectl get pods -l app=normaldance"
EOF

chmod +x ${BUNDLE_DIR}/install.sh

# Create README
cat > ${BUNDLE_DIR}/README.md << EOF
# NORMALDANCE Air-Gapped Installation

## Prerequisites
- Docker registry running on localhost:5000
- Kubernetes cluster
- Helm 3.x installed

## Installation Steps

1. **Load images and install**:
   \`\`\`bash
   ./install.sh
   \`\`\`

2. **Verify installation**:
   \`\`\`bash
   kubectl get pods -l app=normaldance
   kubectl get svc normaldance
   \`\`\`

3. **Access application**:
   \`\`\`bash
   kubectl port-forward svc/normaldance 3000:80
   # Open http://localhost:3000
   \`\`\`

## Terraform Deployment (Alternative)

1. **Initialize Terraform**:
   \`\`\`bash
   cd terraform
   terraform init
   \`\`\`

2. **Deploy infrastructure**:
   \`\`\`bash
   terraform plan -var="image_tag=${VERSION}"
   terraform apply
   \`\`\`

## Support
- Documentation: ./docs/
- Troubleshooting: ./docs/troubleshooting.md
EOF

# Create bundle archive
echo "📦 Creating bundle archive..."
tar -czf "normaldance-airgap-${VERSION}.tar.gz" ${BUNDLE_DIR}

# Generate final checksums
sha256sum "normaldance-airgap-${VERSION}.tar.gz" > "normaldance-airgap-${VERSION}.sha256"

echo "✅ Air-gapped bundle created successfully!"
echo "📦 Bundle: normaldance-airgap-${VERSION}.tar.gz"
echo "🔐 Checksum: normaldance-airgap-${VERSION}.sha256"
echo "📏 Size: $(du -h normaldance-airgap-${VERSION}.tar.gz | cut -f1)"