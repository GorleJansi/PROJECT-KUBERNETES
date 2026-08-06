# EKS Daily Delete Steps

Use this when you finish practice and want to control cost or remove everything.

## Option 1: Delete Only Practice Resources

Use this when you want to keep the cluster and worker nodes running, but remove
the daily test namespace:

```bash
cd ~/PROJECT-KUBERNETES/eks-daily
./cleanup.sh
```

Verify:

```bash
kubectl get ns daily-lab
```

Expected result:

```text
NotFound
```

## Option 2: Stop Worker Nodes After Practice

Use this when you want to keep the EKS control plane and Terraform state, but
stop EC2 worker-node cost:

```bash
cd ~/PROJECT-KUBERNETES/eks-daily
./stop.sh
```

Verify the node group is scaled down:

```bash
aws eks describe-nodegroup \
  --cluster-name roboshop-dev \
  --nodegroup-name roboshop-dev-ng \
  --region us-east-1 \
  --query 'nodegroup.scalingConfig' \
  --output table
```

Expected values:

```text
desiredSize = 0
minSize     = 0
maxSize     = 2
```

Start nodes again next time:

```bash
cd ~/PROJECT-KUBERNETES/eks-daily
./start.sh
kubectl get nodes
```

## Option 3: Delete The Whole EKS Lab

Use this when you are done with the lab and want to remove the Terraform-managed
VPC, subnets, IAM roles, EKS cluster, node group, and add-ons.

Important: run this from the same EC2 checkout where `terraform apply` created
the cluster, because the Terraform state is local unless you configure a remote
backend.

```bash
cd ~/PROJECT-KUBERNETES/eks-daily
./delete-all.sh
```

Type:

```text
DESTROY
```

When Terraform asks for approval, type:

```text
yes
```

## Verify Full Deletion

Check EKS cluster:

```bash
aws eks describe-cluster \
  --name roboshop-dev \
  --region us-east-1
```

Expected result:

```text
ResourceNotFoundException
```

Check node groups:

```bash
aws eks list-nodegroups \
  --cluster-name roboshop-dev \
  --region us-east-1
```

Expected result:

```text
ResourceNotFoundException
```

Check old eksctl stacks are not active:

```bash
aws cloudformation list-stacks \
  --region us-east-1 \
  --query "StackSummaries[?contains(StackName, 'eksctl-roboshop-dev') && StackStatus!='DELETE_COMPLETE'].[StackName,StackStatus]" \
  --output table
```

Expected result:

```text
empty output
```

## If Terraform Destroy Fails

Do not delete random resources from the console first. Run:

```bash
cd ~/PROJECT-KUBERNETES/eks-daily/terraform
terraform state list
terraform plan
terraform destroy
```

If the failure mentions a dependency, paste the last 20-30 lines of the error
and fix that dependency before retrying.

## After Successful Destroy

If this was a temporary EC2 workstation, you can terminate the EC2 instance from
the AWS console after confirming the EKS cluster is gone.

If you configured AWS access keys with `aws configure`, delete or rotate those
keys in IAM after practice.
