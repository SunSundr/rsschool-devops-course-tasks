#!/bin/bash

# Jenkins installation script
# Usage: ./install-jenkins.sh [minikube|cloud]

DEPLOYMENT_TYPE=${1:-minikube}

echo "Installing Jenkins for: $DEPLOYMENT_TYPE"

# Add Jenkins Helm repository
helm repo add jenkins https://charts.jenkins.io
helm repo update

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo "Warning: .env file not found. Using default credentials."
    export JENKINS_ADMIN_USER="admin"
    export JENKINS_ADMIN_PASSWORD="admin123"
fi

# Deploy storage first
./scripts/deploy.sh $DEPLOYMENT_TYPE

# Create Jenkins admin secret
echo "Creating Jenkins admin secret..."
kubectl create secret generic jenkins-admin-secret \
    --from-literal=username="$JENKINS_ADMIN_USER" \
    --from-literal=password="$JENKINS_ADMIN_PASSWORD" \
    --namespace jenkins \
    --dry-run=client -o yaml | kubectl apply -f -

echo "Jenkins credentials configured from environment variables"

# Install Jenkins with Helm
if [ "$DEPLOYMENT_TYPE" = "minikube" ]; then
    echo "Installing Jenkins for Minikube..."
    helm install jenkins jenkins/jenkins \
        --namespace jenkins \
        --values k8s/jenkins/base/values.yaml \
        --values k8s/jenkins/minikube/values-minikube.yaml
        
    echo "Jenkins installation started! Checking status..."
    echo "Wait for Jenkins to be ready (this may take a few minutes):"
    echo "kubectl get pods -n jenkins -w"
    echo ""
    echo "Once ready, access Jenkins via (keep terminal open):"
    echo "minikube service jenkins --namespace jenkins"
    echo ""
    echo "Alternative access method:"
    echo "kubectl port-forward svc/jenkins 8080:8080 -n jenkins"
    
elif [ "$DEPLOYMENT_TYPE" = "cloud" ]; then
    echo "Installing Jenkins for Cloud..."
    helm install jenkins jenkins/jenkins \
        --namespace jenkins \
        --values ../k8s/jenkins/base/values.yaml \
        --values ../k8s/jenkins/cloud/values-cloud.yaml \
        --wait --timeout=10m
        
    echo "Jenkins installed! Get LoadBalancer IP:"
    echo "kubectl get svc jenkins -n jenkins"
else
    echo "Invalid deployment type. Use 'minikube' or 'cloud'"
    exit 1
fi

echo "Jenkins credentials:"
echo "Username: $JENKINS_ADMIN_USER"
echo "Password: $JENKINS_ADMIN_PASSWORD"