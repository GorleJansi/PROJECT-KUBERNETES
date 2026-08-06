# EKS Daily Practice Tools

Daily helper scripts for starting an existing EKS lab, checking health, running kubectl practice, cleaning practice resources, stopping worker nodes, and deleting the cluster when it is no longer needed.

## Files

| File | Purpose |
| --- | --- |
| `setup-terraform-eks.sh` | One-file EC2 setup for Terraform-based EKS creation. |
| `install-terraform.sh` | Installs Terraform on Linux. |
| `terraform/` | Terraform project for VPC, IAM, EKS cluster, node group, and add-ons. |
| `setup-workstation-cluster.sh` | Legacy one-file EC2 workstation and EKS setup using eksctl. |
| `install-tools.sh` | Installs AWS CLI, kubectl, and eksctl together. |
| `install-aws-cli.sh` | Installs or updates AWS CLI v2 on Linux. |
| `install-kubectl.sh` | Installs kubectl on Linux. |
| `install-eksctl.sh` | Installs eksctl on Linux. |
| `cluster.yaml` | Optional eksctl config-file version of the cluster setup. |
| `config.sh` | Shared cluster, node group, region, and namespace settings. |
| `create-cluster.sh` | Creates the EKS cluster for the first time. |
| `start.sh` | Starts the managed node group with two worker nodes. |
| `status.sh` | Checks AWS identity, EKS cluster, node group, nodes, system Pods, and lab resources. |
| `practice.sh` | Runs daily kubectl practice in the `daily-lab` namespace. |
| `cleanup.sh` | Deletes only the daily practice namespace and resources. |
| `stop.sh` | Deletes daily resources and scales worker nodes down to zero. |
| `delete-all.sh` | Permanently deletes the EKS cluster. |

## Clone Correctly

Do not clone the GitHub folder URL. Clone the repository, then enter
`eks-daily`:

```bash
git clone https://github.com/GorleJansi/PROJECT-KUBERNETES.git
cd PROJECT-KUBERNETES/eks-daily
```

If you want only this folder:

```bash
git clone --filter=blob:none --sparse https://github.com/GorleJansi/PROJECT-KUBERNETES.git
cd PROJECT-KUBERNETES
git sparse-checkout set eks-daily
cd eks-daily
```

## Recommended Terraform Setup

Use this path for the project. It creates EKS with Terraform instead of
`eksctl` and avoids creating new `eksctl-roboshop-dev-*` CloudFormation stacks.

Before running Terraform, confirm the old eksctl stacks are gone:

```bash
aws cloudformation list-stacks \
  --region us-east-1 \
  --query "StackSummaries[?contains(StackName, 'eksctl-roboshop-dev') && StackStatus!='DELETE_COMPLETE'].[StackName,StackStatus]" \
  --output table
```

Expected result: empty output.

Then run:

```bash
./setup-terraform-eks.sh
```

Type:

```text
TERRAFORM
```

This one script:

1. Installs AWS CLI if needed.
2. Installs kubectl if needed.
3. Installs Terraform if needed.
4. Checks AWS identity.
5. Runs `terraform init`.
6. Runs `terraform apply`.
7. Updates kubeconfig.
8. Checks Kubernetes nodes.

Manual Terraform workflow:

```bash
cd terraform
terraform init
terraform plan
terraform apply
aws eks update-kubeconfig --name roboshop-dev --region us-east-1
kubectl get nodes
```

Destroy when finished:

```bash
cd terraform
terraform destroy
```

## Legacy Eksctl Setup

Use this on a fresh EC2 workstation when you want one script for everything:

```bash
./setup-workstation-cluster.sh
```

This one file does the full flow:

1. Installs required workstation tools: AWS CLI, kubectl, and eksctl.
2. Checks AWS identity with `aws sts get-caller-identity`.
3. Creates the EKS control plane if it does not exist.
4. Waits until the EKS cluster is `ACTIVE`.
5. Creates the managed node group if it does not exist.
6. Scales the node group to the configured desired node count.
7. Updates kubeconfig.
8. Waits for Kubernetes nodes to become `Ready`.
9. Prints node and node group status.

The script asks you to type `SETUP` before it installs tools or creates AWS
resources.

Use this when the cluster exists but the node group is missing too. It will
reuse the active cluster and create the missing managed node group.

## Install Tools Only

Run this on the EC2 instance before creating the cluster:

```bash
./install-tools.sh
```

This installs:

| Tool | Script |
| --- | --- |
| AWS CLI v2 | `install-aws-cli.sh` |
| kubectl | `install-kubectl.sh` |
| eksctl | `install-eksctl.sh` |

You can also run them one by one:

```bash
./install-aws-cli.sh
./install-kubectl.sh
./install-eksctl.sh
```

## Prerequisites Check

Check the tools:

```bash
aws --version
kubectl version --client
eksctl version
```

The AWS CLI must be authenticated to the account that owns the EKS cluster:

```bash
aws sts get-caller-identity
```

## Cluster Setup Only

Run all commands from this folder:

```bash
cd eks-daily
```

Create the EKS cluster:

```bash
./create-cluster.sh
```

This script assumes AWS CLI, kubectl, and eksctl already exist. For a fresh EC2
workstation, prefer:

```bash
./setup-workstation-cluster.sh
```

The direct `eksctl` command is:

```bash
eksctl create cluster \
  --name roboshop-dev \
  --region us-east-1 \
  --managed \
  --nodes 2 \
  --node-type t3.medium
```

`create-cluster.sh` uses the same setup and also adds
`--nodegroup-name roboshop-dev-ng`, `--nodes-min 0`, and `--nodes-max 2`,
because the daily `start.sh`, `status.sh`, and `stop.sh` scripts need a stable
node group name and a node group that can scale down after practice.

The script creates:

| Setting | Value |
| --- | --- |
| Cluster name | `roboshop-dev` |
| Region | `us-east-1` |
| Node group | `roboshop-dev-ng` |
| Capacity type | Managed on-demand node group |
| Instance type | `t3.medium` |
| Node size | min `0`, desired `2`, max `2` |

The script asks you to type `CREATE` before it creates AWS resources.

If the control plane already exists but the node group is missing,
`create-cluster.sh` creates the missing node group and continues.

After creation, it updates kubeconfig and checks:

```bash
kubectl get nodes
eksctl get nodegroup --cluster roboshop-dev --region us-east-1
```

Important: EKS control plane and EC2 worker nodes can create AWS charges. Use
`./stop.sh` after practice, or `./delete-all.sh` when you no longer need the
cluster.

## Configuration

Default values are in `config.sh`:

```bash
AWS_REGION=us-east-1
CLUSTER_NAME=roboshop-dev
NODEGROUP_NAME=roboshop-dev-ng
DESIRED_NODES=2
MAX_NODES=2
NODE_TYPE=t3.medium
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

If Amazon Linux 2023 shows a `curl-minimal conflicts with curl` error, do not
replace `curl-minimal`. The scripts use the existing `curl` command from
`curl-minimal` and install only the missing helper packages.

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
