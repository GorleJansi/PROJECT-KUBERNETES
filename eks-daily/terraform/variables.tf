variable "aws_region" {
  description = "AWS region for the EKS lab."
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
  default     = "roboshop-dev"
}

variable "cluster_version" {
  description = "EKS Kubernetes control-plane version."
  type        = string
  default     = "1.34"
}

variable "node_group_name" {
  description = "EKS managed node group name."
  type        = string
  default     = "roboshop-dev-ng"
}

variable "node_instance_type" {
  description = "EC2 instance type for worker nodes."
  type        = string
  default     = "t3.medium"
}

variable "node_min_size" {
  description = "Minimum worker-node count."
  type        = number
  default     = 0
}

variable "node_desired_size" {
  description = "Desired worker-node count."
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum worker-node count."
  type        = number
  default     = 2
}

variable "node_disk_size" {
  description = "Worker-node root volume size in GiB."
  type        = number
  default     = 20
}

variable "vpc_cidr" {
  description = "CIDR block for the EKS lab VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDR ranges allowed to reach the public EKS API endpoint."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
