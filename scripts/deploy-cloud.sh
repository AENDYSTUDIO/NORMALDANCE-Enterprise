#!/bin/bash

# NORMALDANCE Enterprise Cloud Deployment Script

set -e

# Configuration
PROJECT_NAME="normaldance-enterprise"
REGION="us-west-2"
CLUSTER_NAME="normaldance-cluster"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 NORMALDANCE Enterprise Cloud Deployment${NC}"
echo "=================================================="

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    echo "🔍 Checking prerequisites..."
    
    # Check if required tools are installed
    for tool in docker kubectl helm; do
        if ! command -v $tool &> /dev/null; then
            print_error "$tool is not installed"
            exit 1
        fi
    done
    
    print_status "All prerequisites met"
}

# Select cloud provider
select_cloud_provider() {
    echo ""
    echo "☁️  Select cloud provider:"
    echo "1) AWS EKS"
    echo "2) Google GKE"
    echo "3) Azure AKS"
    echo "4) Local Docker"
    read -p "Enter choice (1-4): " choice
    
    case $choice in
        1) deploy_aws_eks ;;
        2) deploy_google_gke ;;
        3) deploy_azure_aks ;;
        4) deploy_local_docker ;;
        *) print_error "Invalid choice"; exit 1 ;;
    esac
}

# AWS EKS Deployment
deploy_aws_eks() {
    print_status "Deploying to AWS EKS..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed"
        exit 1
    fi
    
    # Check eksctl
    if ! command -v eksctl &> /dev/null; then
        print_warning "eksctl not found, installing..."
        curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
        sudo mv /tmp/eksctl /usr/local/bin
    fi
    
    # Create EKS cluster
    echo "Creating EKS cluster..."
    eksctl create cluster \
        --name $CLUSTER_NAME \
        --version 1.24 \
        --region $REGION \
        --nodegroup-name standard-workers \
        --node-type t3.medium \
        --nodes 3 \
        --nodes-min 1 \
        --nodes-max 4 \
        --managed
    
    # Install AWS Load Balancer Controller
    kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"
    
    # Deploy application
    deploy_to_kubernetes
    
    print_status "AWS EKS deployment complete!"
}

# Google GKE Deployment
deploy_google_gke() {
    print_status "Deploying to Google GKE..."
    
    # Check gcloud CLI
    if ! command -v gcloud &> /dev/null; then
        print_error "Google Cloud CLI is not installed"
        exit 1
    fi
    
    # Create GKE cluster
    echo "Creating GKE cluster..."
    gcloud container clusters create $CLUSTER_NAME \
        --zone us-central1-a \
        --num-nodes 3 \
        --enable-autoscaling \
        --min-nodes 1 \
        --max-nodes 5 \
        --machine-type e2-standard-2
    
    # Get credentials
    gcloud container clusters get-credentials $CLUSTER_NAME --zone us-central1-a
    
    # Deploy application
    deploy_to_kubernetes
    
    print_status "Google GKE deployment complete!"
}

# Azure AKS Deployment
deploy_azure_aks() {
    print_status "Deploying to Azure AKS..."
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed"
        exit 1
    fi
    
    # Create resource group
    az group create --name ${PROJECT_NAME}-rg --location eastus
    
    # Create AKS cluster
    echo "Creating AKS cluster..."
    az aks create \
        --resource-group ${PROJECT_NAME}-rg \
        --name $CLUSTER_NAME \
        --node-count 3 \
        --enable-addons monitoring \
        --generate-ssh-keys
    
    # Get credentials
    az aks get-credentials --resource-group ${PROJECT_NAME}-rg --name $CLUSTER_NAME
    
    # Deploy application
    deploy_to_kubernetes
    
    print_status "Azure AKS deployment complete!"
}

# Local Docker Deployment
deploy_local_docker() {
    print_status "Deploying locally with Docker..."
    
    # Build and run with Docker Compose
    docker-compose -f docker-compose.enterprise.yml up -d
    
    # Wait for services to be ready
    echo "Waiting for services to be ready..."
    sleep 30
    
    # Check service health
    if curl -f http://localhost:3000/api/health > /dev/null 2>&1; then
        print_status "Application is running at http://localhost:3000"
    else
        print_error "Application failed to start"
        exit 1
    fi
    
    print_status "Local Docker deployment complete!"
}

# Deploy to Kubernetes
deploy_to_kubernetes() {
    print_status "Deploying to Kubernetes..."
    
    # Create namespace
    kubectl create namespace normaldance --dry-run=client -o yaml | kubectl apply -f -
    
    # Apply configurations
    kubectl apply -f k8s/configmap.yaml
    kubectl apply -f k8s/secrets.yaml
    kubectl apply -f k8s/deployment.yaml
    kubectl apply -f k8s/service.yaml
    kubectl apply -f k8s/ingress.yaml
    kubectl apply -f k8s/hpa.yaml
    
    # Wait for deployment
    kubectl rollout status deployment/normaldance-app -n normaldance
    
    # Get service URL
    SERVICE_URL=$(kubectl get ingress normaldance-ingress -n normaldance -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    if [ -z "$SERVICE_URL" ]; then
        SERVICE_URL=$(kubectl get service normaldance-service -n normaldance -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    fi
    
    if [ ! -z "$SERVICE_URL" ]; then
        print_status "Application deployed at: https://$SERVICE_URL"
    else
        print_warning "Service URL not available yet. Check kubectl get ingress -n normaldance"
    fi
}

# Setup monitoring
setup_monitoring() {
    echo ""
    read -p "Do you want to deploy monitoring stack? (y/n): " deploy_monitoring
    
    if [ "$deploy_monitoring" = "y" ]; then
        print_status "Deploying monitoring stack..."
        
        # Deploy monitoring with Docker Compose
        docker-compose -f monitoring/docker-compose.monitoring.yml up -d
        
        print_status "Monitoring stack deployed:"
        echo "  - Prometheus: http://localhost:9090"
        echo "  - Grafana: http://localhost:3001 (admin/admin123)"
        echo "  - AlertManager: http://localhost:9093"
    fi
}

# Main execution
main() {
    check_prerequisites
    select_cloud_provider
    setup_monitoring
    
    echo ""
    print_status "Deployment completed successfully! 🎉"
    echo ""
    echo "📋 Next steps:"
    echo "1. Configure DNS for your domain"
    echo "2. Set up SSL certificates"
    echo "3. Configure monitoring alerts"
    echo "4. Run smoke tests"
    echo ""
    echo "📚 Documentation: https://docs.normaldance.com"
    echo "🆘 Support: support@normaldance.com"
}

# Run main function
main "$@"