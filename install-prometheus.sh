#!/bin/bash

set -e

echo "Installing Prometheus on Minikube..."

# Add Prometheus community Helm repository
echo "Adding Prometheus community Helm repository..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create monitoring namespace
echo "Creating monitoring namespace..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Install Prometheus using community chart with values file
echo "Installing Prometheus..."
helm install prometheus prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --values k8s/prometheus/minikube/values-minikube-stack.yaml \
    --wait \
    --timeout=600s

# Wait for pods to be ready
echo "Waiting for Prometheus pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n monitoring --timeout=300s

# Create ServiceMonitor for Flask app
echo "Creating ServiceMonitor for Flask app..."
cat << EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: flask-app-monitor
  namespace: monitoring
  labels:
    app: flask-app
    release: prometheus
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: flask-app
  namespaceSelector:
    matchNames:
    - flask-app
  endpoints:
  - port: http
    path: /metrics
    interval: 30s
EOF

# Find the correct Prometheus service
PROM_SERVICE=$(kubectl get svc -n monitoring | grep prometheus | grep -v operator | grep -v node-exporter | awk '{print $1}' | head -1)

echo ""
echo "Prometheus installation completed!"
echo ""
echo "Access Prometheus:"
echo "  kubectl port-forward svc/$PROM_SERVICE 9090:9090 -n monitoring"
echo ""
echo "Check pods status:"
echo "  kubectl get pods -n monitoring"
echo ""
echo "Check services:"
echo "  kubectl get svc -n monitoring"
echo ""
echo "Test Flask app metrics:"
echo "  kubectl port-forward svc/flask-app 8080:8080 -n flask-app"
echo "  curl http://localhost:8080/metrics"
echo ""
echo "In Prometheus web UI, try these queries:"
echo "  - up (service status)"
echo "  - node_memory_MemAvailable_bytes (memory usage)"
echo "  - flask_requests_total (Flask app metrics)"