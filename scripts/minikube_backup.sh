#!/bin/bash
set -e

BACKUP_DIR="$HOME/Desktop/minikube_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR/pvcs"

#-----------------------------------------------------------------------
# 1. CONFIGURATION
#-----------------------------------------------------------------------
REQUIRED_PODS=(
  "jenkins/jenkins-0"
)

declare -A PVC_PATHS=(
  ["jenkins/jenkins"]="/var/jenkins_home"
)

#-----------------------------------------------------------------------
# 2. POD VERIFICATION
#-----------------------------------------------------------------------
echo "1. Checking required pods..."
for pod_spec in "${REQUIRED_PODS[@]}"; do
  namespace="${pod_spec%%/*}"
  pod="${pod_spec##*/}"
  if ! kubectl get pod -n "$namespace" "$pod" >/dev/null 2>&1; then
    echo "[ERROR] Pod '$pod' in namespace '$namespace' is not running!"
    case "$pod_spec" in
      "jenkins/jenkins-0")
        echo "> Run: kubectl scale sts jenkins --replicas=1 -n jenkins"
        ;;
    esac
    exit 1
  fi
done

#-----------------------------------------------------------------------
# 3. PVC BACKUP (NEW BASE64 METHOD)
#-----------------------------------------------------------------------
echo "2. Backing up PVCs..."
kubectl get pvc -A --no-headers | while read -r namespace pvc rest; do
  echo "-> Processing PVC: $namespace/$pvc"
  
  case "$namespace/$pvc" in
    "jenkins/jenkins")
      path="${PVC_PATHS[jenkins/jenkins]}"
      pod="jenkins-0"
      container="jenkins"
      backup_file="$BACKUP_DIR/pvcs/pvc_${namespace}_${pvc}.tar"
      
      echo "  - Using pod: $pod (path: $path, container: $container)"
      
      # 1. Checking the availability of the path
      if ! kubectl exec -n "$namespace" "$pod" -c "$container" -- sh -c "test -d $path" 2>/dev/null; then
        echo "  [ERROR] Path $path not found in pod $pod"
        exit 1
      fi
      
      # 2. Create an archive inside the container and encode it in base64
      echo "  - Creating and transferring backup (this may take a while)..."
      kubectl exec -n "$namespace" "$pod" -c "$container" -- sh -c \
        "tar cz -C $path . | base64" > "${backup_file}.b64" || {
        echo "  [ERROR] Failed to create backup archive"
        exit 1
      }
      
      # 3. Decode the archive on the host
      base64 -d "${backup_file}.b64" > "$backup_file" || {
        echo "  [ERROR] Failed to decode backup file"
        rm -f "${backup_file}.b64"
        exit 1
      }
      
      # 4. Check the integrity of the archive
      if ! tar tzf "$backup_file" >/dev/null 2>&1; then
        echo "  [ERROR] Backup file is corrupted"
        rm -f "${backup_file}.b64"
        exit 1
      fi
      
      # 5. Cleaning temporary files
      rm -f "${backup_file}.b64"
      echo "  - Backup successfully saved to: $backup_file"
      ;;
      
    *)
      echo "  [WARN] No backup handler for PVC $namespace/$pvc"
      ;;
  esac
done

#-----------------------------------------------------------------------
#4. MINIKUBE BACKUP
#-----------------------------------------------------------------------
echo "3. Stopping Minikube..."
minikube stop

echo "4. Copying Minikube data..."
cp -r "$USERPROFILE/.minikube" "$BACKUP_DIR"

echo "5. Compressing backup..."
tar -czvf "$BACKUP_DIR.tar.gz" -C "$BACKUP_DIR" .
rm -rf "$BACKUP_DIR"

echo "6. Backup saved to: $BACKUP_DIR.tar.gz"
minikube start