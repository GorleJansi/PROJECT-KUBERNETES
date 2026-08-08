# PROJECT-KUBERNETES

Hands-on Kubernetes practice repository for manifests, troubleshooting notes,
EKS lab automation, RBAC, storage, ingress, and centralized logging.

## Repository Layout

| Path | Purpose |
| --- | --- |
| `01-namespace.yaml` to `51-podDisruptionBudget.yaml` | Core Kubernetes manifest practice, ordered from basic Pods to RBAC and disruption budgets. |
| `Errors/` | Troubleshooting notes for common Kubernetes and CI/CD failure scenarios. |
| `eks-daily/` | Terraform-based EKS daily practice lab with start, stop, status, cleanup, and destroy scripts. |
| `kubernetes-centralized-logging/` | Fluent Bit, Loki, and Grafana logging lab with sample applications and validation commands. |
| `rbac/` | Namespace Role and RoleBinding examples for restricted Kubernetes access. |
| `volumes/` | EmptyDir, hostPath, PersistentVolume, PersistentVolumeClaim, and StorageClass practice. |
| `ingress/` | Frontend, backend, and Ingress examples. |
| `envfrom_files/` | ConfigMap and Secret examples used with environment injection. |
| `initcontainer/` | Init container and shared file examples. |
| `blue-green-app-upgrade/` | Blue/green Deployment and Service manifests. |
| `ROBOSHOP-KUBERNETES/` | Separate nested Git repository for RoboShop Kubernetes manifests. |

## Common Commands

Validate YAML syntax before applying manifests:

```bash
kubectl apply --dry-run=client -f <file>.yaml
```

Apply a manifest:

```bash
kubectl apply -f <file>.yaml
```

Check resources:

```bash
kubectl get pods -A
kubectl get svc -A
kubectl get events -A --sort-by=.lastTimestamp
```

Inspect a failing workload:

```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --previous
```

## EKS Daily Lab

The `eks-daily/` folder is the main AWS EKS practice workflow. It uses Terraform
for cluster creation and scripts for repeatable daily operations.

```bash
cd eks-daily
chmod +x *.sh
./setup-terraform-eks.sh
./status.sh
./practice.sh
./cleanup.sh
```

Use `./stop.sh` to scale worker nodes down after practice, and `./start.sh` to
scale them back up.

## Troubleshooting Notes

The `Errors/` folder contains short incident-style notes for common Kubernetes
problems such as:

- Pod Pending
- ImagePullBackOff
- CrashLoopBackOff
- OOMKilled
- FailedMount
- Node NotReady
- Ingress 404/503
- RBAC forbidden errors
- HPA and metrics-server issues
- CI/CD `npm ci` and `npm run build` flow

## Git Notes

`ROBOSHOP-KUBERNETES/` is an independent nested Git repository. Commit and push
inside that folder only when changes there are intentional.

For this parent repository, stage focused files instead of blindly staging every
path:

```bash
git status --short
git add <file-or-folder>
git commit -m "message"
git push origin main
```
