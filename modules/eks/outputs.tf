output "aws_iam_role_eks" {
  value = aws_iam_role.eks_cluster
}

output "aws_eks_cluster" {
  value = aws_eks_cluster.eks
}

output "aws_eks_node_group" {
  value = aws_eks_node_group.internal
}

output "aws_lb" {
  value = aws_lb.eks
}

output "aws_iam_openid_connect_provider" {
  value = aws_iam_openid_connect_provider.default
}

output "iam_role_lb" {
  value = aws_iam_role.eks-AmazonEKSLoadBalancerControllerRole
}
