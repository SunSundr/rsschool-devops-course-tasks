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
    
    # Build and push image:
    ./scripts/build-image.sh cloud $DOCKER_USERNAME
    
    # Deploy:
    helm upgrade --install $RELEASE_NAME $CHART_PATH \
        --namespace $NAMESPACE \
        --values $CHART_PATH/values-cloud.yaml \
        --set image.repository=$DOCKER_USERNAME/flask-app \
        --wait
    
    echo "Flask app deployed to Cloud!"
    echo "Check LoadBalancer IP: kubectl get svc flask-app -n flask-app"
    
else
    echo "Invalid deployment type. Use 'minikube' or 'cloud'"
    exit 1
fi

echo "Deployment completed for $DEPLOYMENT_TYPE"