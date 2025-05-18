# Fetch the first 3 AZ names for the VPC
data "aws_availability_zones" "available" {}

locals {
  cluster_name = "${var.env}-eks"
}

#  VPC setup

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name            = "${var.env}-eks-vpc"
  cidr            = "10.0.0.0/16"
  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Env                                                = var.env
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/nlb"                           = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-nlb"                  = "1"
  }
}

# EKS with self managed workers 

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.35.0"

  cluster_name                             = "${local.cluster_name}"
  cluster_version                          = var.cluster_version
  vpc_id                                   = module.vpc.vpc_id
  subnet_ids                               = module.vpc.private_subnets
  cluster_endpoint_public_access           = true
  # Set to your IP or a trusted IP range
  # Setting this to 0.0.0.0/0 by default but note this is a security risk
  cluster_endpoint_public_access_cidrs     = ["0.0.0.0/0"]
  cluster_endpoint_private_access          = true
  enable_cluster_creator_admin_permissions = true
  authentication_mode                      = "API"


  self_managed_node_groups = {
    applications-group = {
      ami_type      = "AL2023_x86_64_STANDARD"
      instance_type = "t3.medium"
      min_size      = 1
      max_size      = 3
      desired_size  = 2

      cloudinit_pre_nodeadm = [
        {
          content = <<EOF
#!/bin/bash
set -exo pipefail
yum update -y --security
yum install container-selinux net-tools curl vim bind-utils procps-ng tcpdump -y --skip-broken
systemctl stop sshd
systemctl disable sshd
rm /etc/ssh/sshd_config.d/*
setenforce 1
sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
EOF
          content_type = "text/x-shellscript"
          filename     = "00-pre-nodeadm.sh"
        }
      ]
    }
  }
  eks_managed_node_groups = {}
}



