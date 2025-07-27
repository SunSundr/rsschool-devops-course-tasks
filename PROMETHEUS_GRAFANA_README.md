# Prometheus and Grafana Monitoring Setup

This guide covers the complete setup of Prometheus monitoring and Grafana visualization with alerting for Kubernetes clusters running in Minikube.

## Prerequisites

- **Minikube** running with sufficient resources (4GB RAM, 2 CPUs minimum)
- **kubectl** configured to access your Minikube cluster
- **Helm** package manager installed
- **Flask application** deployed with metrics support (redeploy via Jenkins pipeline)
- **Environment variables** configured in `.env` file

## Overview

The monitoring stack includes:
- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization, dashboards, and alerting
- **Node Exporter**: System metrics collection
- **Kube State Metrics**: Kubernetes cluster metrics
- **Email Alerting**: SMTP-based alert notifications

## Installation Steps

### Step 1: Install Prometheus

```bash
./install-prometheus.sh
```

**What this script does:**
- Adds Prometheus community Helm repository
- Creates `monitoring` namespace
- Installs `kube-prometheus-stack` with:
  - Prometheus server for metrics collection
  - Grafana for visualization
  - Node Exporter for system metrics
  - Kube State Metrics for Kubernetes metrics
  - Alert Manager for alert handling
- Creates ServiceMonitor for Flask app metrics
- Configures proper service discovery

**Verification:**
```bash
# Check all monitoring pods are running
kubectl get pods -n monitoring

# Access Prometheus web UI
kubectl port-forward svc/prometheus-kube-prometheus-stack-prometheus 9090:9090 -n monitoring
# Open: http://localhost:9090
```

### Step 2: Install Grafana with SMTP

```bash
./install-grafana.sh
```

**What this script does:**
- Loads SMTP configuration from `.env` file
- Creates Grafana admin credentials as Kubernetes secret
- Adds Bitnami Helm repository
- Installs Grafana with:
  - SMTP email configuration for alerting
  - Admin credentials from environment variables
  - Persistent storage disabled (suitable for testing)
  - NodePort service for easy access
- Auto-configures Prometheus as default datasource
- Sets up proper service discovery

**Verification:**
```bash
# Check Grafana pod is running
kubectl get pods -n monitoring | grep grafana

# Access Grafana web UI
kubectl port-forward svc/grafana 3000:3000 -n monitoring
# Open: http://localhost:3000
# Login: admin / admin123 (or values from .env)
```

### Step 3: Setup Alert Rules and Contact Points

```bash
# Make sure Grafana is accessible first
kubectl port-forward svc/grafana 3000:3000 -n monitoring

# Run the setup script
./grafana-alerts-rules-setup.sh
```

**What this script does:**
- Checks Grafana connectivity
- Gets real Prometheus datasource UID automatically
- Creates `alerts` folder in Grafana
- Reads contact points configuration from `k8s/grafana/provisioning/contact-points.yaml`:
  - Creates email contact point using SMTP settings
  - Configures notification policies
  - Sets up email templates for alerts
- Reads alert rules from `k8s/grafana/provisioning/alert-rules.yaml`:
  - **High CPU Usage**: Triggers when CPU > 80% for 5 minutes
  - **High Memory Usage**: Triggers when Memory > 85% for 5 minutes  
  - **Low CPU Test Alert**: Triggers when CPU > 10% for 1 minute (for testing)
- Creates all alert rules with proper Grafana API format
- Uses environment variables for dynamic configuration

**Verification:**
```bash
# Check alert rules in Grafana UI
# Go to: Alerting → Alert Rules (should show 3 rules)
# Go to: Alerting → Contact points (should show email-alerts)
# Go to: Alerting → Notification policies (should use email-alerts)

# The Low CPU Test Alert should trigger immediately
# Check your email for test notifications
```

## Dashboard Import

After completing the installation steps, import the pre-built dashboards for comprehensive monitoring:

### Step 4: Import Kubernetes Cluster Dashboard

1. **Access Grafana**: http://localhost:3000 (admin / admin123)
2. **Import Dashboard**: 
   - Click **+** → **Import**
   - Copy content from `k8s/grafana/minikube/kubernetes-dashboard-extended.json`
   - Paste JSON content → **Load** → **Import**

**Dashboard Features:**
- **Cluster CPU Usage**: Real-time CPU utilization across all nodes
- **Cluster Memory Usage**: Memory consumption and availability
- **Running Pods**: Count and distribution by namespace
- **Network Traffic**: RX/TX network statistics
- **Disk I/O**: Read/write operations and throughput
- **System Load Average**: 1m, 5m, 15m load averages
- **Resource Usage by Namespace**: CPU and memory breakdown
- **Node and Namespace Statistics**: Comprehensive cluster overview

### Step 5: Import Flask Application Dashboard

