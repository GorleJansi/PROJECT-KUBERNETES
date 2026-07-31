#!/bin/sh
set -eu

NAMESPACE="${NAMESPACE:-logging-demo}"
COUNT="${COUNT:-10}"

kubectl get namespace "$NAMESPACE" >/dev/null

for service in frontend cart payment; do
  pod_name="manual-error-${service}-$(date +%s)"
  kubectl run "$pod_name" \
    --namespace "$NAMESPACE" \
    --image busybox:1.36 \
    --restart Never \
    --labels "component=${service},project=central-logging,test=manual-error" \
    --command -- sh -c "
      i=1
      while [ \"\$i\" -le \"$COUNT\" ]; do
        printf '{\"service\":\"$service\",\"level\":\"ERROR\",\"message\":\"manual test error\",\"request_id\":\"manual-%s\"}\n' \"\$i\"
        i=\$((i + 1))
        sleep 1
      done
    "
done

kubectl get pods --namespace "$NAMESPACE" -l test=manual-error
