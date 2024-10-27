terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.72.1"
    }
  }
}

locals {
  cluster_name = "eks-${var.environment}"
  node_group01 = "group01-${var.environment}"
}

### K8s cluster

# Trust policy to allow this role to EKS
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# IAM Role for EKS cluster
resource "aws_iam_role" "eks_cluster" {
  name               = local.cluster_name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

# Attach the built-in policy to the EKS IAM role
resource "aws_iam_role_policy_attachment" "eks-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# Optionally, enable Security Groups for Pods
# Reference: https://docs.aws.amazon.com/eks/latest/userguide/security-groups-for-pods.html
resource "aws_iam_role_policy_attachment" "eks-AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_eks_cluster" "eks" {
  name                          = local.cluster_name
  role_arn                      = aws_iam_role.eks_cluster.arn
  version                       = var.cluster_version
  enabled_cluster_log_types     = var.cluster_log_types
  bootstrap_self_managed_addons = true

  vpc_config {
    subnet_ids = var.subnet_ids
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.eks-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eks-AmazonEKSVPCResourceController,
  ]

  tags = {
    Environment = var.environment
  }
}
  
# Cluster addons
# Enable pod networking within the cluster
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.eks.name
  addon_name                  = "vpc-cni"
}

# Enable service discovery within the cluster
resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.eks.name
  addon_name                  = "coredns"
  depends_on = [aws_eks_node_group.internal]
}

# Enable service networking within the cluster
resource "aws_eks_addon" "kube-proxy" {
  cluster_name                = aws_eks_cluster.eks.name
  addon_name                  = "kube-proxy"
}

### Node groups

# IAM Role for EKS node group
resource "aws_iam_role" "eks_node_group" {
  name = local.node_group01

  assume_role_policy = jsonencode(
    {
      Statement = [{
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }]
      Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "eks-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group.name
}

# Node groups
resource "aws_eks_node_group" "internal" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = local.node_group01
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = var.subnet_ids
  instance_types  = var.instance_types
  labels = {
    aim = "internal"
  }

  scaling_config {
    desired_size = 3
    min_size     = 2
    max_size     = 10
  }

  update_config {
    max_unavailable = 1
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.eks-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eks-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.eks-AmazonEC2ContainerRegistryReadOnly,
  ]

  tags = {
    "k8s.io/cluster-autoscaler/${local.cluster_name}" = "owned"
    "k8s.io/cluster-autoscaler/enabled"               = "TRUE"
  }
}

### ALB

resource "aws_lb" "lb" {                                                                                                                                                               
  name               = "alb-${local.cluster_name}"
  internal           = false
  load_balancer_type = "application"
  subnets            = var.lb_subnet_ids

  enable_cross_zone_load_balancing = true
 
  tags = {
    Name                       = "alb-${local.cluster_name}"
    "ingress.k8s.aws/resource" = "LoadBalancer"
    "ingress.k8s.aws/stack"    = "ingress-${local.cluster_name}"
    "elbv2.k8s.aws/cluster"    = local.cluster_name
  }
 
  lifecycle {
    ignore_changes = all
  }
}

resource "aws_lb_target_group" "lb_tg" {
  name     = "lb-tg-${var.environment}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.lb_vpc
}

resource "aws_lb_listener" "lb_listener" {
  load_balancer_arn = aws_lb.lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_tg.arn
  }
}
