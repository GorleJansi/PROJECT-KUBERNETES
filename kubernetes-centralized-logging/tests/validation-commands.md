# Validation Commands

Run these commands from inside `kubernetes-centralized-logging/`.

## Application

```bash
kubectl get ns logging-demo
kubectl get deploy,pods -n logging-demo
kubectl logs -n logging-demo deploy/frontend --tail=20
kubectl logs -n logging-demo deploy/cart --tail=20
kubectl logs -n logging-demo deploy/payment --tail=20
```

## Loki

```bash
kubectl get pods,svc -n logging -l app.kubernetes.io/instance=loki
kubectl get svc -n logging loki-gateway
kubectl port-forward -n logging svc/loki-gateway 3100:80
```

In another terminal:

```bash
curl -G 'http://localhost:3100/loki/api/v1/query' \
  --data-urlencode 'query={namespace="logging-demo"}'
```

## Fluent Bit

```bash
kubectl get ds,pods -n logging -l app.kubernetes.io/name=fluent-bit
kubectl logs -n logging -l app.kubernetes.io/name=fluent-bit --tail=100
kubectl exec -n logging ds/fluent-bit -- ls -l /var/log/containers | head
```

Expected healthy signs:

- Fluent Bit pods are running on each node.
- Fluent Bit logs do not show repeated `connection refused` to Loki.
- Loki query returns streams from `logging-demo`.

## Grafana

```bash
kubectl get svc -n logging grafana
kubectl get configmap -n logging grafana-logging-dashboard
```

Open Grafana using the LoadBalancer address or port-forward:

```bash
kubectl port-forward -n logging svc/grafana 3000:80
```

Login:

```text
username: admin
password: admin123
```

Open Explore and run:

```logql
{namespace="logging-demo"}
```

For errors only:

```logql
{namespace="logging-demo"} |= "ERROR"
```

## Generate Manual Errors

```bash
sh tests/generate-errors.sh
```

Then query:

```logql
{namespace="logging-demo"} |= "manual test error"
```

## Cleanup Test Pods

```bash
kubectl delete pod -n logging-demo -l test=manual-error
```
