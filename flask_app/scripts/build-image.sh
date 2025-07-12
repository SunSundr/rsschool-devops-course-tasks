#!/bin/bash

# Build script for Flask app Docker image
# Usage: ./build-image.sh [minikube|cloud] [docker-username]

DEPLOYMENT_TYPE=${1:-minikube}
DOCKER_USERNAME=${2:-your-dockerhub-username}
IMAGE_NAME="flask-app"
IMAGE_TAG="latest"

echo "Building Flask app image for: $DEPLOYMENT_TYPE"

# Change to flask_app directory
cd "$(dirname "$0")/.."

if [ "$DEPLOYMENT_TYPE" = "minikube" ]; then
    echo "Building image for Minikube..."
    # Use Minikube's Docker daemon
    eval $(minikube docker-env)
    docker build -t $IMAGE_NAME:$IMAGE_TAG .
    echo "Image built for Minikube: $IMAGE_NAME:$IMAGE_TAG"
    
elif [ "$DEPLOYMENT_TYPE" = "cloud" ]; then
    echo "Building and pushing image for Cloud..."
    FULL_IMAGE_NAME="$DOCKER_USERNAME/$IMAGE_NAME:$IMAGE_TAG"
    
    # Build image
    docker build -t $FULL_IMAGE_NAME .
    
    # Push to registry
    echo "Pushing image to DockerHub..."
    docker push $FULL_IMAGE_NAME
    echo "Image pushed: $FULL_IMAGE_NAME"
    
else
    echo "Invalid deployment type. Use 'minikube' or 'cloud'"
    exit 1
fi

echo "Build completed for $DEPLOYMENT_TYPE"