1. **Import Dashboard**:
   - Click **+** → **Import**
   - Copy content from `k8s/grafana/minikube/flask-app-dashboard.json`
   - Paste JSON content → **Load** → **Import**

**Dashboard Features:**
- **Total Flask Requests**: Cumulative request counter
- **Request Rate**: Requests per second (req/sec)
- **Response Time Percentiles**: 50th, 95th, 99th percentile latencies
- **Error Rate**: 4xx/5xx error tracking
- **Request Rate by Endpoint**: Per-endpoint traffic analysis
- **Flask Pod CPU Usage**: Application container CPU consumption
- **Flask Pod Memory Usage**: Application container memory usage
- **Health Monitoring**: Application health and availability metrics

## Configuration Files

### Contact Points Configuration
**File**: `k8s/grafana/provisioning/contact-points.yaml`

Contains:
- Email contact point configuration using SMTP settings from `.env`
- Notification policies for alert routing
- Email templates with alert details
- Group-by and timing configurations

### Alert Rules Configuration  
**File**: `k8s/grafana/provisioning/alert-rules.yaml`

Contains:
- **High CPU Alert**: Production threshold (80% for 5 minutes)
- **High Memory Alert**: Production threshold (85% for 5 minutes)
- **Low CPU Test Alert**: Testing threshold (10% for 1 minute)
- Proper Grafana API format with datasource UIDs
- Expression queries for threshold evaluation
- Annotations and labels for alert context

## Environment Variables

Required in `.env` file:
```bash
# Grafana Admin Credentials
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=admin123

# SMTP Configuration for Alerts
SMTP_HOST=smtp.gmail.com
SMTP_PORT=465
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-app-password
SMTP_FROM_ADDRESS=your-email@gmail.com
SMTP_FROM_NAME=Grafana Alerts
```

## Testing Alerts

The monitoring setup includes a low-threshold test alert that should trigger immediately:

```bash
# Check alert status in Grafana
# Go to: Alerting → Alert Rules
# "Low CPU Test Alert" should show "Firing" status

# Check your email for alert notifications
# Subject: "Grafana Alert: Low CPU Test Alert"
```

## Accessing Services

```bash
# Prometheus Web UI
kubectl port-forward svc/prometheus-kube-prometheus-stack-prometheus 9090:9090 -n monitoring
# Open: http://localhost:9090

# Grafana Web UI  
kubectl port-forward svc/grafana 3000:3000 -n monitoring
# Open: http://localhost:3000 (admin / admin123)

# Flask Application (if deployed)
kubectl port-forward svc/flask-app 8080:8080 -n flask-app
# Open: http://localhost:8080
# Metrics: http://localhost:8080/metrics
```

## Troubleshooting

### Common Issues

**Prometheus not collecting Flask metrics:**
```bash
# Check ServiceMonitor
kubectl get servicemonitor -n monitoring

# Verify Flask app has metrics endpoint
curl http://localhost:8080/metrics

# Check Prometheus targets
# Go to: http://localhost:9090/targets
```

**Grafana alerts not working:**
```bash
# Check Grafana logs
kubectl logs deployment/grafana -n monitoring

# Verify SMTP settings in Grafana UI
# Go to: Administration → Settings → SMTP

# Test contact point
# Go to: Alerting → Contact points → Test
```

**Dashboard panels showing "No data":**
```bash
# Check Prometheus datasource in Grafana
# Go to: Configuration → Data sources → Prometheus → Test

# Verify queries in Explore tab
# Go to: Explore → Select Prometheus → Test queries
```

## Monitoring Queries

Key Prometheus queries used in dashboards and alerts:

```promql
# CPU Usage
avg(1 - rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100

# Memory Usage  
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Flask Request Rate
rate(flask_requests_total[5m])

# Pod CPU Usage
sum(rate(container_cpu_usage_seconds_total[5m])) by (pod)

# Pod Memory Usage
sum(container_memory_working_set_bytes) by (pod)
```

## File Structure

```
k8s/grafana/
├── minikube/
│   ├── kubernetes-dashboard-extended.json  # Kubernetes cluster dashboard
│   ├── flask-app-dashboard.json            # Flask application dashboard
│   └── values-minikube.yaml                # Grafana Helm values
└── provisioning/
    ├── contact-points.yaml                 # Email contact points config
    └── alert-rules.yaml                    # Alert rules configuration
```

## Next Steps

1. **Customize Thresholds**: Adjust CPU/Memory alert thresholds in `alert-rules.yaml`
2. **Add More Metrics**: Extend Flask app with custom business metrics
3. **Create Custom Dashboards**: Build dashboards for specific use cases
4. **Set Up Log Aggregation**: Add ELK stack or Loki for log monitoring
5. **Implement SLOs**: Define and monitor Service Level Objectives

This monitoring setup provides a solid foundation for observability in your Kubernetes environment with comprehensive metrics, visualization, and alerting capabilities.