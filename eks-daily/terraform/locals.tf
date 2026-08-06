data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  selected_azs = slice(data.aws_availability_zones.available.names, 0, 2)

  common_tags = {
    Project     = "roboshop"
    Environment = "dev"
    ManagedBy   = "terraform"
    Lab         = "eks-daily"
  }
}
