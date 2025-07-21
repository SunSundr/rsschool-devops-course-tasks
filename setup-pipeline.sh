#!/bin/bash

# Complete setup script for Jenkins pipeline
# Usage: ./setup-pipeline.sh

echo "Setting up Jenkins pipeline environment..."

# Check if .env file exists
if [ ! -f .env ]; then
    echo "Creating .env file from example..."
    cp .env.example .env
    echo "Please edit .env file with your credentials before continuing."
    exit 1
fi

# Start Minikube if not running
if ! minikube status &>/dev/null; then
    echo "Starting Minikube..."
    minikube start --driver=docker --memory=4096 --cpus=2
else
    echo "Minikube is already running."
fi

# Create Jenkins namespace
kubectl create namespace jenkins --dry-run=client -o yaml | kubectl apply -f -

# Apply the RBAC configuration for Jenkins:
kubectl apply -f k8s/jenkins/minikube/jenkins-cluster-rbac.yaml

# Install Jenkins
echo "Installing Jenkins..."
./install-jenkins.sh minikube


echo "Setup completed!"
echo ""
echo "Access Jenkins:"
echo "minikube service jenkins --namespace jenkins"
echo ""
echo "Access SonarQube:"
echo "kubectl port-forward svc/sonarqube-service 9000:9000 -n sonarqube"
echo "Then open http://localhost:9000 in your browser (default credentials: admin/admin)"
echo ""
echo "For more details, see JENKINS_SETUP.md and QUICK_START.md"