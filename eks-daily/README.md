# EKS Daily Terraform Lab

This folder is the EC2 workstation setup for a daily EKS practice cluster.
Terraform is the only supported cluster creation path in this folder.

## What This Creates

| Layer | Created By | Purpose |
| --- | --- | --- |
| AWS CLI | `install-aws-cli.sh` | AWS authentication and EKS kubeconfig updates. |
| kubectl | `install-kubectl.sh` | Kubernetes cluster access. |
| Terraform | `install-terraform.sh` | Infrastructure provisioning. |
| VPC and subnets | `terraform/` | Network for the lab cluster. |
| IAM roles | `terraform/` | EKS control plane and node permissions. |
| EKS cluster | `terraform/` | Kubernetes control plane named `roboshop-dev`. |
| Managed node group | `terraform/` | Worker nodes named `roboshop-dev-ng`. |
| Kubernetes practice resources | `practice.sh` | Daily namespace, Deployment, Service, probes, and service test. |

## Files

| File | Purpose |
| --- | --- |
| `DELETE-STEPS.md` | Exact cleanup, stop, and full delete steps after practice. |
| `setup-terraform-eks.sh` | One command for EC2 tool install, Terraform apply, kubeconfig, and node check. |
| `install-tools.sh` | Installs AWS CLI, kubectl, and Terraform. |
| `install-aws-cli.sh` | Installs or updates AWS CLI v2 on Linux. |
| `install-kubectl.sh` | Installs kubectl on Linux. |
| `install-terraform.sh` | Installs Terraform on Linux. |
| `terraform/` | Terraform code for VPC, IAM, EKS, node group, and add-ons. |
| `config.sh` | Shared cluster, node group, region, and namespace settings. |
| `status.sh` | Checks AWS identity, EKS cluster, node group, nodes, system Pods, and lab resources. |
| `start.sh` | Scales the Terraform-created managed node group back to two nodes. |
| `stop.sh` | Deletes daily resources and scales worker nodes to zero. |
| `practice.sh` | Runs daily kubectl practice in the `daily-lab` namespace. |
| `cleanup.sh` | Deletes only the daily practice namespace. |
| `delete-all.sh` | Runs Terraform destroy for the lab infrastructure. |

## Clone Correctly

Do not clone the GitHub folder URL. Clone the repository, then enter
`eks-daily`:

```bash
git clone https://github.com/GorleJansi/PROJECT-KUBERNETES.git
cd PROJECT-KUBERNETES/eks-daily
```

If the repo already exists on EC2:

```bash
cd ~/PROJECT-KUBERNETES
git pull
cd eks-daily
```

If `git pull` says local script edits would be overwritten, discard only those
temporary EC2 edits:

```bash
git restore eks-daily
git pull
cd eks-daily
```

## AWS Access

Use an EC2 IAM role when possible. If you temporarily use `aws configure`, rotate
the key after practice if it was pasted anywhere.

Check identity:

```bash
aws sts get-caller-identity
```

The caller needs permissions for:

```text
EC2
EKS
IAM
VPC
CloudWatch Logs
Terraform-managed resource creation and deletion
```

## Clean Old Eksctl Stacks

Before Terraform, old `eksctl` CloudFormation stacks must be gone:

```bash
aws cloudformation list-stacks \
  --region us-east-1 \
  --query "StackSummaries[?contains(StackName, 'eksctl-roboshop-dev') && StackStatus!='DELETE_COMPLETE'].[StackName,StackStatus]" \
  --output table
```

Expected result: empty output.

If stacks still exist, delete them before running Terraform. Terraform should
not be mixed with old failed `eksctl` stacks for the same cluster name.

## One Command Setup

Run from `eks-daily`:

```bash
chmod +x *.sh
./setup-terraform-eks.sh
```

Type:

```text
TERRAFORM
```

When Terraform asks for approval, type:

```text
yes
```

The setup flow is:

1. Install AWS CLI.
2. Install kubectl.
3. Install Terraform.
4. Check AWS identity.
5. Run `terraform init`.
6. Run `terraform apply`.
7. Update kubeconfig.
8. Run `kubectl get nodes`.

## Manual Terraform Flow

```bash
cd terraform
terraform init
terraform plan
terraform apply
aws eks update-kubeconfig --name roboshop-dev --region us-east-1
kubectl get nodes
```

## Verify

```bash
aws eks describe-cluster \
  --name roboshop-dev \
  --region us-east-1 \
  --query 'cluster.status'

aws eks list-nodegroups \
  --cluster-name roboshop-dev \
  --region us-east-1 \
  --output table

kubectl get nodes
./status.sh
```

## Daily Practice

Create practice resources:

```bash
./practice.sh
```

Check resources:

```bash
kubectl get all -n daily-lab
kubectl get pods -n daily-lab -o wide
kubectl get service,endpointslice -n daily-lab
kubectl describe deployment nginx-web -n daily-lab
```

Clean only practice resources:

```bash
./cleanup.sh
```

## Stop And Start Nodes

Stop worker nodes after practice:

```bash
./stop.sh
```

This keeps the EKS control plane and Terraform state, but scales the node group
to:

```text
minSize=0
desiredSize=0
maxSize=2
```

Start worker nodes again:

```bash
./start.sh
```

## Destroy Everything

For complete removal steps, use:

```bash
cat DELETE-STEPS.md
```

Short version: run this from the same EC2 checkout where `terraform apply`
created the cluster:

```bash
./delete-all.sh
```

Type:

```text
DESTROY
```

Then type `yes` when Terraform asks for approval.

Important: local Terraform state is not committed. If you want to destroy from a
different workstation, add an S3/DynamoDB remote backend first or copy the state
securely.

Verify deletion:

```bash
aws eks describe-cluster --name roboshop-dev --region us-east-1
```

Expected result after successful destroy:

```text
ResourceNotFoundException
```

## Troubleshooting

If `kubectl` tries `localhost:8080`, kubeconfig is missing. Run:

```bash
aws eks update-kubeconfig --name roboshop-dev --region us-east-1
```

If Amazon Linux 2023 shows `curl-minimal conflicts with curl`, do not replace
`curl-minimal`. These scripts use the existing `curl` command from
`curl-minimal` and install only missing helper packages.

If Terraform fails halfway, check:

```bash
terraform -chdir=terraform state list
terraform -chdir=terraform plan
```

If old `eksctl` stacks return, clean them before reusing the same cluster name.

If node group creation fails with `The specified instance type is not eligible
for Free Tier`, keep the default `NODE_TYPE=t3.micro` from `config.sh`, then run:

```bash
cd terraform
terraform apply -replace=aws_eks_node_group.this
```
