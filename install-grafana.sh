#!/bin/bash

set -e

echo "Installing Grafana on Minikube..."

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo "Warning: .env file not found. Using default values."
    export GRAFANA_ADMIN_USER=admin
    export GRAFANA_ADMIN_PASSWORD=admin123
fi

echo "Using Grafana credentials: ${GRAFANA_ADMIN_USER} / ${GRAFANA_ADMIN_PASSWORD}"

# Add Bitnami Helm repository
echo "Adding Bitnami Helm repository..."
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Find Prometheus service
PROM_SERVICE=$(kubectl get svc -n monitoring | grep prometheus | grep -v operator | grep -v node-exporter | awk '{print $1}' | head -1)
echo "Found Prometheus service: $PROM_SERVICE"

# Create Prometheus datasource configuration
echo "Creating Prometheus datasource configuration..."
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: grafana-datasources
  namespace: monitoring
type: Opaque
stringData:
  datasources.yaml: |
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      access: proxy
      url: http://$PROM_SERVICE.monitoring.svc.cluster.local:9090
      isDefault: true
      editable: true
EOF

# Clean up any existing failed installation
echo "Cleaning up any existing Grafana installation..."
helm uninstall grafana -n monitoring 2>/dev/null || echo "No existing Grafana installation found"
kubectl delete pvc -n monitoring -l app.kubernetes.io/name=grafana 2>/dev/null || echo "No Grafana PVC to delete"

# Wait for cleanup
sleep 10

# Create Grafana admin secret
echo "Creating Grafana admin secret..."
kubectl create secret generic grafana-admin-secret \
    --from-literal=username="$GRAFANA_ADMIN_USER" \
    --from-literal=password="$GRAFANA_ADMIN_PASSWORD" \
    --namespace monitoring \
    --dry-run=client -o yaml | kubectl apply -f -

echo "Grafana credentials configured from environment variables"

# Install Grafana with environment variables
echo "Installing Grafana..."
envsubst < k8s/grafana/minikube/values-minikube.yaml | helm install grafana bitnami/grafana \
    --namespace monitoring \
    --values - \
    --wait \
    --timeout=600s

# Wait for Grafana to be ready
echo "Waiting for Grafana to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s

# Configure Prometheus datasource via API
echo "Configuring Prometheus datasource..."
kubectl port-forward svc/grafana 3000:3000 -n monitoring &
PORT_FORWARD_PID=$!
sleep 5

# Add datasource via API
curl -X POST \
  -H "Content-Type: application/json" \
  -u ${GRAFANA_ADMIN_USER}:${GRAFANA_ADMIN_PASSWORD} \
  -d "{
    \"name\": \"Prometheus\",
    \"type\": \"prometheus\",
    \"url\": \"http://$PROM_SERVICE.monitoring.svc.cluster.local:9090\",
    \"access\": \"proxy\",
    \"isDefault\": true
  }" \
  http://localhost:3000/api/datasources 2>/dev/null || echo "Datasource may already exist"

kill $PORT_FORWARD_PID 2>/dev/null || true

echo ""
echo "Grafana installation completed!"
echo ""
echo "Access Grafana:"
echo "  kubectl port-forward svc/grafana 3000:3000 -n monitoring"
echo "  Login: ${GRAFANA_ADMIN_USER} / ${GRAFANA_ADMIN_PASSWORD}"
echo ""
echo "Prometheus datasource is pre-configured and ready to use!"
echo ""
echo "Import dashboards from:"
echo "  - k8s/grafana/minikube/kubernetes-dashboard-extended.json"
echo "  - k8s/grafana/minikube/flask-app-dashboard.json"