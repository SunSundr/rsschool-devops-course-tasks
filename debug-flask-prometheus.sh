#!/bin/bash

echo "Debugging Flask app discovery by Prometheus..."

echo "=== Checking Flask app pods and annotations ==="
kubectl get pods -n flask-app -o yaml | grep -A 10 -B 5 "prometheus.io"

echo ""
echo "=== Checking if Flask app has correct labels ==="
kubectl get pods -n flask-app --show-labels

echo ""
echo "=== Checking Prometheus targets ==="
kubectl port-forward svc/prometheus-kube-prometheus-stack-prometheus 9090:9090 -n monitoring &
PROM_PID=$!
sleep 5

echo "All Prometheus targets:"
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, instance: .labels.instance, health: .health, lastScrape: .lastScrape}'

echo ""
echo "Looking for Flask app in targets:"
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job | contains("flask") or contains("kubernetes-pods"))'

echo ""
echo "Checking if flask_requests_total exists in Prometheus:"
curl -s "http://localhost:9090/api/v1/query?query=flask_requests_total" | jq '.data.result'

kill $PROM_PID 2>/dev/null || true

echo ""
echo "=== Checking ServiceMonitor resources ==="
kubectl get servicemonitor -n monitoring
kubectl get servicemonitor -n flask-app 2>/dev/null || echo "No ServiceMonitor in flask-app namespace"

echo ""
echo "=== Flask app service details ==="
kubectl get svc flask-app -n flask-app -o yaml