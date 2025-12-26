terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  required_version = ">= 1.3.0"
}

provider "aws" {
  region = "ap-south-1"
}

# -------------------------------
# VPC
# -------------------------------
resource "aws_vpc" "devopsshack1_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "devopsshack1-vpc"
  }
}

# -------------------------------
# Subnets
# -------------------------------
resource "aws_subnet" "devopsshack1_subnet" {
  count                   = 2
  vpc_id                  = aws_vpc.devopsshack1_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.devopsshack1_vpc.cidr_block, 8, count.index)
  availability_zone       = element(["ap-south-1a", "ap-south-1b"], count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "devopsshack1-subnet-${count.index}"
  }
}

# -------------------------------
# Internet Gateway
# -------------------------------
resource "aws_internet_gateway" "devopsshack1_igw" {
  vpc_id = aws_vpc.devopsshack1_vpc.id

  tags = {
    Name = "devopsshack1-igw"
  }
}

# -------------------------------
# Route Table
# -------------------------------
resource "aws_route_table" "devopsshack1_rt" {
  vpc_id = aws_vpc.devopsshack1_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.devopsshack1_igw.id
  }

  tags = {
    Name = "devopsshack1-rt"
  }
}

resource "aws_route_table_association" "devopsshack1_assoc" {
  count          = length(aws_subnet.devopsshack1_subnet)
  subnet_id      = aws_subnet.devopsshack1_subnet[count.index].id
  route_table_id = aws_route_table.devopsshack1_rt.id
}

# -------------------------------
# EKS Cluster Role
# -------------------------------
resource "aws_iam_role" "eks_cluster_role" {
  name = "devopsshack1-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Principal = { Service = "eks.amazonaws.com" },
      Effect    = "Allow"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# -------------------------------
# EKS Cluster
# -------------------------------
resource "aws_eks_cluster" "devopsshack1" {
  name     = "devopsshack1-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = aws_subnet.devopsshack1_subnet[*].id
  }

  version = "1.33"

  depends_on = [aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy]
}

# -------------------------------
# Node Group Role
# -------------------------------
resource "aws_iam_role" "eks_node_role" {
  name = "devopsshack1-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# -------------------------------
# Node Group
# -------------------------------
resource "aws_eks_node_group" "devopsshack1_node_group" {
  cluster_name    = aws_eks_cluster.devopsshack1.name
  node_group_name = "devopsshack1-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = aws_subnet.devopsshack1_subnet[*].id

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  instance_types = ["c7i-flex.large"]
  disk_size      = 20

  depends_on = [
    aws_eks_cluster.devopsshack1,
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly
  ]
}

# -------------------------------
# EBS CSI Driver Add-on
# -------------------------------
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name             = aws_eks_cluster.devopsshack1.name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.35.0-eksbuild.1" # ✅ Compatible with EKS 1.33
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.devopsshack1_node_group]
}

