#!/bin/bash

# Build script for Flask app Docker image
# Usage: ./build-image.sh [minikube|cloud] [docker-username]

DEPLOYMENT_TYPE=${1:-minikube}
DOCKER_USERNAME=${2:-your-dockerhub-username}
IMAGE_NAME="flask-app"
IMAGE_TAG="latest"

echo "Building Flask app image for: $DEPLOYMENT_TYPE"

cd "$(dirname "$0")/.."

if [ "$DEPLOYMENT_TYPE" = "minikube" ]; then
    echo "Building image for Minikube..."

    eval $(minikube docker-env) # Use Minikube's Docker daemon

    docker build -t $IMAGE_NAME:$IMAGE_TAG .
    echo "Image built for Minikube: $IMAGE_NAME:$IMAGE_TAG"
    
elif [ "$DEPLOYMENT_TYPE" = "cloud" ]; then
    echo "Building and pushing image for Cloud..."
    
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        echo "Error: Docker not found. This script must be run from local machine with Docker installed."
        echo "Run this command from your local machine, not from bastion host."
        exit 1
    fi
    
    FULL_IMAGE_NAME="$DOCKER_USERNAME/$IMAGE_NAME:$IMAGE_TAG"
    
    # Build image
    echo "Building image: $FULL_IMAGE_NAME"
    docker build -t $FULL_IMAGE_NAME .
    
    # Push to DockerHub
    echo "Pushing image to DockerHub..."
    echo "Make sure you're logged in to DockerHub (docker login)"
    docker push $FULL_IMAGE_NAME
    echo "Image pushed: $FULL_IMAGE_NAME"
    
else
    echo "Invalid deployment type. Use 'minikube' or 'cloud'"
    exit 1
fi

echo "Build completed for $DEPLOYMENT_TYPE"