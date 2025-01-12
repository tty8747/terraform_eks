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
  cluster_name = aws_eks_cluster.eks.name
  addon_name   = "vpc-cni"
}

# Enable service discovery within the cluster
resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.eks.name
  addon_name   = "coredns"
  depends_on   = [aws_eks_node_group.internal]
}

# Enable service networking within the cluster
resource "aws_eks_addon" "kube-proxy" {
  cluster_name = aws_eks_cluster.eks.name
  addon_name   = "kube-proxy"
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
    desired_size = 5
    min_size     = 5
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

### oidc

resource "aws_iam_openid_connect_provider" "default" {
# url             = aws_eks_cluster.ek8s.identity[0].oidc[0].issuer
  url             = aws_eks_cluster.eks.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
# thumbprint_list = [data.tls_certificate.ek8s.certificates[0].sha1_fingerprint]
  thumbprint_list = [sha1(base64decode(aws_eks_cluster.eks.certificate_authority[0].data))]
}

### LoadBalancer

resource "aws_security_group" "lb" {
  name        = "lb"
  description = "Allow inbound traffic and all outbound traffic"
  vpc_id      = var.vpc.id

  tags = {
    Name = "lb"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_80" {
  security_group_id = aws_security_group.lb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80

  tags = {
    Name = "80"
  }
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.lb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports

  tags = {
    Name = "-1"
  }
}

resource "aws_lb" "eks" {
  name               = "alb-${local.cluster_name}"
  internal           = false
# load_balancer_type = "application"
  load_balancer_type = "network"
  security_groups    = [aws_security_group.lb.id]
  subnets            = var.subnet_ids_pub

  tags = {
    Name                       = "alb-${local.cluster_name}"
    "ingress.k8s.aws/resource" = "LoadBalancer"
    "ingress.k8s.aws/stack"    = "gocovid/ingress-gocovid"
    "elbv2.k8s.aws/cluster"    = local.cluster_name
  }

# Ignore changing SG since ALB controller will add them
lifecycle {
  ignore_changes = [
    security_groups
  ]
}

# lifecycle {
#   ignore_changes = all
# }
}

### LoadBalancer policies

# IAM Role for EKS Load Balancer Controller add-on
# https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html
resource "null_resource" "policy" {
  triggers = {
    always_run = timestamp()
  }
  provisioner "local-exec" {
    on_failure  = fail
    when        = create
    interpreter = ["/usr/bin/env", "sh", "-c"]
    command     = <<EOT
            curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
     EOT
  }
}

resource "aws_iam_policy" "eks-AWSLoadBalancerControllerIAMPolicy" {
  depends_on  = [null_resource.policy]
  name        = "${local.cluster_name}-AWSLoadBalancerControllerIAMPolicy"
  path        = "/"
  description = "AWS LoadBalancer Controller IAM Policy"

  policy = file("${path.module}/iam_policy.json")
}

resource "aws_iam_role" "eks-AmazonEKSLoadBalancerControllerRole" {
  name = "${local.cluster_name}-AmazonEKSLoadBalancerControllerRole"

  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Principal" : {
            "Federated" : "${aws_iam_openid_connect_provider.default.arn}"
          },
          "Action" : "sts:AssumeRoleWithWebIdentity",
          "Condition" : {
            "StringEquals" : {
              "${aws_iam_openid_connect_provider.default.url}:aud" : "sts.amazonaws.com",
              "${aws_iam_openid_connect_provider.default.url}:sub" : "system:serviceaccount:kube-system:aws-load-balancer-controller"
            }
          }
        }
      ]
  })
}

resource "aws_iam_role_policy_attachment" "eks-AWSLoadBalancerControllerIAMPolicy" {
  policy_arn = aws_iam_policy.eks-AWSLoadBalancerControllerIAMPolicy.arn
  role       = aws_iam_role.eks-AmazonEKSLoadBalancerControllerRole.name
}

