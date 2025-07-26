#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "[ERROR] Usage: $0 <path_to_backup.tar.gz>"
  exit 1
fi

BACKUP_FILE="$1"
RESTORE_DIR="$USERPROFILE/.minikube_restored"

#-----------------------------------------------------------------------
# 1. CONFIGURATION
#-----------------------------------------------------------------------
declare -A PVC_PATHS=(
  ["jenkins/jenkins"]="/var/jenkins_home"
)

#-----------------------------------------------------------------------
# 2. EXTRACT BACKUP
#-----------------------------------------------------------------------
echo "1. Extracting backup..."
mkdir -p "$RESTORE_DIR"
tar -xzvf "$BACKUP_FILE" -C "$RESTORE_DIR"

#-----------------------------------------------------------------------
# 3. RESTORE MINIKUBE
#-----------------------------------------------------------------------
echo "2. Stopping Minikube..."
minikube stop 2>/dev/null || true

echo "3. Restoring Minikube data..."
rm -rf "$USERPROFILE/.minikube"
cp -r "$RESTORE_DIR/.minikube" "$USERPROFILE/.minikube"

echo "4. Starting Minikube..."
minikube start

#-----------------------------------------------------------------------
# 4. RESTORE PVCs (BASE64 METHOD)
#-----------------------------------------------------------------------
echo "5. Restoring PVCs..."
if [ -d "$RESTORE_DIR/pvcs" ]; then
  for pvc_tar in "$RESTORE_DIR/pvcs"/pvc_*.tar; do
    [ -f "$pvc_tar" ] || continue
    
    pvc_name=$(basename "$pvc_tar" | sed 's/^pvc_//;s/\.tar$//')
    namespace=$(echo "$pvc_name" | cut -d_ -f1)
    pvc=$(echo "$pvc_name" | cut -d_ -f2-)
    
    echo "-> Restoring PVC: $namespace/$pvc"
    
    case "$namespace/$pvc" in
      "jenkins/jenkins")
        path="${PVC_PATHS[jenkins/jenkins]}"
        pod="jenkins-0"
        container="jenkins"
        
        if ! kubectl get pod -n "$namespace" "$pod" >/dev/null 2>&1; then
          echo "  [ERROR] Pod $pod not running in namespace $namespace"
          exit 1
        fi
        
        echo "  - Restoring to pod: $pod (path: $path, container: $container)"
        
        # 1. Encode the archive in base64
        echo "  - Encoding and transferring backup (this may take a while)..."
        base64 "$pvc_tar" | kubectl exec -n "$namespace" "$pod" -c "$container" -i -- sh -c \
          "base64 -d | tar xz -C $path" || {
          echo "  [ERROR] Failed to restore backup"
          exit 1
        }
        
        echo "  - Successfully restored Jenkins data"
        ;;
        
      *)
        echo "  [WARN] No restore handler for PVC $namespace/$pvc"
        ;;
    esac
  done
fi

#-----------------------------------------------------------------------
# 5. POST-RESTORE CHECKS
#-----------------------------------------------------------------------
echo "6. Verifying Jenkins restoration..."
jenkins_pod=$(kubectl get pods -n jenkins -l app.kubernetes.io/component=jenkins-master -o jsonpath="{.items[0].metadata.name}")
if [ -n "$jenkins_pod" ]; then
  echo "  - Jenkins pod: $jenkins_pod"
  echo "  - Checking key files:"
  kubectl exec -n jenkins "$jenkins_pod" -- ls -la /var/jenkins_home/secrets/
  kubectl exec -n jenkins "$jenkins_pod" -- ls -la /var/jenkins_home/jobs/
else
  echo "  [WARN] Jenkins pod not found"
fi

#-----------------------------------------------------------------------
# 6. CLEANUP
#-----------------------------------------------------------------------
echo "7. Restoration complete!"
rm -rf "$RESTORE_DIR"