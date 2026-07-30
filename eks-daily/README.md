# EKS Daily Practice Tools

Daily helper scripts for starting an existing EKS lab, checking health, running kubectl practice, cleaning practice resources, stopping worker nodes, and deleting the cluster when it is no longer needed.

## Files

| File | Purpose |
| --- | --- |
| `config.sh` | Shared cluster, node group, region, and namespace settings. |
| `start.sh` | Starts the managed node group with two worker nodes. |
| `status.sh` | Checks AWS identity, EKS cluster, node group, nodes, system Pods, and lab resources. |
| `practice.sh` | Runs daily kubectl practice in the `daily-lab` namespace. |
| `cleanup.sh` | Deletes only the daily practice namespace and resources. |
| `stop.sh` | Deletes daily resources and scales worker nodes down to zero. |
| `delete-all.sh` | Permanently deletes the EKS cluster. |

## Prerequisites

Install and configure these tools before running the scripts:

```bash
aws --version
kubectl version --client
eksctl version
```

The AWS CLI must be authenticated to the account that owns the EKS cluster:

```bash
aws sts get-caller-identity
```

## Configuration

Default values are in `config.sh`:

```bash
AWS_REGION=us-east-1
CLUSTER_NAME=roboshop-dev
NODEGROUP_NAME=roboshop-free-spot-ng
DESIRED_NODES=2
MAX_NODES=2
LAB_NAMESPACE=daily-lab
```

Edit `config.sh` if your cluster name, node group name, or AWS region changes.

You can also override values for one command:

```bash
AWS_REGION=us-east-2 CLUSTER_NAME=my-cluster ./status.sh
```

## Daily Workflow

Run all commands from this folder:

```bash
cd eks-daily
```

Start the lab:

```bash
./start.sh
```

This checks the EKS control plane, scales the managed node group to two desired worker nodes, updates kubeconfig, and waits until the Kubernetes nodes are Ready.

Check cluster health:

```bash
./status.sh
```

Run daily kubectl practice:

```bash
./practice.sh
```

This creates the `daily-lab` namespace, ConfigMap, Deployment, ReplicaSet, Pods, ClusterIP Service, EndpointSlice, readiness and liveness probes, resource requests and limits, and tests Pod self-healing and internal service connectivity.

Clean only the practice resources:

```bash
./cleanup.sh
```

Stop worker nodes after practice:

```bash
./stop.sh
```

This deletes the daily lab namespace if it exists and scales the node group to:

```text
minSize=0
desiredSize=0
maxSize=2
```

## Manual Practice Commands

After running `practice.sh`, use these commands for extra practice:

```bash
kubectl get all -n daily-lab
kubectl get pods -n daily-lab -o wide
kubectl describe deployment nginx-web -n daily-lab
kubectl get service,endpointslice -n daily-lab
kubectl scale deployment nginx-web --replicas=3 -n daily-lab
kubectl rollout status deployment/nginx-web -n daily-lab
kubectl set image deployment/nginx-web nginx=nginx:latest -n daily-lab
kubectl rollout history deployment/nginx-web -n daily-lab
kubectl rollout undo deployment/nginx-web -n daily-lab
```

## Permanent Delete

Use this only when you want to permanently delete the EKS cluster:

```bash
./delete-all.sh
```

The script asks you to type `DELETE` before it runs `eksctl delete cluster`.

## Cost Note

`stop.sh` stops the worker nodes by scaling the managed node group to zero, but it does not delete the EKS control plane. If you will not practice for several days, use `delete-all.sh` to remove the cluster completely.

## Troubleshooting

If no nodes are Ready:

```bash
./status.sh
```

If AWS authentication fails:

```bash
aws sts get-caller-identity
aws eks update-kubeconfig --name roboshop-dev --region us-east-1
```

If kubectl says `Unauthorized`, check AWS/EKS authentication and kubeconfig. If kubectl says `Forbidden`, authentication worked but Kubernetes RBAC is denying the action.
