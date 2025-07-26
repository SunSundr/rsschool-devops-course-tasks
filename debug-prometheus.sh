#!/bin/bash

echo "Debugging Prometheus installation..."

echo "=== Checking pods in monitoring namespace ==="
kubectl get pods -n monitoring -o wide

echo ""
echo "=== Checking services in monitoring namespace ==="
kubectl get svc -n monitoring

echo ""
echo "=== Checking Prometheus configuration ==="
kubectl get configmap -n monitoring | grep prometheus

echo ""
echo "=== Checking Prometheus logs ==="
PROMETHEUS_POD=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}')
echo "Prometheus pod: $PROMETHEUS_POD"
kubectl logs $PROMETHEUS_POD -n monitoring --tail=20

echo ""
echo "=== Checking if targets are configured ==="
kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring &
PORT_FORWARD_PID=$!
sleep 5

echo "Checking Prometheus targets..."
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health, lastError: .lastError}' 2>/dev/null || curl -s http://localhost:9090/api/v1/targets

echo ""
echo "Checking available metrics..."
curl -s http://localhost:9090/api/v1/label/__name__/values | jq '.data[0:10]' 2>/dev/null || curl -s http://localhost:9090/api/v1/label/__name__/values | head -20

kill $PORT_FORWARD_PID 2>/dev/null || true

echo ""
echo "=== Helm release status ==="
helm status prometheus -n monitoring