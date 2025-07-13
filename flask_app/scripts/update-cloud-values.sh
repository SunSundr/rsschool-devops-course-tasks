#!/bin/bash

# Script to update DockerHub username in values-cloud.yaml
# Usage: ./update-cloud-values.sh <docker-username>

DOCKER_USERNAME=${1}
VALUES_FILE="helm-chart/flask-app/values-cloud.yaml"

if [ -z "$DOCKER_USERNAME" ]; then
    echo "Usage: $0 <docker-username>"
    echo "Example: $0 sunsundr"
    exit 1
fi

cd "$(dirname "$0")/.."

if [ ! -f "$VALUES_FILE" ]; then
    echo "Error: $VALUES_FILE not found"
    exit 1
fi

# Update repository value
sed -i "s|repository: .*/flask-app|repository: $DOCKER_USERNAME/flask-app|g" "$VALUES_FILE"

echo "Updated $VALUES_FILE with repository: $DOCKER_USERNAME/flask-app"
echo "Current repository setting:"
grep "repository:" "$VALUES_FILE"