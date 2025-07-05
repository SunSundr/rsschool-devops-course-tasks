#!/bin/bash

# Deployment script for Jenkins
# Usage: ./deploy.sh [minikube|cloud]

DEPLOYMENT_TYPE=${1:-minikube}

echo "Deploying Jenkins for: $DEPLOYMENT_TYPE"

# Apply common resources
kubectl apply -f k8s/common/

# Apply storage class based on deployment type
if [ "$DEPLOYMENT_TYPE" = "minikube" ]; then
    echo "Using Minikube configuration with static PV (2Gi)..."
    kubectl apply -f k8s/jenkins/minikube/  # Apply PV first
    kubectl apply -f k8s/jenkins/base/      # Then PVC
elif [ "$DEPLOYMENT_TYPE" = "cloud" ]; then
    echo "Using Cloud configuration with dynamic EBS (5Gi)..."
    kubectl apply -f k8s/jenkins/cloud/storage-class-cloud.yaml  # Dynamic provisioning
    # Update PVC to use dynamic storage class
    sed 's/storageClassName: jenkins-storage/storageClassName: jenkins-storage-dynamic/' k8s/jenkins/base/pvc.yaml | kubectl apply -f -
else
    echo "Invalid deployment type. Use 'minikube' or 'cloud'"
    exit 1
fi

echo "Deployment completed for $DEPLOYMENT_TYPE"