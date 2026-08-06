# Terraform EKS Lab

This folder creates the `roboshop-dev` EKS lab with Terraform instead of
`eksctl`. Terraform manages the VPC, public subnets, IAM roles, EKS control
plane, managed node group, and EKS add-ons.

## Why Terraform

`eksctl` creates CloudFormation stacks named like `eksctl-roboshop-dev-*`.
This Terraform setup manages resources through Terraform state instead, so the
main workflow is:

```bash
terraform init
terraform plan
terraform apply
terraform destroy
```

## What It Creates

| Resource | Name |
| --- | --- |
| VPC | `roboshop-dev-vpc` |
| Public subnets | `roboshop-dev-public-us-east-1a`, `roboshop-dev-public-us-east-1b` |
| EKS cluster | `roboshop-dev` |
| Managed node group | `roboshop-dev-ng` |
| Node instance type | `t3.medium` |
| Desired nodes | `2` |
| EKS add-ons | `vpc-cni`, `kube-proxy`, `coredns` |

The lab intentionally uses public subnets for worker nodes to avoid NAT Gateway
cost. This is acceptable for a temporary learning cluster, not a production
network design.

## Use From EC2

From the `eks-daily` folder:

```bash
./setup-terraform-eks.sh
```

Type:

```text
TERRAFORM
```

The wrapper installs Terraform if needed, runs Terraform, updates kubeconfig,
and checks Kubernetes nodes. It also installs AWS CLI and kubectl if they are
missing on the EC2 workstation.

## Manual Terraform Commands

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

Update kubeconfig:

```bash
aws eks update-kubeconfig --name roboshop-dev --region us-east-1
kubectl get nodes
```

Destroy when finished:

```bash
terraform destroy
```

For the full cleanup checklist, see:

```bash
cat ../DELETE-STEPS.md
```

## Important

- Delete old `eksctl-roboshop-dev-*` CloudFormation stacks before using this.
- Do not commit `.terraform/` or `terraform.tfstate`.
- The IAM user or EC2 IAM role running Terraform needs EKS, EC2, IAM, and VPC permissions.
- If you pasted an AWS access key anywhere, rotate/delete that key in IAM.
