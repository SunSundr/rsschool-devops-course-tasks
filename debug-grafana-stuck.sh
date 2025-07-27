#!/bin/bash

echo "Debugging stuck Grafana pod..."

echo "=== Checking pod status ==="
kubectl get pods -n monitoring | grep grafana

echo ""
echo "=== Describing stuck pod ==="
GRAFANA_POD=$(kubectl get pods -n monitoring | grep grafana | awk '{print $1}')
kubectl describe pod $GRAFANA_POD -n monitoring

echo ""
echo "=== Checking events ==="
kubectl get events -n monitoring --sort-by=.metadata.creationTimestamp | tail -10

echo ""
echo "=== Checking PVC status ==="
kubectl get pvc -n monitoring | grep grafana

echo ""
echo "=== Checking ConfigMap ==="
kubectl get configmap grafana-config -n monitoring -o yaml | head -20

echo ""
echo "=== Force delete and restart ==="
echo "Run these commands to fix:"
echo "kubectl delete pod $GRAFANA_POD -n monitoring --force --grace-period=0"
echo "helm uninstall grafana -n monitoring"
echo "./install-grafana.sh"