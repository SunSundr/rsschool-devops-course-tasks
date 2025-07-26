#!/bin/bash

echo "Debugging Grafana installation..."

echo "=== Checking Grafana pod status ==="
kubectl get pods -n monitoring | grep grafana

echo ""
echo "=== Describing Grafana pod ==="
GRAFANA_POD=$(kubectl get pods -n monitoring | grep grafana | awk '{print $1}')
kubectl describe pod $GRAFANA_POD -n monitoring

echo ""
echo "=== Checking PVC status ==="
kubectl get pvc -n monitoring | grep grafana

echo ""
echo "=== Checking storage class ==="
kubectl get storageclass

echo ""
echo "=== Checking events ==="
kubectl get events -n monitoring --sort-by=.metadata.creationTimestamp | tail -20

echo ""
echo "=== Checking Minikube resources ==="
kubectl top nodes 2>/dev/null || echo "Metrics server not available"
kubectl get nodes -o wide