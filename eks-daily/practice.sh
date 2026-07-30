#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

require_command() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "ERROR: required command not found: $1"
        exit 1
    }
}

require_command kubectl
require_command awk

echo "========================================"
echo "Checking worker nodes"
echo "========================================"

READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null |
    awk '$2 == "Ready" {count++} END {print count+0}')

if [[ "$READY_NODES" -eq 0 ]]; then
    echo "No Ready worker nodes."
    echo "Run: $SCRIPT_DIR/start.sh"
    exit 1
fi

echo "$READY_NODES worker nodes are Ready."

echo
echo "========================================"
echo "1. Creating namespace"
echo "========================================"

kubectl create namespace "$LAB_NAMESPACE" \
  --dry-run=client \
  -o yaml |
kubectl apply -f -

echo
echo "========================================"
echo "2. Creating ConfigMap"
echo "========================================"

kubectl create configmap web-config \
  --namespace "$LAB_NAMESPACE" \
  --from-literal=APP_NAME="Daily EKS Lab" \
  --from-literal=ENVIRONMENT="learning" \
  --dry-run=client \
  -o yaml |
kubectl apply -f -

echo
echo "========================================"
echo "3. Creating Deployment and Service"
echo "========================================"

kubectl apply -f - <<EOFYAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-web
  namespace: ${LAB_NAMESPACE}
  labels:
    app: nginx-web
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: nginx-web
  template:
    metadata:
      labels:
        app: nginx-web
    spec:
      containers:
        - name: nginx
          image: nginx:alpine
          ports:
            - name: http
              containerPort: 80
          resources:
            requests:
              cpu: 20m
              memory: 32Mi
            limits:
              cpu: 100m
              memory: 64Mi
          readinessProbe:
            httpGet:
              path: /
              port: http
            initialDelaySeconds: 3
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /
              port: http
            initialDelaySeconds: 10
            periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
  namespace: ${LAB_NAMESPACE}
spec:
  type: ClusterIP
  selector:
    app: nginx-web
  ports:
    - name: http
      port: 80
      targetPort: http
EOFYAML

echo
echo "Waiting for Deployment rollout..."

kubectl rollout status \
  deployment/nginx-web \
  --namespace "$LAB_NAMESPACE" \
  --timeout=5m

echo
echo "========================================"
echo "4. Deployment, ReplicaSet and Pods"
echo "========================================"

kubectl get deployment,replicaset,pods \
  --namespace "$LAB_NAMESPACE" \
  -o wide

echo
echo "========================================"
echo "5. Service and EndpointSlices"
echo "========================================"

kubectl get service,endpointslice \
  --namespace "$LAB_NAMESPACE" \
  -o wide

echo
echo "========================================"
echo "6. Testing Kubernetes self-healing"
echo "========================================"

OLD_POD=$(kubectl get pods \
  --namespace "$LAB_NAMESPACE" \
  -l app=nginx-web \
  -o jsonpath='{.items[0].metadata.name}')

echo "Deleting Pod: $OLD_POD"

kubectl delete pod "$OLD_POD" \
  --namespace "$LAB_NAMESPACE"

echo
echo "ReplicaSet creates a replacement Pod:"

kubectl wait \
  --for=condition=Ready \
  pod \
  --namespace "$LAB_NAMESPACE" \
  -l app=nginx-web \
  --timeout=5m

kubectl get pods \
  --namespace "$LAB_NAMESPACE" \
  -o wide

echo
echo "========================================"
echo "7. Testing service internally"
echo "========================================"

kubectl delete pod curl-test \
  --namespace "$LAB_NAMESPACE" \
  --ignore-not-found=true \
  --wait=false \
  >/dev/null 2>&1 || true

kubectl run curl-test \
  --namespace "$LAB_NAMESPACE" \
  --image=curlimages/curl \
  --restart=Never \
  --rm \
  -i \
  --command -- \
  curl --fail --silent \
  http://nginx-service

echo
echo
echo "========================================"
echo "DAILY PRACTICE COMPLETE"
echo "========================================"

echo "Useful commands:"
echo
echo "kubectl get all -n $LAB_NAMESPACE"
echo "kubectl describe deployment nginx-web -n $LAB_NAMESPACE"
echo "kubectl describe pod <pod-name> -n $LAB_NAMESPACE"
echo "kubectl logs <pod-name> -n $LAB_NAMESPACE"
echo "kubectl scale deployment nginx-web --replicas=3 -n $LAB_NAMESPACE"
echo "kubectl rollout history deployment/nginx-web -n $LAB_NAMESPACE"
echo
echo "Clean the lab:"
echo "  $SCRIPT_DIR/cleanup.sh"
echo
echo "Stop worker nodes:"
echo "  $SCRIPT_DIR/stop.sh"
