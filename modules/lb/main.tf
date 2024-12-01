terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.72.1"
    }
  }
}

locals {
  lb = "${var.cluster_name}"
}

### NLB

# resource "aws_security_group" "lb" {
#   name        = "lb"
#   description = "Allow inbound traffic and all outbound traffic"
#   vpc_id      = var.lb_vpc_id
# 
#   tags = {
#     Name = "lb"
#   }
# }

# resource "aws_vpc_security_group_ingress_rule" "allow_80" {
#   count             = length(var.lb_cidr_blocks)
#   security_group_id = aws_security_group.lb.id
#   cidr_ipv4         = var.lb_cidr_blocks[count.index]
#   from_port         = 80
#   ip_protocol       = "tcp"
#   to_port           = 80
# 
#   tags = {
#     Name = "80"
#   }
# }

# resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
#   security_group_id = aws_security_group.lb.id
#   cidr_ipv4         = "0.0.0.0/0"
#   ip_protocol       = "-1" # semantically equivalent to all ports
# 
#   tags = {
#     Name = "-1"
#   }
# }

resource "aws_lb" "lb" {
  name               = "alp-${local.lb}"
  internal           = false
  load_balancer_type = "network"
  subnets            = var.lb_subnet_ids
# security_groups    = [aws_security_group.lb.id]

# enable_cross_zone_load_balancing = true

  tags = {
    Name                       = local.lb
    "ingress.k8s.aws/resource" = "LoadBalancer"
  # "ingress.k8s.aws/stack"    = "ingress-${local.lb}"
  # "elbv2.k8s.aws/cluster"    = "eks-stage"
  # "kubernetes.io/service-name" = "nginx/my-nginx-ingress-nginx-controller"
    "elbv2.k8s.aws/cluster"    = var.cluster_name
    "service.k8s.aws/resource" = "LoadBalancer"
    # where svc of helm chart is installed: namespace=default, name of service=nginx-ingress-nginx-controller
    "service.k8s.aws/stack"    = "default/nginx-ingress-nginx-controller"
  }

  # Ignore changing SG since ALB controller will add them
  lifecycle {
    ignore_changes = [
      security_groups
    ]
  }
}
