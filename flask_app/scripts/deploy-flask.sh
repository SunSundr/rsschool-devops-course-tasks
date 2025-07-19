#!/bin/bash

# Deploy script for Flask app using Helm
# Usage: ./deploy-flask.sh [minikube|cloud] [docker-username]

DEPLOYMENT_TYPE=${1:-minikube}
DOCKER_USERNAME=${2:-your-dockerhub-username}
CHART_PATH="helm-chart/flask-app"
RELEASE_NAME="flask-app"
NAMESPACE="flask-app"

echo "Deploying Flask app for: $DEPLOYMENT_TYPE"

cd "$(dirname "$0")/.."

# Create namespace:
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

if [ "$DEPLOYMENT_TYPE" = "minikube" ]; then
    echo "Deploying to Minikube..."
    
    # Build image:
    ./scripts/build-image.sh minikube
    
    # Deploy:
    helm upgrade --install $RELEASE_NAME $CHART_PATH \
        --namespace $NAMESPACE \
        --values $CHART_PATH/values-minikube.yaml \
        --wait
    
    echo "Flask app deployed to Minikube!"
    echo "Access via: minikube service flask-app --namespace flask-app"
    
elif [ "$DEPLOYMENT_TYPE" = "cloud" ]; then
    echo "Deploying to Cloud..."
    
    # Note: Docker image should be built and pushed from local machine first
    echo "Make sure to run './scripts/build-image.sh cloud $DOCKER_USERNAME' from local machine first!"
    
    # Update values file with correct repository
    ./scripts/update-cloud-values.sh $DOCKER_USERNAME
    
    # Deploy
    helm upgrade --install $RELEASE_NAME $CHART_PATH \
        --namespace $NAMESPACE \
        --values $CHART_PATH/values-cloud.yaml \
        --wait
    
    echo "Flask app deployed to Cloud!"
    echo "Fix NodePort if needed: kubectl patch svc flask-app -n flask-app -p '{\"spec\":{\"ports\":[{\"port\":8080,\"targetPort\":8080,\"nodePort\":30080,\"protocol\":\"TCP\"}]}}'"
    echo "Access via port-forward: kubectl port-forward --address 0.0.0.0 svc/flask-app 8080:8080 -n flask-app &"
    echo "Or check service: kubectl get svc flask-app -n flask-app"
    
else
    echo "Invalid deployment type. Use 'minikube' or 'cloud'"
    exit 1
fi

echo "Deployment completed for $DEPLOYMENT_TYPE"