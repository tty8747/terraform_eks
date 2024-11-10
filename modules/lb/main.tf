terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.72.1"
    }
  }
}

locals {
  lb = "${var.cluster_name}-${var.environment}"
}

### ALB

resource "aws_security_group" "lb" {
  name        = "lb"
  description = "Allow inbound traffic and all outbound traffic"
  vpc_id      = var.lb_vpc_id

  tags = {
    Name = "lb"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_80" {
  count             = length(var.lb_cidr_blocks)
  security_group_id = aws_security_group.lb.id
  cidr_ipv4         = var.lb_cidr_blocks[count.index]
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

resource "aws_lb" "lb" {
  name               = local.lb
  internal           = false
  load_balancer_type = "application"
  subnets            = var.lb_subnet_ids
  security_groups    = [aws_security_group.lb.id]

  enable_cross_zone_load_balancing = true

  tags = {
    Name                       = local.lb
    "ingress.k8s.aws/resource" = "LoadBalancer"
    "ingress.k8s.aws/stack"    = "ingress-${local.lb}"
    "elbv2.k8s.aws/cluster"    = local.lb
  }

  lifecycle {
    ignore_changes = all
  }
}

# https://docs.aws.amazon.com/eks/latest/userguide/lbc-helm.html
resource "aws_iam_policy" "AWSLoadBalancerControllerIAMPolicy" {
  name        = "AWSLoadBalancerControllerIAMPolicy"
  path        = "/"
  description = "AWS LoadBalancer Controller IAM Policy"

  policy = file("${path.module}/iam_policy.json")
}

resource "aws_iam_role" "AmazonEKSLoadBalancerControllerRole" {
  name = "AmazonEKSLoadBalancerControllerRole"

  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Principal" : {
            "Federated": "arn:aws:iam::619115920608:oidc-provider/oidc.eks.eu-central-1.amazonaws.com/id/7ABFD5AA0D82CB7F69A12C4998C0369C"
          },
          "Action" : "sts:AssumeRoleWithWebIdentity",
          "Condition" : {
            "StringEquals" : {
              "oidc.eks.eu-central-1.amazonaws.com/id/7ABFD5AA0D82CB7F69A12C4998C0369C:aud": "sts.amazonaws.com",
              "oidc.eks.eu-central-1.amazonaws.com/id/7ABFD5AA0D82CB7F69A12C4998C0369C:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
            }
          }
        }
      ]
  })
}

resource "aws_iam_role_policy_attachment" "AWSLoadBalancerControllerIAMPolicy" {
  policy_arn = aws_iam_policy.AWSLoadBalancerControllerIAMPolicy.arn
  role       = aws_iam_role.AmazonEKSLoadBalancerControllerRole.name
}

# ---
# resource "aws_lb_target_group" "lb_tg" {
#   name     = "lb-tg-${var.environment}"
#   port     = 80
#   protocol = "HTTP"
#   vpc_id   = var.lb_vpc_id
# }
# 
# resource "aws_lb_listener" "lb_listener" {
#   load_balancer_arn = aws_lb.lb.arn
#   port              = "80"
#   protocol          = "HTTP"
# 
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.lb_tg.arn
#   }
# }

# Amazon load balancer controller
# resource "helm_release" "aws-load-balancer-controller" {
#   name = "aws-load-balancer-controller"
# 
#   repository = "https://aws.github.io/eks-charts"
#   chart      = "aws-load-balancer-controller"
#   namespace  = "kube-system"
# 
#   set {
#     name  = "clusterName"
#     value = var.cluster_name
#   }

# set {
#   name  = "serviceAccount.create"
#   value = "false"
# }

# set {
#   name  = "serviceAccount.name"
#   value = kubernetes_service_account.aws_load_balancer_controller.metadata[0].name
# }
# }
