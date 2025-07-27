#!/bin/bash

echo "Simulating CPU and Memory stress on Kubernetes node..."

echo "Deploying comprehensive stress test pod..."
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: stress-test-comprehensive
  namespace: default
  labels:
    app: stress-test
spec:
  containers:
  - name: stress
    image: polinux/stress
    resources:
      requests:
        memory: "200Mi"
        cpu: "200m"
      limits:
        memory: "1Gi"
        cpu: "1000m"
    command: ["stress"]
    args: [
      "--cpu", "4",           # Use 4 CPU cores at 100%
      "--memory", "2",        # Allocate 2 memory workers
      "--memory-bytes", "800M", # Each worker uses 800MB (total ~1.6GB)
      "--timeout", "600s"     # Run for 10 minutes
    ]
  restartPolicy: Never
EOF

echo ""
echo "Deploying sysbench CPU stress test..."
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: sysbench-cpu-test
  namespace: default
  labels:
    app: sysbench-test
spec:
  containers:
  - name: sysbench
    image: severalnines/sysbench
    resources:
      requests:
        cpu: "100m"
        memory: "100Mi"
      limits:
        cpu: "500m"
        memory: "200Mi"
    command: ["sysbench"]
    args: [
      "cpu",
      "--cpu-max-prime=50000",
      "--threads=4",
      "--time=300",
      "run"
    ]
  restartPolicy: Never
EOF

echo ""
echo "Deploying memory-intensive workload..."
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: memory-hog
  namespace: default
  labels:
    app: memory-test
spec:
  containers:
  - name: memory-consumer
    image: busybox
    resources:
      requests:
        memory: "500Mi"
      limits:
        memory: "1.5Gi"
    command: ["sh", "-c"]
    args: [
      "echo 'Starting memory allocation...';
       dd if=/dev/zero of=/tmp/memory.fill bs=1M count=1200;
       echo 'Memory allocated, sleeping...';
       sleep 600;
       echo 'Cleaning up...';
       rm /tmp/memory.fill"
    ]
  restartPolicy: Never
EOF

echo ""
echo "Deploying I/O stress test..."
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: io-stress-test
  namespace: default
  labels:
    app: io-test
spec:
  containers:
  - name: io-stress
    image: polinux/stress
    resources:
      requests:
        cpu: "100m"
        memory: "100Mi"
      limits:
        cpu: "300m"
        memory: "200Mi"
    command: ["stress"]
    args: [
      "--io", "4",            # 4 I/O workers
      "--hdd", "2",           # 2 disk workers
      "--hdd-bytes", "100M",  # Write 100MB per worker
      "--timeout", "300s"     # Run for 5 minutes
    ]
  restartPolicy: Never
EOF

echo ""
echo "Stress tests deployed successfully!"
echo ""
echo "Monitor the tests:"
echo "kubectl get pods | grep -E 'stress|sysbench|memory|io'"
echo "kubectl top pods"
echo "kubectl top nodes"
echo ""
echo "Check individual pod status:"
echo "kubectl logs stress-test-comprehensive"
echo "kubectl logs sysbench-cpu-test"
echo "kubectl logs memory-hog"
echo "kubectl logs io-stress-test"
echo ""
echo "Monitor resource usage:"
echo "watch 'kubectl top pods && echo && kubectl top nodes'"
echo ""
echo "Clean up after testing:"
echo "kubectl delete pod stress-test-comprehensive sysbench-cpu-test memory-hog io-stress-test"
echo ""
echo "Expected behavior:"
echo "- CPU usage should spike to 80%+ (triggering High CPU alert)"
echo "- Memory usage should increase to 85%+ (triggering High Memory alert)"
echo "- I/O operations will stress disk subsystem"
echo "- Tests will run for 5-10 minutes then auto-cleanup"
echo ""
echo "Check Grafana alerts:"
echo "- Go to Alerting → Alert Rules"
echo "- Monitor dashboard metrics"
echo "- Check email for alert notifications"