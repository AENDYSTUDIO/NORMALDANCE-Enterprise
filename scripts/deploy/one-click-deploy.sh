#!/bin/bash
set -e

echo "🚀 NormalDance One-Click Production Deployment"

# Deploy AWS infrastructure
aws cloudformation deploy \
  --template-file aws/cloudformation/production-stack.yml \
  --stack-name normaldance-production \
  --capabilities CAPABILITY_IAM

# Configure kubectl
aws eks update-kubeconfig --name normaldance-production

# Deploy application
kubectl apply -f k8s/
kubectl rollout status deployment/normaldance-app --timeout=600s

echo "✅ Deployment complete!"