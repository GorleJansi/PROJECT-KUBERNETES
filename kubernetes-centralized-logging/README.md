# Kubernetes Centralized Logging

This lab sends Kubernetes application logs to Loki using Fluent Bit and views them in Grafana.

## Components

- `application/`: sample frontend, cart, and payment Deployments that write JSON logs to stdout.
- `fluent-bit/`: DaemonSet, RBAC, and configuration to collect node container logs.
- `loki/`: Helm values for a small monolithic Loki deployment.
- `grafana/`: Helm values and dashboard JSON for viewing Loki logs.
- `tests/`: error generation and validation commands.

## Namespaces

- `logging-demo`: sample applications
- `logging`: Fluent Bit, Loki, and Grafana

## Deploy

Run these commands from inside `kubernetes-centralized-logging/`.

```bash
kubectl apply -f application/namespace.yaml
kubectl apply -f application/
kubectl apply -f fluent-bit/namespace.yaml
```

Install Loki and Grafana with the Grafana Community Helm chart repository.

```bash
helm repo add grafana-community https://grafana-community.github.io/helm-charts
helm repo update

helm upgrade --install loki grafana-community/loki \
  --namespace logging \
  --values loki/loki-values.yaml

kubectl create configmap grafana-logging-dashboard \
  --namespace logging \
  --from-file=logging-dashboard.json=grafana/dashboard.json \
  --dry-run=client \
  -o yaml | kubectl apply -f -

helm upgrade --install grafana grafana-community/grafana \
  --namespace logging \
  --values grafana/grafana-values.yaml
```

Deploy Fluent Bit after Loki is reachable.

```bash
kubectl apply -f fluent-bit/
```

## Validate

```bash
kubectl get pods -n logging-demo
kubectl get pods -n logging
kubectl logs -n logging -l app.kubernetes.io/name=fluent-bit --tail=50
kubectl port-forward -n logging svc/loki-gateway 3100:80
```

In another terminal:

```bash
curl -G 'http://localhost:3100/loki/api/v1/query' \
  --data-urlencode 'query={namespace="logging-demo"}'
```

Open Grafana:

```bash
kubectl get svc -n logging grafana
```

Login:

```text
username: admin
password: admin123
```

## Test Errors

```bash
sh tests/generate-errors.sh
```

Then query in Grafana Explore:

```logql
{namespace="logging-demo"} |= "ERROR"
```

## Cleanup

```bash
kubectl delete -f fluent-bit/
helm uninstall grafana -n logging
helm uninstall loki -n logging
kubectl delete -f application/
kubectl delete ns logging logging-demo
```
